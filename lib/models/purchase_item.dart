class PurchaseItem {
  String? productId;
  String? productName;
  String? brand;
  String? hsnCode;
  String? category; // Add this field
  double? quantity;
  double? rate;
  double? discountPercentage;
  double? gstAmount;
  List<String>? imeiNumbers;

  PurchaseItem({
    this.productId,
    this.productName,
    this.brand,
    this.hsnCode,
    this.category, // Add this
    this.quantity,
    this.rate,
    this.discountPercentage,
    this.gstAmount,
    this.imeiNumbers,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'hsnCode': hsnCode,
      'category': category, // Add this
      'quantity': quantity,
      'rate': rate,
      'discountPercentage': discountPercentage,
      'gstAmount': gstAmount,
      'imeiNumbers': imeiNumbers,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'],
      productName: map['productName'],
      brand: map['brand'],
      hsnCode: map['hsnCode'],
      category: map['category'], // Add this
      quantity: map['quantity']?.toDouble(),
      rate: map['rate']?.toDouble(),
      discountPercentage: map['discountPercentage']?.toDouble(),
      gstAmount: map['gstAmount']?.toDouble(),
      imeiNumbers: map['imeiNumbers'] != null
          ? List<String>.from(map['imeiNumbers'])
          : null,
    );
  }
}
