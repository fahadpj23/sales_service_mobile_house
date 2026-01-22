// models/purchase_item.dart
class PurchaseItem {
  String? id;
  String? productId;
  String? productName;
  String? brand;
  String? model;
  String? color;
  double? quantity;
  double? rate;
  double? discountPercentage;
  String? imei;
  String? hsnCode; // Add this field

  PurchaseItem({
    this.id,
    this.productId,
    this.productName,
    this.brand,
    this.model,
    this.color,
    this.quantity,
    this.rate,
    this.discountPercentage,
    this.imei,
    this.hsnCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'model': model,
      'color': color,
      'quantity': quantity,
      'rate': rate,
      'discountPercentage': discountPercentage,
      'imei': imei,
      'hsnCode': hsnCode,
      if (id != null) 'id': id,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      productId: map['productId'],
      productName: map['productName'],
      brand: map['brand'],
      model: map['model'],
      color: map['color'],
      quantity: map['quantity']?.toDouble(),
      rate: map['rate']?.toDouble(),
      discountPercentage: map['discountPercentage']?.toDouble(),
      imei: map['imei'],
      hsnCode: map['hsnCode'],
    );
  }
}
