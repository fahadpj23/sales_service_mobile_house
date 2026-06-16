class Product {
  String? id;
  String productType;
  String brand;
  String productName;
  String hsn;
  double purchaseRate;
  double saleRate;
  int gstPercentage;
  DateTime createdAt;

  Product({
    this.id,
    required this.productType,
    required this.brand,
    required this.productName,
    required this.hsn,
    required this.purchaseRate,
    required this.saleRate,
    required this.gstPercentage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productType': productType,
      'brand': brand,
      'productName': productName,
      'hsn': hsn,
      'purchaseRate': purchaseRate,
      'saleRate': saleRate,
      'gstPercentage': gstPercentage,
      'createdAt': createdAt,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      productType: map['productType'],
      brand: map['brand'],
      productName: map['productName'],
      hsn: map['hsn'],
      purchaseRate: map['purchaseRate'].toDouble(),
      saleRate: map['saleRate']?.toDouble() ?? 0.0,
      gstPercentage: map['gstPercentage'],
      createdAt: (map['createdAt'] as DateTime).toLocal(),
    );
  }
}
