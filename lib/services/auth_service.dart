// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // SIGN IN — requires existing Firestore profile
  // ============================================================
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      print('Attempting to sign in with email: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        print('Login failed - user is null');
        return null;
      }

      print('Firebase Auth successful, UID: ${user.uid}');

      // Fetch the Firestore profile. If it doesn't exist, deny access.
      final docRef = _firestore.collection('users').doc(user.uid);
      final snap = await docRef.get();

      if (!snap.exists) {
        // No profile → sign out so they can't stay half-authenticated.
        await _auth.signOut();
        throw 'Your account has no profile. Please contact the admin to '
            'create your user record.';
      }

      final data = snap.data()!;

      // Guard: required fields must be present (role especially).
      if ((data['role'] ?? '').toString().isEmpty) {
        await _auth.signOut();
        throw 'Your account has no role assigned. Please contact the admin.';
      }

      print('Existing user loaded: ${data['email']}');
      return UserModel.fromMap(data);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // ============================================================
  // SIGN UP (public self-signup — optional)
  // ============================================================
  /// Kept for compatibility. Note: this is NOT used by the admin screen,
  /// which creates accounts via a secondary FirebaseApp with explicit role.
  /// Caller must supply a role; there is no default.
  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String role,
    String name, {
    String? shopId,
    String? shopName,
  }) async {
    if (role.trim().isEmpty) {
      throw 'Role is required.';
    }
    if (name.trim().isEmpty) {
      throw 'Name is required.';
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      final uid = user.uid;
      final newUser = UserModel(
        uid: uid,
        email: email.trim().toLowerCase(),
        role: role,
        name: name,
        createdAt: DateTime.now(),
        shopId: shopId,
        shopName: shopName,
      );

      final userMap = newUser.toMap();
      userMap['id'] = uid;
      userMap['uid'] = uid;
      userMap['createdAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(uid)
          .set(userMap, SetOptions(merge: true));

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Registration failed. Please try again.';
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ============================================================
  // CURRENT USER
  // ============================================================
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ============================================================
  // ERROR MESSAGES
  // ============================================================
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      default:
        return 'Login failed. Please check your credentials and try again.';
    }
  }
}
