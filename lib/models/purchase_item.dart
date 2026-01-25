class PurchaseItem {
  String? productId;
  String? productName;
  String? brand;
  String? model;
  String? hsnCode;
  double? quantity;
  double? rate;
  double? discountPercentage;
  double? gstAmount;
  String? imei; // Single IMEI for backward compatibility
  List<String>? imeis; // Multiple IMEIs for multiple quantities

  PurchaseItem({
    this.productId,
    this.productName,
    this.brand,
    this.model,
    this.hsnCode,
    this.quantity,
    this.rate,
    this.discountPercentage,
    this.gstAmount,
    this.imei,
    this.imeis,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'],
      productName: map['productName'],
      brand: map['brand'],
      model: map['model'],
      hsnCode: map['hsnCode'],
      quantity: (map['quantity'] as num?)?.toDouble(),
      rate: (map['rate'] as num?)?.toDouble(),
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble(),
      gstAmount: (map['gstAmount'] as num?)?.toDouble(),
      imei: map['imei'],
      imeis: map['imeis'] != null ? List<String>.from(map['imeis']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'model': model,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'rate': rate,
      'discountPercentage': discountPercentage,
      'gstAmount': gstAmount,
      'imei': imei, // Keep for backward compatibility
      'imeis': imeis, // Add new field
    };
  }
}
