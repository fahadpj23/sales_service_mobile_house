import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/finance_dashboard.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/purchase_dashboard.dart';

// Centralised Firebase options so it can be reused by secondary apps
// (e.g., the 'userCreator' app used in UserManagementScreen).
const FirebaseOptions kFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyBPt3fdES0hRN8Qmt-4naWavpK-p2QW3Xc",
  authDomain: "mobilehousewebsite.firebaseapp.com",
  databaseURL: "https://mobilehousewebsite-default-rtdb.firebaseio.com",
  projectId: "mobilehousewebsite",
  storageBucket: "mobilehousewebsite.firebasestorage.app",
  messagingSenderId: "27265006915",
  appId: "1:27265006915:web:e3c6adb5a9ea20d832c3f6",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: kFirebaseOptions);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'Sales App',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = authProvider.user;

    // Not logged in → login screen
    if (user == null) {
      return const LoginScreen();
    }

    // Logged in but with an unrecognised role → force re-login
    switch (user.role) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'user':
        return const UserDashboard();
      case 'finance':
        return const FinanceDashboard();
      case 'purchaser':
        return const PurchaseDashboardScreen();
      default:
        // Invalid / missing role — treat as a configuration error
        // and send the user back to login.
        return const LoginScreen();
    }
  }
}
