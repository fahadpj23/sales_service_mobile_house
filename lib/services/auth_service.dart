import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      print('Attempting to sign in with email: $email');

      // Sign in with Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('Firebase Auth successful, UID: ${userCredential.user!.uid}');

      if (userCredential.user != null) {
        // Get user data from Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        print('User document exists: ${userDoc.exists}');

        if (userDoc.exists) {
          // User exists in Firestore, return the user data
          UserModel userModel = UserModel.fromMap(
            userDoc.data() as Map<String, dynamic>,
          );
          print('User model created: ${userModel.email}');
          return userModel;
        } else {
          // User doesn't exist in Firestore, create a new user document
          print('User document not found, creating new user document...');
          await _createUserDocument(userCredential.user!);

          // Get the newly created user document
          DocumentSnapshot newUserDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (newUserDoc.exists) {
            UserModel userModel = UserModel.fromMap(
              newUserDoc.data() as Map<String, dynamic>,
            );
            print('New user document created: ${userModel.email}');
            return userModel;
          }
        }
      }

      print('Login failed - user is null');
      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      print('General login error: $e');
      throw 'Login failed. Please try again.';
    }
  }

  Future<void> _createUserDocument(User user) async {
    try {
      UserModel newUser = UserModel(
        uid: user.uid,
        email: user.email!,
        role: 'user', // Default role
        name: user.displayName ?? user.email!.split('@')[0],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

      print('User document created successfully for: ${user.uid}');
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

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
      default:
        return 'Login failed. Please check your credentials and try again.';
    }
  }

  // Sign up new user
  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String role,
    String? name,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      if (userCredential.user != null) {
        UserModel newUser = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          role: role,
          name: name ?? email.split('@')[0],
          createdAt: DateTime.now(),
        );

        // Save user to Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(newUser.toMap());

        return newUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Registration failed. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
