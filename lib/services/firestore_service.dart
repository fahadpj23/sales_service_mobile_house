import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sales_stock/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== USER METHODS ==========
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return UserModel.fromMap({'uid': userId, ...data});
        }
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // ========== SUPPLIER METHODS ==========
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final snapshot = await _firestore
          .collection('suppliers')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching suppliers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSupplierById(String supplierId) async {
    try {
      final doc = await _firestore
          .collection('suppliers')
          .doc(supplierId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      print('Error getting supplier: $e');
      return null;
    }
  }

  Future<void> addSupplier(Map<String, dynamic> supplierData) async {
    try {
      await _firestore.collection('suppliers').add({
        ...supplierData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding supplier: $e');
      rethrow;
    }
  }

  Future<void> updateSupplier(
    String supplierId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating supplier: $e');
      rethrow;
    }
  }

  Future<void> deleteSupplier(String supplierId) async {
    try {
      await _firestore.collection('suppliers').doc(supplierId).delete();
    } catch (e) {
      print('Error deleting supplier: $e');
      rethrow;
    }
  }

  // ========== PRODUCT METHODS ==========
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final snapshot = await _firestore
          .collection('phones')
          .orderBy('productName')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('phones').doc(productId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  Future<void> addProduct(Map<String, dynamic> productData) async {
    try {
      await _firestore.collection('phones').add({
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> updateProductPurchaseRate(String productId, double rate) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'purchaseRate': rate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product purchase rate: $e');
      rethrow;
    }
  }

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

  Future<void> updateProductStock(String productId, int quantity) async {
    try {
      await _firestore.collection('phones').doc(productId).update({
        'stockQuantity': FieldValue.increment(quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product stock: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('phones').doc(productId).delete();
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  Future<double> getSellingPrice(String productId) async {
    try {
      final productDoc = await _firestore
          .collection('phones')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>?;
        return (data?['price'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting selling price: $e');
      return 0.0;
    }
  }

  // Add this method to your FirestoreService class

  Future<List<Map<String, dynamic>>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .where('purchaseDate', isGreaterThanOrEqualTo: startDate)
          .where('purchaseDate', isLessThanOrEqualTo: endOfDay)
          .orderBy('purchaseDate', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching purchases by date range: $e');
      rethrow;
    }
  }

  // ========== PURCHASE METHODS ==========
  Future<List<Map<String, dynamic>>> getPurchases() async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching purchases: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPurchasesByShop(String shopId) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching purchases by shop: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPurchaseById(String purchaseId) async {
    try {
      final doc = await _firestore
          .collection('purchases')
          .doc(purchaseId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      print('Error getting purchase: $e');
      return null;
    }
  }

  Future<String> createPurchase(Map<String, dynamic> purchaseData) async {
    try {
      final docRef = await _firestore.collection('purchases').add({
        ...purchaseData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating purchase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentPurchases(int limit) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error getting recent purchases: $e');
      return [];
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    try {
      await _firestore.collection('purchases').doc(purchaseId).delete();
    } catch (e) {
      print('Error deleting purchase: $e');
      rethrow;
    }
  }

  // ========== SHOP METHODS ==========
  Future<List<Map<String, dynamic>>> getUserShops() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _firestore
            .collection('shops')
            .where('employees', arrayContains: user.uid)
            .orderBy('name')
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting user shops: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCurrentShop() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData?['shopId'] != null) {
            final shopId = userData!['shopId'];
            final shopDoc = await _firestore
                .collection('shops')
                .doc(shopId)
                .get();

            if (shopDoc.exists) {
              final shopData = shopDoc.data() as Map<String, dynamic>;
              return {
                'id': shopDoc.id,
                'name': shopData['name'] ?? '',
                ...shopData,
              };
            }
          }
        }

        final userShops = await getUserShops();
        if (userShops.isNotEmpty) {
          return userShops.first;
        }
      }
      return null;
    } catch (e) {
      print('Error getting current shop: $e');
      return null;
    }
  }

  Future<void> updateCurrentShop(String shopId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'shopId': shopId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating current shop: $e');
      rethrow;
    }
  }

  Future<bool> hasShopAccess(String shopId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final shopDoc = await _firestore.collection('shops').doc(shopId).get();

      if (shopDoc.exists) {
        final data = shopDoc.data() as Map<String, dynamic>?;
        final employees = List<String>.from(data?['employees'] ?? []);
        return employees.contains(user.uid);
      }
      return false;
    } catch (e) {
      print('Error checking shop access: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getShopById(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      print('Error getting shop: $e');
      return null;
    }
  }

  Future<void> addShop(Map<String, dynamic> shopData) async {
    try {
      await _firestore.collection('shops').add({
        ...shopData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding shop: $e');
      rethrow;
    }
  }

  // ========== PHONE STOCK METHODS ==========
  Future<List<Map<String, dynamic>>> getPhoneStock() async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching phone stock: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPhoneStockByShop(String shopId) async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error fetching phone stock by shop: $e');
      return [];
    }
  }

  Future<void> addToPhoneStock(Map<String, dynamic> phoneData) async {
    try {
      await _firestore.collection('phoneStock').add({
        ...phoneData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to phone stock: $e');
      rethrow;
    }
  }

  Future<bool> checkIMEIExists(String imei) async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .where('imei', isEqualTo: imei)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking IMEI: $e');
      return false;
    }
  }

  Future<void> deletePhoneStockByPurchaseId(String purchaseId) async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .where('purchaseId', isEqualTo: purchaseId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting phone stock: $e');
      rethrow;
    }
  }

  Future<int> getPhoneStockCountByShop(String shopId) async {
    try {
      final snapshot = await _firestore
          .collection('phoneStock')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'available')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting phone stock count: $e');
      return 0;
    }
  }

  // ========== STATISTICS & REPORTS ==========
  Future<double> getTotalPurchaseValueByShop(String shopId) async {
    try {
      final snapshot = await _firestore
          .collection('purchases')
          .where('shopId', isEqualTo: shopId)
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['totalAmount'] != null) {
          total += (data['totalAmount'] as num).toDouble();
        }
      }

      return total;
    } catch (e) {
      print('Error getting total purchase value: $e');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getShopStatistics(String shopId) async {
    try {
      final phoneStockCount = await getPhoneStockCountByShop(shopId);
      final totalPurchaseValue = await getTotalPurchaseValueByShop(shopId);

      final recentPurchases = await _firestore
          .collection('purchases')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final monthlySnapshot = await _firestore
          .collection('purchases')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: firstDayOfMonth)
          .get();

      double monthlyTotal = 0.0;
      for (var doc in monthlySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['totalAmount'] != null) {
          monthlyTotal += (data['totalAmount'] as num).toDouble();
        }
      }

      return {
        'phoneStockCount': phoneStockCount,
        'totalPurchaseValue': totalPurchaseValue,
        'monthlyPurchaseValue': monthlyTotal,
        'recentPurchases': recentPurchases.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {'id': doc.id, ...data};
        }).toList(),
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('Error getting shop statistics: $e');
      return {
        'phoneStockCount': 0,
        'totalPurchaseValue': 0.0,
        'monthlyPurchaseValue': 0.0,
        'recentPurchases': [],
        'lastUpdated': DateTime.now(),
      };
    }
  }

  // ========== SEARCH METHODS ==========
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      if (query.isEmpty) return await getProducts();

      final snapshot = await _firestore
          .collection('phones')
          .where('productName', isGreaterThanOrEqualTo: query)
          .where('productName', isLessThan: query + 'z')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchSuppliers(String query) async {
    try {
      if (query.isEmpty) return await getSuppliers();

      final snapshot = await _firestore
          .collection('suppliers')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error searching suppliers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchPurchases(String query) async {
    try {
      if (query.isEmpty) return await getPurchases();

      final snapshot = await _firestore
          .collection('purchases')
          .where('invoiceNumber', isGreaterThanOrEqualTo: query)
          .where('invoiceNumber', isLessThan: query + 'z')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error searching purchases: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchPhoneStock({
    String? shopId,
    String? imei,
    String? productName,
    String? status,
  }) async {
    try {
      Query query = _firestore.collection('phoneStock');

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      if (imei != null && imei.isNotEmpty) {
        query = query.where('imei', isEqualTo: imei);
      }

      if (productName != null && productName.isNotEmpty) {
        query = query.where('productName', isEqualTo: productName);
      }

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('Error searching phone stock: $e');
      return [];
    }
  }

  // ========== BATCH OPERATIONS ==========
  Future<void> updateMultipleProductsStock(
    Map<String, int> productUpdates,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var entry in productUpdates.entries) {
        final productRef = _firestore.collection('phones').doc(entry.key);
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(entry.value),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating multiple products stock: $e');
      rethrow;
    }
  }

  Future<void> updatePhoneStockStatus(
    List<String> phoneIds,
    String newStatus,
  ) async {
    try {
      final batch = _firestore.batch();

      for (var phoneId in phoneIds) {
        final phoneRef = _firestore.collection('phoneStock').doc(phoneId);
        batch.update(phoneRef, {
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error updating phone stock status: $e');
      rethrow;
    }
  }

  // ========== VALIDATION METHODS ==========
  Future<bool> validateInvoiceNumber(
    String invoiceNumber,
    String? supplierId,
  ) async {
    try {
      Query query = _firestore
          .collection('purchases')
          .where('invoiceNumber', isEqualTo: invoiceNumber);

      if (supplierId != null) {
        query = query.where('supplierId', isEqualTo: supplierId);
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      print('Error validating invoice number: $e');
      return true;
    }
  }

  // ========== DASHBOARD DATA ==========
  Future<Map<String, dynamic>> getDashboardData(String shopId) async {
    try {
      final phoneStockCount = await getPhoneStockCountByShop(shopId);

      final productsSnapshot = await _firestore
          .collection('phones')
          .count()
          .get();

      final suppliersSnapshot = await _firestore
          .collection('suppliers')
          .count()
          .get();

      final recentPurchases = await getRecentPurchases(5);

      final lowStockSnapshot = await _firestore
          .collection('phones')
          .where('stockQuantity', isLessThan: 5)
          .limit(10)
          .get();

      final lowStockProducts = lowStockSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      return {
        'phoneStockCount': phoneStockCount,
        'productCount': productsSnapshot.count,
        'supplierCount': suppliersSnapshot.count,
        'recentPurchases': recentPurchases,
        'lowStockProducts': lowStockProducts,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('Error getting dashboard data: $e');
      return {
        'phoneStockCount': 0,
        'productCount': 0,
        'supplierCount': 0,
        'recentPurchases': [],
        'lowStockProducts': [],
        'lastUpdated': DateTime.now(),
      };
    }
  }

  // ========== TRANSACTION METHODS ==========
  Future<void> createPurchaseWithTransaction(
    Map<String, dynamic> purchaseData,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          ...purchaseData,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final items = purchaseData['items'] as List<dynamic>;
        for (var item in items) {
          final productId = item['productId'] as String;
          final quantity = item['quantity'] as int;

          final productRef = _firestore.collection('phones').doc(productId);
          transaction.update(productRef, {
            'stockQuantity': FieldValue.increment(quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error creating purchase with transaction: $e');
      rethrow;
    }
  }

  // ========== BACKUP/RESTORE ==========
  Future<Map<String, dynamic>> exportShopData(String shopId) async {
    try {
      final purchases = await _firestore
          .collection('purchases')
          .where('shopId', isEqualTo: shopId)
          .get();

      final phoneStock = await _firestore
          .collection('phoneStock')
          .where('shopId', isEqualTo: shopId)
          .get();

      return {
        'shopId': shopId,
        'exportDate': DateTime.now(),
        'purchases': purchases.docs.map((doc) => doc.data()).toList(),
        'phoneStock': phoneStock.docs.map((doc) => doc.data()).toList(),
        'totalRecords': purchases.docs.length + phoneStock.docs.length,
      };
    } catch (e) {
      print('Error exporting shop data: $e');
      rethrow;
    }
  }

  // ========== ANALYTICS ==========
  Future<Map<String, dynamic>> getPurchaseAnalytics({
    String? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('purchases');

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();

      double totalAmount = 0.0;
      double totalGst = 0.0;
      double totalDiscount = 0.0;
      int totalItems = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['totalAmount'] ?? 0).toDouble();
        totalGst += (data['gstAmount'] ?? 0).toDouble();
        totalDiscount += (data['totalDiscount'] ?? 0).toDouble();

        if (data['items'] != null) {
          totalItems += (data['items'] as List).length;
        }
      }

      return {
        'totalPurchases': snapshot.docs.length,
        'totalAmount': totalAmount,
        'totalGst': totalGst,
        'totalDiscount': totalDiscount,
        'totalItems': totalItems,
        'averagePurchaseValue': snapshot.docs.isEmpty
            ? 0
            : totalAmount / snapshot.docs.length,
        'period': {'startDate': startDate, 'endDate': endDate},
      };
    } catch (e) {
      print('Error getting purchase analytics: $e');
      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========
  Future<void> clearTestData() async {
    try {
      final collections = ['purchases', 'phoneStock', 'products', 'suppliers'];
      for (var collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error clearing test data: $e');
    }
  }

  Stream<QuerySnapshot> getPurchasesStream() {
    return _firestore
        .collection('purchases')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getProductsStream() {
    return _firestore.collection('phones').orderBy('productName').snapshots();
  }

  Stream<QuerySnapshot> getSuppliersStream() {
    return _firestore.collection('suppliers').orderBy('name').snapshots();
  }

  Stream<QuerySnapshot> getPhoneStockStream({String? shopId}) {
    Query query = _firestore
        .collection('phoneStock')
        .orderBy('createdAt', descending: true);

    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    return query.snapshots();
  }
}
