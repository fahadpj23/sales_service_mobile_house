import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user data
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Upload sales data
  Future<void> uploadSalesData({
    required String userId,
    required String customerName,
    required String product,
    required int quantity,
    required double unitPrice,
    required double saleAmountTotal,
    required double serviceAmountTotal,
    required DateTime saleDate,
  }) async {
    try {
      await _firestore.collection('sales').add({
        'userId': userId,
        'customerName': customerName,
        'product': product,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'saleAmountTotal': saleAmountTotal,
        'serviceAmountTotal': serviceAmountTotal,
        'grandTotal': saleAmountTotal + serviceAmountTotal,
        'saleDate': saleDate.millisecondsSinceEpoch,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to upload sales data: $e');
    }
  }

  // Get all sales (for admin)
  Stream<QuerySnapshot> getAllSales() {
    return _firestore
        .collection('sales')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Get user's sales
  Stream<QuerySnapshot> getUserSales(String userId) {
    return _firestore
        .collection('sales')
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }
}
