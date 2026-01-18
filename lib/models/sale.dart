class Sale {
  final String id;
  final String type;
  final String shopName;
  final String shopId;
  final double amount;
  final DateTime date;
  final String customerName;
  final String category;
  final String itemName;
  final String? brand;
  final String? model;
  final double? cashAmount;
  final double? cardAmount;
  final double? gpayAmount;
  final double? downPayment;
  final String? financeType;
  final String? purchaseMode;
  final String? salesPersonName;
  final String? salesPersonEmail;
  final String? customerPhone;
  final String? imei;
  final String? defect;
  final double? discount;
  final double? exchangeValue;
  final double? amountToPay;
  final double? balanceReturnedToCustomer;
  final double? customerCredit;
  final DateTime? addedAt;
  final double? serviceAmount;
  final double? accessoriesAmount;
  final Map<String, dynamic>? paymentBreakdownVerified;
  final bool? paymentVerified;
  final String? notes;

  Sale({
    required this.id,
    required this.type,
    required this.shopName,
    required this.shopId,
    required this.amount,
    required this.date,
    required this.customerName,
    required this.category,
    required this.itemName,
    this.brand,
    this.model,
    this.cashAmount,
    this.cardAmount,
    this.gpayAmount,
    this.downPayment,
    this.financeType,
    this.purchaseMode,
    this.salesPersonName,
    this.salesPersonEmail,
    this.customerPhone,
    this.imei,
    this.defect,
    this.discount,
    this.exchangeValue,
    this.amountToPay,
    this.balanceReturnedToCustomer,
    this.customerCredit,
    this.addedAt,
    this.serviceAmount,
    this.accessoriesAmount,
    this.paymentBreakdownVerified,
    this.paymentVerified,
    this.notes,
  });
}
