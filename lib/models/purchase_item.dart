class PurchaseItem {
  String? productId;
  String? productName;
  String? brand;
  double? quantity;
  double? rate;
  double? discountPercentage;
  String? hsnCode;
  double? gstAmount;

  PurchaseItem({
    this.productId,
    this.productName,
    this.brand,
    this.quantity,
    this.rate,
    this.discountPercentage,
    this.hsnCode,
    this.gstAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'quantity': quantity,
      'rate': rate,
      'discountPercentage': discountPercentage,
      'hsnCode': hsnCode,
      'gstAmount': gstAmount,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'],
      productName: map['productName'],
      brand: map['brand'],
      quantity: map['quantity']?.toDouble(),
      rate: map['rate']?.toDouble(),
      discountPercentage: map['discountPercentage']?.toDouble(),
      hsnCode: map['hsnCode'],
      gstAmount: map['gstAmount']?.toDouble(),
    );
  }
}
