class PurchaseItem {
  String productId;
  String productName;
  double rate;  // Changed from purchaseRate to rate
  int quantity;
  double total;
  int gstPercentage;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.rate,  // Changed parameter name
    required this.quantity,
    required this.total,
    required this.gstPercentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'rate': rate,  // Changed key name
      'quantity': quantity,
      'total': total,
      'gstPercentage': gstPercentage,
    };
  }
}