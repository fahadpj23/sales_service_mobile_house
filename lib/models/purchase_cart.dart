// lib/models/purchase_cart.dart
//
// Standalone file so it cannot clash with purchase.dart / purchase_model.dart.

/// Which stock collection a purchased unit goes into.
enum StockKind { phone, tv, appliance, accessory, none }

/// Mutable in-memory row used while building a purchase.
class CartItem {
  String productId;
  String productName;
  double rate;
  int quantity;
  double total;
  int gstPercentage;
  double discount;
  String discountType;
  double originalRate;
  String productType;
  String brand;
  double saleRate;
  List<String> identifiers;
  String identifierType;

  CartItem({
    required this.productId,
    required this.productName,
    required this.rate,
    required this.quantity,
    required this.total,
    required this.gstPercentage,
    this.discount = 0,
    this.discountType = 'percentage',
    this.originalRate = 0,
    this.productType = '',
    this.brand = '',
    this.saleRate = 0,
    List<String>? identifiers,
    this.identifierType = 'Serial',
  }) : identifiers = identifiers ?? <String>[];
}
