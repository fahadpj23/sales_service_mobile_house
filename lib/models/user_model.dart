import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? shopId; // Optional shop ID
  final String? shopName; // Optional shop ID
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.shopId, // Optional parameter
    this.shopName, // Optional parameter
    required this.createdAt,
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'shopId': shopId, // Will be null if not provided
      'shopName': shopName, // Will be null if not provided
      'createdAt': createdAt,
    };
  }

  // Create UserModel from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'user',
      shopId: map['shopId'], // Can be null
      shopName: map['shopName'], // Can be null
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is DateTime) {
      return timestamp;
    } else {
      return DateTime.now();
    }
  }

  bool get isAdmin => role == 'admin';
}
