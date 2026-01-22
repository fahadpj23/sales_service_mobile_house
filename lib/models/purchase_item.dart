class PurchaseItem {
  String? productId;
  String? productName;
  String? brand;
  String? model;
  String? color;
  String? ram;
  String? storage;
  String? hsnCode;
  double? quantity;
  double? rate;
  double? discountPercentage;
  String? imei;
  double? gstAmount; // NEW FIELD

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'brand': brand,
      'model': model,
      'color': color,
      'ram': ram,
      'storage': storage,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'rate': rate,
      'discountPercentage': discountPercentage,
      'imei': imei,
      'gstAmount': gstAmount, // NEW FIELD
    };
  }
}
