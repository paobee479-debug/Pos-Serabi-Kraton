import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Ganti dengan URL & anon key project Supabase kamu sendiri.
/// Simpan sebagai --dart-define saat build agar tidak hardcode di repo publik:
/// flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://YOUR-PROJECT.supabase.co');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR-ANON-KEY');

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }

  // ---------- AUTH ----------
  Future<AppProfile?> signIn(String email, String password) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    if (res.user == null) return null;
    return fetchProfile(res.user!.id);
  }

  Future<void> signOut() => client.auth.signOut();

  Future<AppProfile?> fetchProfile(String userId) async {
    final data = await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return AppProfile.fromMap(data);
  }

  // ---------- PRODUCTS & HPP ----------
  Future<List<Product>> fetchProductsWithHpp({String? outletId}) async {
    var query = client.from('products').select().eq('is_active', true);
    if (outletId != null) query = query.eq('outlet_id', outletId);
    final products = await query;
    final hppRows = await client.from('product_hpp').select();
    final hppMap = {for (var r in hppRows) r['product_id']: r['hpp']};
    return (products as List)
        .map((p) => Product.fromMap({...p, 'hpp': hppMap[p['id']] ?? 0}))
        .toList();
  }

  // ---------- INGREDIENTS / STOK ----------
  Future<List<Ingredient>> fetchIngredients({String? outletId}) async {
    var query = client.from('ingredients').select();
    if (outletId != null) query = query.eq('outlet_id', outletId);
    final data = await query.order('name');
    return (data as List).map((e) => Ingredient.fromMap(e)).toList();
  }

  Future<void> adjustStock({
    required String ingredientId,
    required double qty,
    required String type, // in, out, adjustment, waste
    String? note,
  }) async {
    await client.from('stock_movements').insert({
      'ingredient_id': ingredientId,
      'type': type,
      'qty': qty,
      'note': note,
    });
    // update stock_qty langsung (selain 'in' via trigger, di sini manual)
    final current = await client
        .from('ingredients')
        .select('stock_qty')
        .eq('id', ingredientId)
        .single();
    final currentQty = (current['stock_qty'] as num).toDouble();
    final delta = (type == 'in') ? qty : -qty;
    await client.from('ingredients').update({
      'stock_qty': currentQty + delta,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ingredientId);
  }

  // ---------- OUTLETS ----------
  Future<List<Map<String, dynamic>>> fetchOutlets() async {
    final data = await client.from('outlets').select().order('name');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ---------- PRODUCT CRUD ----------
  Future<void> createProduct({
    required String name,
    String? category,
    required double price,
    required String outletId,
  }) async {
    await client.from('products').insert({
      'name': name,
      'category': category,
      'price': price,
      'outlet_id': outletId,
      'is_active': true,
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    String? category,
    required double price,
  }) async {
    await client.from('products').update({
      'name': name,
      'category': category,
      'price': price,
    }).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    // soft delete supaya histori order_items tidak rusak
    await client.from('products').update({'is_active': false}).eq('id', id);
  }

  // ---------- INGREDIENT CRUD ----------
  Future<void> createIngredient({
    required String name,
    required String unit,
    required double stockQty,
    required double minStock,
    required double costPerUnit,
    required String outletId,
  }) async {
    await client.from('ingredients').insert({
      'name': name,
      'unit': unit,
      'stock_qty': stockQty,
      'min_stock': minStock,
      'cost_per_unit': costPerUnit,
      'outlet_id': outletId,
    });
  }

  Future<void> updateIngredient({
    required String id,
    required String name,
    required String unit,
    required double minStock,
    required double costPerUnit,
  }) async {
    await client.from('ingredients').update({
      'name': name,
      'unit': unit,
      'min_stock': minStock,
      'cost_per_unit': costPerUnit,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteIngredient(String id) async {
    await client.from('ingredients').delete().eq('id', id);
  }

  // ---------- RECIPE ITEMS CRUD (bahan per produk, dasar HPP) ----------
  Future<List<Map<String, dynamic>>> fetchRecipeItems(String productId) async {
    final data = await client
        .from('recipe_items')
        .select('id, qty_used, ingredient_id, ingredients(id, name, unit, cost_per_unit)')
        .eq('product_id', productId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> addRecipeItem({
    required String productId,
    required String ingredientId,
    required double qtyUsed,
  }) async {
    await client.from('recipe_items').insert({
      'product_id': productId,
      'ingredient_id': ingredientId,
      'qty_used': qtyUsed,
    });
  }

  Future<void> updateRecipeItemQty(String recipeItemId, double qtyUsed) async {
    await client.from('recipe_items').update({'qty_used': qtyUsed}).eq('id', recipeItemId);
  }

  Future<void> deleteRecipeItem(String recipeItemId) async {
    await client.from('recipe_items').delete().eq('id', recipeItemId);
  }

  // ---------- ORDERS ----------
  Future<Map<String, dynamic>> createOrder({
    required List<CartItem> items,
    required SalesChannel channel,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    required String cashierId,
    required String outletId,
  }) async {
    final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final order = await client.from('orders').insert({
      'order_number': orderNumber,
      'channel': channel.name,
      'status': 'pending',
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'cashier_id': cashierId,
      'outlet_id': outletId,
    }).select().single();

    final orderId = order['id'];
    final itemsPayload = items.map((c) => {
          'order_id': orderId,
          'product_id': c.product.id,
          'qty': c.qty,
          'price': c.product.price,
          'hpp_snapshot': c.product.hpp,
          'note': c.note,
        }).toList();

    await client.from('order_items').insert(itemsPayload);
    return order;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await client.from('orders').update({
      'status': status,
      if (status == 'completed') 'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  Stream<List<Map<String, dynamic>>> watchKitchenOrders() {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .inFilter('status', ['pending', 'in_kitchen'])
        .order('created_at');
  }

  // ---------- LAPORAN ----------
  Future<List<Map<String, dynamic>>> fetchDailySalesReport({String? outletId}) async {
    var query = client.from('sales_report_daily').select();
    if (outletId != null) query = query.eq('outlet_id', outletId);
    final data = await query;
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchProductSalesReport({String? outletId}) async {
    var query = client.from('sales_report_by_product').select();
    if (outletId != null) query = query.eq('outlet_id', outletId);
    final data = await query;
    return (data as List).cast<Map<String, dynamic>>();
  }
}
