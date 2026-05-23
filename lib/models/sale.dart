import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Sale {
  final String id;
  final String type;
  final String shopName;
  final String shopId;
  final double amount;
  final double? totalSaleAmount;
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
  final String? productName;
  final String? modelName;

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

  // New fields for bills collection
  final String? billNumber;
  final double? gstAmount;
  final double? taxableAmount;
  final String? customerAddress;
  final bool? sealApplied;

  // Original phone data fields
  final String? originalProductBrand;
  final String? originalShopName;
  final String? originalProductName;
  final double? originalProductPrice;
  final String? originalShopId;
  final String? originalPhoneStockId;
  final String? originalImei;
  final String? originalPreviousShopName;
  final String? originalPreviousShopId;
  final String? transferredBy;
  final String? transferredById;
  final DateTime? transferredAt;

  Sale({
    required this.id,
    required this.type,
    required this.shopName,
    required this.shopId,
    required this.amount,
    this.totalSaleAmount,
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
    this.productName,
    this.modelName,
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
    this.billNumber,
    this.gstAmount,
    this.taxableAmount,
    this.customerAddress,
    this.sealApplied,
    this.originalProductBrand,
    this.originalShopName,
    this.originalProductName,
    this.originalProductPrice,
    this.originalShopId,
    this.originalPhoneStockId,
    this.originalImei,
    this.originalPreviousShopName,
    this.originalPreviousShopId,
    this.transferredBy,
    this.transferredById,
    this.transferredAt,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseDate(dynamic dateField) {
      if (dateField == null) return DateTime.now();
      if (dateField is Timestamp) {
        return dateField.toDate();
      } else if (dateField is String) {
        try {
          return DateFormat('yyyy-MM-dd').parse(dateField);
        } catch (e) {
          try {
            return DateFormat('dd MMM yyyy at HH:mm:ss').parse(dateField);
          } catch (e) {
            return DateTime.now();
          }
        }
      } else if (dateField is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateField);
      }
      return DateTime.now();
    }

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

    // Extract originalPhoneData if exists - this contains the source product information
    Map<String, dynamic>? originalPhoneData =
        data['originalPhoneData'] as Map<String, dynamic>?;

    String originalProductBrand = '';
    String originalShopName = '';
    String originalProductName = '';
    double originalProductPrice = 0.0;
    String originalShopId = '';
    String originalPhoneStockId = '';
    String originalImei = '';
    String? originalPreviousShopName;
    String? originalPreviousShopId;
    String? transferredBy;
    String? transferredById;
    DateTime? transferredAt;

    if (originalPhoneData != null) {
      originalProductBrand = originalPhoneData['productBrand'] ?? '';
      originalShopName =
          originalPhoneData['shopName'] ?? originalPhoneData['shop'] ?? '';
      originalProductName = originalPhoneData['productName'] ?? '';
      originalProductPrice =
          safeToDouble(originalPhoneData['productPrice']) ?? 0.0;
      originalShopId = originalPhoneData['shopId'] ?? '';
      originalPhoneStockId =
          originalPhoneData['id'] ?? originalPhoneData['phoneStockId'] ?? '';
      originalImei = originalPhoneData['imei'] ?? '';
      originalPreviousShopName = originalPhoneData['previousShopName'];
      originalPreviousShopId = originalPhoneData['previousShopId'];
      transferredBy = originalPhoneData['transferredBy'];
      transferredById = originalPhoneData['transferredById'];
      transferredAt = originalPhoneData['transferredAt'] != null
          ? parseDate(originalPhoneData['transferredAt'])
          : null;
    }

    // Determine the type of sale from the document path
    String type = 'unknown';
    String category = 'Unknown';

    final path = doc.reference.path;
    if (path.contains('phone_sales')) {
      type = 'phone_sale';
      category = 'New Phone';
    } else if (path.contains('base_model_sale')) {
      type = 'base_model_sale';
      category = 'Base Model';
    } else if (path.contains('seconds_phone_sale')) {
      type = 'seconds_phone_sale';
      category = 'Second Phone';
    } else if (path.contains('accessories_service_sale')) {
      type = 'accessories_service_sale';
      category = 'Accessories & Service';
    } else if (path.contains('bills')) {
      final billType = data['billType'] as String?;
      final typeField = data['type'] as String?;

      if (billType == 'Applianaces') {
        type = 'appliances_sale';
        category = 'Appliances';
      } else if (billType == 'GST Accessories') {
        type = 'gst_accessories_sale';
        category = 'GST Accessories';
      } else if (typeField == 'tv') {
        type = 'tv_sale';
        category = 'TV';
      } else {
        type = 'phone_sale';
        category = 'New Phone';
      }
    }

    // Parse dates with multiple possible field names
    DateTime saleDate = parseDate(
      data['date'] ??
          data['uploadedAt'] ??
          data['billDate'] ??
          data['timestamp'] ??
          data['saleDate'] ??
          data['createdAt'],
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

    Map<String, dynamic>? paymentBreakdown = data['paymentBreakdown'] != null
        ? Map<String, dynamic>.from(data['paymentBreakdown'])
        : null;

    // Calculate amount based on sale type
    double amount = 0.0;
    double? totalSaleAmount;

    if (type == 'accessories_service_sale') {
      totalSaleAmount = safeToDouble(data['totalSaleAmount']);
      final accessoriesAmount = safeToDouble(data['accessoriesAmount']) ?? 0;
      final serviceAmount = safeToDouble(data['serviceAmount']) ?? 0;

      if (totalSaleAmount != null && totalSaleAmount > 0) {
        amount = totalSaleAmount;
      } else {
        amount = accessoriesAmount + serviceAmount;
        totalSaleAmount = amount;
      }
    } else if (type == 'phone_sale') {
      // For phone sales, use totalAmount from the bill
      amount = safeToDouble(data['totalAmount']) ?? 0.0;
      // Also check for totalSaleAmount as fallback
      if (amount == 0.0) {
        amount = safeToDouble(data['totalSaleAmount']) ?? 0.0;
      }
    } else if (type == 'tv_sale' ||
        type == 'appliances_sale' ||
        type == 'gst_accessories_sale') {
      amount = safeToDouble(data['totalAmount']) ?? 0.0;
    } else {
      amount =
          safeToDouble(data['amount']) ??
          safeToDouble(data['price']) ??
          safeToDouble(data['totalAmount']) ??
          safeToDouble(data['totalSaleAmount']) ??
          0.0;
    }

    // Determine brand, shop name, and product name - prioritize originalPhoneData for phone sales
    String finalBrand = '';
    String finalShopName = '';
    String finalProductName = '';
    String finalImei = '';

    if (type == 'phone_sale' && originalPhoneData != null) {
      // For phone sales, use data from originalPhoneData
      finalBrand = originalProductBrand;
      finalShopName = originalShopName;
      finalProductName = originalProductName;
      finalImei = originalImei;
    } else {
      finalBrand =
          data['brand'] ?? data['modelBrand'] ?? data['productBrand'] ?? '';
      finalShopName = data['shopName'] ?? data['shop'] ?? 'Unknown Shop';
      finalProductName =
          data['productModel'] ??
          data['modelName'] ??
          data['productName'] ??
          '';
      finalImei = data['imei'] ?? '';
    }

    return Sale(
      id: doc.id,
      type: type,
      shopName: finalShopName.isNotEmpty
          ? finalShopName
          : (data['shopName'] ?? data['shop'] ?? 'Unknown Shop'),
      shopId: data['shopId'] ?? originalShopId,
      amount: amount,
      totalSaleAmount: totalSaleAmount,
      date: saleDate,
      customerName: data['customerName'] ?? 'Walk-in Customer',
      category: category,
      itemName: finalProductName.isNotEmpty
          ? finalProductName
          : (data['productModel'] ??
                data['modelName'] ??
                data['productName'] ??
                'Item'),
      brand: finalBrand.isNotEmpty
          ? finalBrand
          : (data['brand'] ?? data['modelBrand'] ?? data['productBrand']),
      model: data['productModel'] ?? data['modelName'] ?? data['productName'],
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
          data['userEmail'] ??
          data['createdBy'],
      salesPersonEmail:
          data['salesPersonEmail'] ?? data['userEmail'] ?? data['createdBy'],
      serviceAmount: safeToDouble(data['serviceAmount']),
      accessoriesAmount: safeToDouble(data['accessoriesAmount']),
      paymentBreakdownVerified: data['paymentBreakdownVerified'] != null
          ? Map<String, dynamic>.from(data['paymentBreakdownVerified'])
          : null,
      paymentVerified: data['paymentVerified'],
      notes: data['notes'],
      customerPhone: data['customerPhone'] ?? data['customerMobile'],
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
      imei: data['imei'] ?? finalImei,
      defect: data['defect'],
      productName: data['productName'] ?? originalProductName,
      modelName: data['modelName'],
      price: safeToDouble(data['price']) ?? originalProductPrice,
      disbursementAmount: safeToDouble(data['disbursementAmount']),
      disbursementReceived: data['disbursementReceived'],
      downPaymentReceived: data['downPaymentReceived'],
      userEmail: data['userEmail'] ?? data['createdBy'],
      userId: data['userId'] ?? data['createdById'],
      updatedAt: updatedAt,
      createdAt: createdAt,
      support: data['support'],
      upgrade: data['upgrade'],
      billNumber: data['billNumber'],
      gstAmount: safeToDouble(data['gstAmount']),
      taxableAmount: safeToDouble(data['taxableAmount']),
      customerAddress: data['customerAddress'],
      sealApplied: data['sealApplied'],
      originalProductBrand: originalProductBrand,
      originalShopName: originalShopName,
      originalProductName: originalProductName,
      originalProductPrice: originalProductPrice,
      originalShopId: originalShopId,
      originalPhoneStockId: originalPhoneStockId,
      originalImei: originalImei,
      originalPreviousShopName: originalPreviousShopName,
      originalPreviousShopId: originalPreviousShopId,
      transferredBy: transferredBy,
      transferredById: transferredById,
      transferredAt: transferredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'shopName': shopName,
      'shopId': shopId,
      'amount': amount,
      'totalSaleAmount': totalSaleAmount,
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
      'productName': productName,
      'modelName': modelName,
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
      'billNumber': billNumber,
      'gstAmount': gstAmount,
      'taxableAmount': taxableAmount,
      'customerAddress': customerAddress,
      'sealApplied': sealApplied,
      'originalProductBrand': originalProductBrand,
      'originalShopName': originalShopName,
      'originalProductName': originalProductName,
      'originalProductPrice': originalProductPrice,
      'originalShopId': originalShopId,
      'originalPhoneStockId': originalPhoneStockId,
      'originalImei': originalImei,
      'originalPreviousShopName': originalPreviousShopName,
      'originalPreviousShopId': originalPreviousShopId,
      'transferredBy': transferredBy,
      'transferredById': transferredById,
      'transferredAt': transferredAt,
    };
  }

  // Helper method to check if this sale has original phone data
  bool get hasOriginalPhoneData {
    return originalProductBrand != null && originalProductBrand!.isNotEmpty;
  }

  // Helper method to get the source shop name (where phone came from)
  String get sourceShopName {
    return originalShopName ?? shopName;
  }

  // Helper method to get the original product full description
  String get originalProductFullDescription {
    if (originalProductBrand != null && originalProductName != null) {
      return '$originalProductBrand $originalProductName';
    }
    return itemName;
  }

  // Helper method to check if this is a transferred phone
  bool get isTransferredPhone {
    return originalPreviousShopName != null &&
        originalPreviousShopName!.isNotEmpty;
  }
}
