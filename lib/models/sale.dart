import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final String? salesPersonName;
  final String? salesPersonEmail;
  final double? serviceAmount;
  final double? accessoriesAmount;
  final Map<String, dynamic>? paymentBreakdownVerified;
  final bool? paymentVerified;
  final String? notes;
  final String? customerPhone;
  final double? downPayment;
  final String? financeType;
  final String? purchaseMode;
  final double? discount;
  final double? exchangeValue;
  final double? amountToPay;
  final double? balanceReturnedToCustomer;
  final double? customerCredit;
  final DateTime? addedAt;
  final String? imei;
  final String? defect;

  // NEW FIELDS from your data model
  final double? price;
  final double? disbursementAmount;
  final bool? disbursementReceived;
  final bool? downPaymentReceived;
  final String? userEmail;
  final String? userId;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final String? support;
  final String? upgrade;

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
    this.salesPersonName,
    this.salesPersonEmail,
    this.serviceAmount,
    this.accessoriesAmount,
    this.paymentBreakdownVerified,
    this.paymentVerified,
    this.notes,
    this.customerPhone,
    this.downPayment,
    this.financeType,
    this.purchaseMode,
    this.discount,
    this.exchangeValue,
    this.amountToPay,
    this.balanceReturnedToCustomer,
    this.customerCredit,
    this.addedAt,
    this.imei,
    this.defect,

    // New fields
    this.price,
    this.disbursementAmount,
    this.disbursementReceived,
    this.downPaymentReceived,
    this.userEmail,
    this.userId,
    this.updatedAt,
    this.createdAt,
    this.support,
    this.upgrade,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse date
    DateTime parseDate(dynamic dateField) {
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        try {
          return DateFormat('yyyy-MM-dd').parse(dateField);
        } catch (e) {
          return DateTime.now();
        }
      } else if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      }
      return DateTime.now();
    }

    // Helper function to safely convert to double
    double? safeToDouble(dynamic value) {
      if (value == null) return null;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // Determine sale type and category
    String type = 'unknown';
    String category = 'Unknown';

    if (doc.reference.path.contains('phone_sales') ||
        (data['productModel'] != null && data['imei'] != null)) {
      type = 'phone_sale';
      category = 'New Phone';
    } else if (doc.reference.path.contains('base_model_sales') ||
        data.containsKey('modelName')) {
      type = 'base_model_sale';
      category = 'Base Model';
    } else if (doc.reference.path.contains('seconds_phone_sales') ||
        data.containsKey('productName')) {
      type = 'seconds_phone_sale';
      category = 'Second Phone';
    } else if (doc.reference.path.contains('accessories_service_sales') ||
        data.containsKey('serviceAmount')) {
      type = 'accessories_service_sale';
      category = 'Service';
    }

    // Parse all date fields
    DateTime saleDate = parseDate(
      data['saleDate'] ?? data['date'] ?? data['timestamp'],
    );
    DateTime? addedAt = data['addedAt'] != null
        ? parseDate(data['addedAt'])
        : null;
    DateTime? createdAt = data['createdAt'] != null
        ? parseDate(data['createdAt'])
        : null;
    DateTime? updatedAt = data['updatedAt'] != null
        ? parseDate(data['updatedAt'])
        : null;

    // Get payment breakdown
    Map<String, dynamic>? paymentBreakdown = data['paymentBreakdown'] != null
        ? Map<String, dynamic>.from(data['paymentBreakdown'])
        : null;

    return Sale(
      id: doc.id,
      type: type,
      shopName: data['shopName'] ?? 'Unknown Shop',
      shopId: data['shopId'] ?? '',
      amount:
          safeToDouble(
            data['effectivePrice'] ??
                data['price'] ??
                data['totalSaleAmount'] ??
                data['amount'],
          ) ??
          0.0,
      date: saleDate,
      customerName: data['customerName'] ?? 'Unknown Customer',
      category: category,
      itemName:
          data['productModel'] ??
          data['modelName'] ??
          data['productName'] ??
          'Item',
      brand: data['brand'],
      model: data['productModel'] ?? data['modelName'],
      cashAmount: safeToDouble(
        paymentBreakdown?['cash'] ?? data['cashAmount'] ?? data['cash'],
      ),
      cardAmount: safeToDouble(
        paymentBreakdown?['card'] ?? data['cardAmount'] ?? data['card'],
      ),
      gpayAmount: safeToDouble(
        paymentBreakdown?['gpay'] ?? data['gpayAmount'] ?? data['gpay'],
      ),
      salesPersonName:
          data['salesPersonName'] ??
          data['uploadedByEmail'] ??
          data['userEmail'],
      salesPersonEmail: data['salesPersonEmail'] ?? data['userEmail'],
      serviceAmount: safeToDouble(data['serviceAmount']),
      accessoriesAmount: safeToDouble(data['accessoriesAmount']),
      paymentBreakdownVerified: data['paymentBreakdownVerified'] != null
          ? Map<String, dynamic>.from(data['paymentBreakdownVerified'])
          : null,
      paymentVerified: data['paymentVerified'],
      notes: data['notes'],
      customerPhone: data['customerPhone'],
      downPayment: safeToDouble(data['downPayment']),
      financeType: data['financeType'],
      purchaseMode: data['purchaseMode'],
      discount: safeToDouble(data['discount']),
      exchangeValue: safeToDouble(data['exchangeValue']),
      amountToPay: safeToDouble(data['amountToPay']),
      balanceReturnedToCustomer: safeToDouble(
        data['balanceReturnedToCustomer'],
      ),
      customerCredit: safeToDouble(data['customerCredit']),
      addedAt: addedAt,
      imei: data['imei'],
      defect: data['defect'],

      // New fields
      price: safeToDouble(data['price']),
      disbursementAmount: safeToDouble(data['disbursementAmount']), // Updated
      disbursementReceived: data['disbursementReceived'],
      downPaymentReceived: data['downPaymentReceived'],
      userEmail: data['userEmail'],
      userId: data['userId'],
      updatedAt: updatedAt,
      createdAt: createdAt,
      support: data['support'],
      upgrade: data['upgrade'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'shopName': shopName,
      'shopId': shopId,
      'amount': amount,
      'date': date,
      'customerName': customerName,
      'category': category,
      'itemName': itemName,
      'brand': brand,
      'model': model,
      'cashAmount': cashAmount,
      'cardAmount': cardAmount,
      'gpayAmount': gpayAmount,
      'salesPersonName': salesPersonName,
      'salesPersonEmail': salesPersonEmail,
      'serviceAmount': serviceAmount,
      'accessoriesAmount': accessoriesAmount,
      'paymentBreakdownVerified': paymentBreakdownVerified,
      'paymentVerified': paymentVerified,
      'notes': notes,
      'customerPhone': customerPhone,
      'downPayment': downPayment,
      'financeType': financeType,
      'purchaseMode': purchaseMode,
      'discount': discount,
      'exchangeValue': exchangeValue,
      'amountToPay': amountToPay,
      'balanceReturnedToCustomer': balanceReturnedToCustomer,
      'customerCredit': customerCredit,
      'addedAt': addedAt,
      'imei': imei,
      'defect': defect,
      'price': price,
      'disbursementAmount': disbursementAmount,
      'disbursementReceived': disbursementReceived,
      'downPaymentReceived': downPaymentReceived,
      'userEmail': userEmail,
      'userId': userId,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
      'support': support,
      'upgrade': upgrade,
    };
  }
}
