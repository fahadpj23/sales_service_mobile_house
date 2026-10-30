class Product {
  final String productType;
  final String brand;
  final String productName;
  final String hsn;
  final double purchaseRate;
  final double saleRate;
  final int gstPercentage;
  final String? imeiOrSerial; // NEW
  final String? purchaseBillUrl; // NEW
  final DateTime createdAt;

  Product({
    required this.productType,
    required this.brand,
    required this.productName,
    required this.hsn,
    required this.purchaseRate,
    required this.saleRate,
    required this.gstPercentage,
    this.imeiOrSerial,
    this.purchaseBillUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'productType': productType,
    'brand': brand,
    'productName': productName,
    'hsn': hsn,
    'purchaseRate': purchaseRate,
    'saleRate': saleRate,
    'gstPercentage': gstPercentage,
    'imeiOrSerial': imeiOrSerial,
    'purchaseBillUrl': purchaseBillUrl,
    'createdAt': createdAt,
  };
}
