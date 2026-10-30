import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItem {
  final String productId;
  final String productName;
  final String itemType; // phone, tv, appliances, accessories
  final String? imei;
  final String? serialNo;
  final double rate;
  final int quantity;
  final double total;
  final int gstPercentage;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.itemType,
    this.imei,
    this.serialNo,
    required this.rate,
    required this.quantity,
    required this.total,
    required this.gstPercentage,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'itemType': itemType,
    'imei': imei,
    'serialNo': serialNo,
    'rate': rate,
    'quantity': quantity,
    'total': total,
    'gstPercentage': gstPercentage,
  };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
    productId: map['productId'] ?? '',
    productName: map['productName'] ?? '',
    itemType: map['itemType'] ?? 'phone',
    imei: map['imei'],
    serialNo: map['serialNo'],
    rate: (map['rate'] ?? 0).toDouble(),
    quantity: map['quantity'] ?? 0,
    total: (map['total'] ?? 0).toDouble(),
    gstPercentage: map['gstPercentage'] ?? 0,
  );
}

class Purchase {
  final String? id;
  final String supplierId;
  final String supplierName;
  final String invoiceNo;
  final DateTime date;
  final List<PurchaseItem> items;
  final double totalAmount;
  final double gstAmount;
  final double roundingAmount;
  final bool isRoundingManual;
  final double grandTotal;
  final String uploadedByUserId;
  final String uploadedByUserName;
  final String shopId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Purchase({
    this.id,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNo,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.gstAmount,
    required this.roundingAmount,
    required this.isRoundingManual,
    required this.grandTotal,
    required this.uploadedByUserId,
    required this.uploadedByUserName,
    required this.shopId,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'supplierId': supplierId,
    'supplierName': supplierName,
    'invoiceNo': invoiceNo,
    'date': Timestamp.fromDate(date),
    'items': items.map((i) => i.toMap()).toList(),
    'totalAmount': totalAmount,
    'gstAmount': gstAmount,
    'roundingAmount': roundingAmount,
    'isRoundingManual': isRoundingManual,
    'grandTotal': grandTotal,
    'uploadedByUserId': uploadedByUserId,
    'uploadedByUserName': uploadedByUserName,
    'shopId': shopId,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
