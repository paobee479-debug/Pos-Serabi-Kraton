import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Mengatur daftar outlet & outlet yang sedang aktif dipilih.
/// Hanya relevan untuk role owner (kasir/dapur terkunci ke outlet_id
/// mereka masing-masing dari tabel profiles). Owner bisa switch outlet
/// untuk melihat data (produk, stok, laporan) per cabang, atau "Semua
/// Outlet" untuk gabungan.
class OutletProvider extends ChangeNotifier {
  List<Map<String, dynamic>> outlets = [];
  String? selectedOutletId; // null = semua outlet
  bool loading = false;

  bool get hasMultipleOutlets => outlets.length > 1;

  Future<void> loadOutlets() async {
    loading = true;
    notifyListeners();
    try {
      outlets = await SupabaseService.instance.fetchOutlets();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectOutlet(String? outletId) {
    selectedOutletId = outletId;
    notifyListeners();
  }

  String? outletName(String id) {
    final match = outlets.where((o) => o['id'] == id);
    return match.isEmpty ? null : match.first['name'];
  }
}

class AuthProvider extends ChangeNotifier {
  AppProfile? profile;
  bool loading = false;

  bool get isOwner => profile?.role == UserRole.owner;
  bool get isKasir => profile?.role == UserRole.kasir;
  bool get isDapur => profile?.role == UserRole.dapur;

  Future<bool> login(String email, String password) async {
    loading = true;
    notifyListeners();
    try {
      profile = await SupabaseService.instance.signIn(email, password);
      return profile != null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SupabaseService.instance.signOut();
    profile = null;
    notifyListeners();
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  SalesChannel channel = SalesChannel.offline;
  double discount = 0;
  double taxPercent = 0; // contoh: 10 untuk PB1 10%

  List<CartItem> get items => List.unmodifiable(_items);

  double get subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);
  double get tax => subtotal * (taxPercent / 100);
  double get total => (subtotal - discount) + tax;

  void addProduct(Product p) {
    final idx = _items.indexWhere((i) => i.product.id == p.id);
    if (idx >= 0) {
      _items[idx].qty++;
    } else {
      _items.add(CartItem(product: p));
    }
    notifyListeners();
  }

  void decreaseQty(String productId) {
    final idx = _items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    if (_items[idx].qty > 1) {
      _items[idx].qty--;
    } else {
      _items.removeAt(idx);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  void setChannel(SalesChannel c) {
    channel = c;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    discount = 0;
    channel = SalesChannel.offline;
    notifyListeners();
  }
}
