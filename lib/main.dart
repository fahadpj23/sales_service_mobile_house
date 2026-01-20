import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:sales_stock/screens/finance_dashboard.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/user_dashboard.dart';

// TODO: Add your Firebase configuration here
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBPt3fdES0hRN8Qmt-4naWavpK-p2QW3Xc",
      authDomain: "mobilehousewebsite.firebaseapp.com",
      databaseURL: "https://mobilehousewebsite-default-rtdb.firebaseio.com",
      projectId: "mobilehousewebsite",
      storageBucket: "mobilehousewebsite.firebasestorage.app",
      messagingSenderId: "27265006915",
      appId: "1:27265006915:web:e3c6adb5a9ea20d832c3f6",
    ),
  );

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
    print(authProvider);
    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.user == null) {
      return const LoginScreen();
    }
    print(authProvider.user!.role);
    // Check user role and navigate accordingly
    if (authProvider.user!.role == 'admin') {
      return AdminDashboardScreen();
    } else if (authProvider.user!.role == 'user') {
      return const UserDashboard();
    } else {
      return FinanceDashboard();
    }
  }
}
