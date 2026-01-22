// services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/purchase_item.dart';

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

  // SUPPLIER METHODS
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching suppliers: $e');
      return [];
    }
  }

  // Get suppliers stream for real-time updates
  Stream<List<Map<String, dynamic>>> getSuppliersStream() {
    return _firestore.collection('suppliers').orderBy('name').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Add a new supplier
  Future<void> addSupplier(Map<String, dynamic> supplierData) async {
    try {
      await _firestore.collection('suppliers').add({
        ...supplierData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding supplier: $e');
      rethrow;
    }
  }

  // Update an existing supplier
  Future<void> updateSupplier(
    String supplierId,
    Map<String, dynamic> supplierData,
  ) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        ...supplierData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating supplier: $e');
      rethrow;
    }
  }

  // Delete a supplier
  Future<void> deleteSupplier(String supplierId) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).delete();
    } catch (e) {
      print('Error deleting supplier: $e');
      rethrow;
    }
  }

  // Get a single supplier by ID
  Future<Map<String, dynamic>?> getSupplierById(String supplierId) async {
    try {
      final doc = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        data?['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting supplier: $e');
      return null;
    }
  }

  // PRODUCT METHODS (Phones Collection)
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      // Simple query without ordering to avoid index requirement
      final snapshot = await _firestore.collection('phones').get();

      // Map documents to list
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort locally by brand and model
      products.sort((a, b) {
        final brandA = (a['brand'] ?? '').toString().toLowerCase();
        final brandB = (b['brand'] ?? '').toString().toLowerCase();
        final brandCompare = brandA.compareTo(brandB);

        if (brandCompare != 0) return brandCompare;

        final modelA = (a['model'] ?? '').toString().toLowerCase();
        final modelB = (b['model'] ?? '').toString().toLowerCase();
        return modelA.compareTo(modelB);
      });

      return products;
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  // Get products stream for real-time updates
  Stream<List<Map<String, dynamic>>> getProductsStream() {
    return _firestore.collection('phones').snapshots().map((snapshot) {
      // Map documents
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort locally by brand and model
      products.sort((a, b) {
        final brandA = (a['brand'] ?? '').toString().toLowerCase();
        final brandB = (b['brand'] ?? '').toString().toLowerCase();
        final brandCompare = brandA.compareTo(brandB);

        if (brandCompare != 0) return brandCompare;

        final modelA = (a['model'] ?? '').toString().toLowerCase();
        final modelB = (b['model'] ?? '').toString().toLowerCase();
        return modelA.compareTo(modelB);
      });

      return products;
    });
  }

  // Add a new product (phone)
  Future<String> addProduct(Map<String, dynamic> productData) async {
    try {
      final docRef = await _firestore.collection('phones').add({
        ...productData,
        'purchaseRate': productData['purchaseRate'] ?? 0.0,
        'sellingPrice': productData['sellingPrice'] ?? 0.0,
        'stockQuantity': productData['stockQuantity'] ?? 0,
        'hsnCode': productData['hsnCode'] ?? '', // Include HSN code field
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  // Update product purchase rate
  Future<void> updateProductPurchaseRate(
    String productId,
    double purchaseRate,
  ) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'purchaseRate': purchaseRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product purchase rate: $e');
      rethrow;
    }
  }

  // Update product HSN code
  Future<void> updateProductHsnCode(String productId, String hsnCode) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'hsnCode': hsnCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product HSN code: $e');
      rethrow;
    }
  }

  // Update product selling price
  Future<void> updateProductSellingPrice(
    String productId,
    double sellingPrice,
  ) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'sellingPrice': sellingPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product selling price: $e');
      rethrow;
    }
  }

  // Update product stock quantity (increase when purchased)
  Future<void> updateProductStock(String productId, int quantityToAdd) async {
    try {
      final doc = await _firestore.collection('phones').doc(productId).get();
      if (doc.exists) {
        final currentStock = doc.data()?['stockQuantity'] ?? 0;
        await _firestore.collection('phones').doc(productId).update({
          'stockQuantity': currentStock + quantityToAdd,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating product stock: $e');
      rethrow;
    }
  }

  // Update product stock quantity (set specific value)
  Future<void> setProductStock(String productId, int newStockQuantity) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'stockQuantity': newStockQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error setting product stock: $e');
      rethrow;
    }
  }

  // Get a single product by ID
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('phones').doc(productId).get();
      if (doc.exists) {
        final data = doc.data();
        data?['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('phones').doc(productId).delete();
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  // PURCHASE METHODS
  Future<void> createPurchase(Map<String, dynamic> purchaseData) async {
    try {
      // First, add the purchase document
      final purchaseRef = await _firestore.collection('purchases').add({
        ...purchaseData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final purchaseId = purchaseRef.id;

      // Update stock for each product in the purchase
      final List<Map<String, dynamic>> items = purchaseData['items'];
      for (var item in items) {
        if (item['productId'] != null && item['quantity'] != null) {
          await updateProductStock(item['productId'], item['quantity'].toInt());
        }
      }
    } catch (e) {
      print('Error creating purchase: $e');
      rethrow;
    }
  }

  // Get all purchases
  Stream<List<Map<String, dynamic>>> getPurchasesStream() {
    return _firestore
        .collection('purchases')
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['purchaseDate'] = (data['purchaseDate'] as Timestamp).toDate();
            return data;
          }).toList();
        });
  }

  // Get purchases by supplier
  Stream<List<Map<String, dynamic>>> getPurchasesBySupplier(String supplierId) {
    return _firestore
        .collection('purchases')
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['purchaseDate'] = (data['purchaseDate'] as Timestamp).toDate();
            return data;
          }).toList();
        });
  }

  // Get single purchase by ID
  Future<Map<String, dynamic>?> getPurchaseById(String purchaseId) async {
    try {
      final doc = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        data?['id'] = doc.id;
        if (data?['purchaseDate'] != null) {
          data?['purchaseDate'] = (data?['purchaseDate'] as Timestamp).toDate();
        }
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting purchase: $e');
      return null;
    }
  }

  // Delete a purchase and adjust stock
  Future<void> deletePurchase(String purchaseId) async {
    try {
      // Get purchase data first
      final purchase = await getPurchaseById(purchaseId);
      if (purchase != null) {
        // Adjust stock for each item
        final List<Map<String, dynamic>> items = purchase['items'];
        for (var item in items) {
          if (item['productId'] != null && item['quantity'] != null) {
            final product = await getProductById(item['productId']);
            if (product != null) {
              final currentStock = product['stockQuantity'] ?? 0;
              final quantityToRemove = item['quantity'].toInt();
              await _firestore
                  .collection('phones')
                  .doc(item['productId'])
                  .update({
                    'stockQuantity': currentStock - quantityToRemove,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
            }
          }
        }

        // Delete the purchase
        await _firestore.collection('purchases').doc(purchaseId).delete();
      }
    } catch (e) {
      print('Error deleting purchase: $e');
      rethrow;
    }
  }

  Future<List<QueryDocumentSnapshot>> getPurchases() async {
    try {
      final querySnapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs;
    } catch (e) {
      print('Error fetching purchases: $e');
      rethrow;
    }
  }

  // Get purchase statistics
  Future<Map<String, dynamic>> getPurchaseStatistics() async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Monthly purchases
      final monthlySnapshot = await _firestore
          .collection('purchases')
          .where('purchaseDate', isGreaterThanOrEqualTo: firstDayOfMonth)
          .where('purchaseDate', isLessThanOrEqualTo: lastDayOfMonth)
          .get();

      double monthlyTotal = 0;
      int monthlyItems = 0;

      for (var doc in monthlySnapshot.docs) {
        final data = doc.data();
        monthlyTotal += data['totalAmount'] ?? 0;
        final items = data['items'] as List<dynamic>;
        monthlyItems += items.length;
      }

      // All-time purchases
      final allTimeSnapshot = await _firestore.collection('purchases').get();

      double allTimeTotal = 0;
      int allTimeItems = 0;

      for (var doc in allTimeSnapshot.docs) {
        final data = doc.data();
        allTimeTotal += data['totalAmount'] ?? 0;
        final items = data['items'] as List<dynamic>;
        allTimeItems += items.length;
      }

      return {
        'monthlyTotal': monthlyTotal,
        'monthlyItems': monthlyItems,
        'allTimeTotal': allTimeTotal,
        'allTimeItems': allTimeItems,
        'monthlyGST': monthlyTotal * 0.18,
        'allTimeGST': allTimeTotal * 0.18,
      };
    } catch (e) {
      print('Error getting purchase statistics: $e');
      return {
        'monthlyTotal': 0.0,
        'monthlyItems': 0,
        'allTimeTotal': 0.0,
        'allTimeItems': 0,
        'monthlyGST': 0.0,
        'allTimeGST': 0.0,
      };
    }
  }
}
