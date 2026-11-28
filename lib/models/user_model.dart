// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? shopId;
  final String? shopName;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.shopId,
    this.shopName,
    required this.createdAt,
  });

  // ---------------------------------------------------------------
  // TO MAP (Firestore write)
  // ---------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': uid, // matches sample data (has both id + uid)
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'shopId': shopId,
      'shopName': shopName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------------------------------------------------------
  // FROM MAP (Firestore read — null-safe)
  // ---------------------------------------------------------------
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? 'user').toString(),
      shopId: map['shopId'] as String?,
      shopName: map['shopName'] as String?,
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }

  // ---------------------------------------------------------------
  // COPY WITH
  // ---------------------------------------------------------------
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? shopId,
    String? shopName,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------
  // ROLE HELPERS
  // ---------------------------------------------------------------
  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';
  bool get isFinance => role == 'finance';
  bool get isPurchaser => role == 'purchaser';

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, name: $name, role: $role, '
      'shopId: $shopId, shopName: $shopName, createdAt: $createdAt)';
}
