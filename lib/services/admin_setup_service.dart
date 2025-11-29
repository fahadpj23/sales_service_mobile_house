import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AdminSetupService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to create admin user
  Future<void> createAdminUser() async {
    try {
      const adminEmail = 'admin@example.com';
      const adminPassword = 'Admin123!'; // Change this to a strong password
      const adminName = 'Administrator';

      print('Starting admin user creation...');

      // Check if admin user already exists in Authentication
      try {
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        // If login successful, admin already exists
        print('Admin user already exists in Authentication');
        await _auth.signOut(); // Sign out after check
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Admin doesn't exist, proceed with creation
          print('Admin user not found, creating new admin...');
        } else {
          // Other error during sign in check
          print('Error checking admin user: ${e.message}');
          return;
        }
      }

      // Create admin user in Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );

      print(
        'Admin user created in Authentication: ${userCredential.user!.uid}',
      );

      // Create admin user document in Firestore
      UserModel adminUser = UserModel(
        uid: userCredential.user!.uid,
        email: adminEmail,
        role: 'admin',
        name: adminName,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(adminUser.toMap());

      print('Admin user document created in Firestore');

      // Sign out after creation
      await _auth.signOut();
      print('Admin user setup completed successfully');
    } catch (e) {
      print('Error creating admin user: $e');
      rethrow;
    }
  }

  // Method to check if admin exists
  Future<bool> checkAdminExists() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@example.com')
          .where('role', isEqualTo: 'admin')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking admin existence: $e');
      return false;
    }
  }
}
