enum UserRole { owner, kasir, dapur }

UserRole roleFromString(String s) => UserRole.values.firstWhere(
      (e) => e.name == s,
      orElse: () => UserRole.kasir,
    );

class AppProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final String? outletId;

  AppProfile({required this.id, required this.fullName, required this.role, this.outletId});

  factory AppProfile.fromMap(Map<String, dynamic> m) => AppProfile(
        id: m['id'],
        fullName: m['full_name'] ?? '',
        role: roleFromString(m['role'] ?? 'kasir'),
        outletId: m['outlet_id'],
      );
}

class Ingredient {
  final String id;
  final String name;
  final String unit;
  final double stockQty;
  final double minStock;
  final double costPerUnit;

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockQty,
    required this.minStock,
    required this.costPerUnit,
  });

  bool get isLowStock => stockQty <= minStock;

  factory Ingredient.fromMap(Map<String, dynamic> m) => Ingredient(
        id: m['id'],
        name: m['name'],
        unit: m['unit'],
        stockQty: (m['stock_qty'] as num).toDouble(),
        minStock: (m['min_stock'] as num?)?.toDouble() ?? 0,
        costPerUnit: (m['cost_per_unit'] as num).toDouble(),
      );
}

class Product {
  final String id;
  final String name;
  final String? category;
  final double price;
  final String? imageUrl;
  final double hpp; // dihitung dari view product_hpp

  Product({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    this.imageUrl,
    this.hpp = 0,
  });

  double get margin => price - hpp;
  double get marginPercent => price == 0 ? 0 : (margin / price) * 100;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'],
        name: m['name'],
        category: m['category'],
        price: (m['price'] as num).toDouble(),
        imageUrl: m['image_url'],
        hpp: (m['hpp'] as num?)?.toDouble() ?? 0,
      );
}

class CartItem {
  final Product product;
  int qty;
  String? note;

  CartItem({required this.product, this.qty = 1, this.note});

  double get subtotal => product.price * qty;
}

enum SalesChannel { offline, whatsapp, gofood, grabfood, shopeefood }

extension SalesChannelX on SalesChannel {
  String get label {
    switch (this) {
      case SalesChannel.offline:
        return 'Offline / Dine-in';
      case SalesChannel.whatsapp:
        return 'WhatsApp';
      case SalesChannel.gofood:
        return 'GoFood';
      case SalesChannel.grabfood:
        return 'GrabFood';
      case SalesChannel.shopeefood:
        return 'ShopeeFood';
    }
  }
}
