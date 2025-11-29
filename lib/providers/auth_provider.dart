import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _initialize();
  }

  void _initialize() async {
    FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // User is signed in
        _user = await FirestoreService().getUser(firebaseUser.uid);
      } else {
        // User is signed out
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
