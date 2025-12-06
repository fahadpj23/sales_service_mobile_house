import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'accessories_sale_upload.dart'; // Create these files
import 'phone_sale_upload.dart';
import 'second_phone_sale_upload.dart';
import 'base_model_sale_upload.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              Provider.of<AuthProvider>(context, listen: false).clearUser();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 25),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, ${user?.name ?? user?.email}!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sales Representative',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Text(
                  //   'ID: ${user?.id ?? 'N/A'}',
                  //   style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  // ),
                ],
              ),
            ),

            // Sales Upload Options Title
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Sales Upload Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),

            // Grid of Sales Options
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
                children: [
                  // Accessories Sale Upload
                  _buildSalesOptionCard(
                    context: context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Accessories and Service',
                    subtitle: 'Upload accessories & Service sales',
                    color: Colors.blue,
                    screen: AccessoriesSaleUpload(), // Create this widget
                  ),

                  // Phone Sale Upload
                  _buildSalesOptionCard(
                    context: context,
                    icon: Icons.phone_iphone,
                    title: 'Phone Sales',
                    subtitle: 'Upload new phone sales',
                    color: Colors.green,
                    screen: PhoneSaleUpload(), // Create this widget
                  ),

                  // Second Phone Sale Upload
                  _buildSalesOptionCard(
                    context: context,
                    icon: Icons.phone_android,
                    title: 'Second Phones',
                    subtitle: 'Upload used phone sales',
                    color: Colors.orange,
                    screen: SecondPhoneSaleUpload(), // Create this widget
                  ),

                  // Base Model Sale Upload
                  _buildSalesOptionCard(
                    context: context,
                    icon: Icons.devices,
                    title: 'Base Models',
                    subtitle: 'Upload base model sales',
                    color: Colors.purple,
                    screen: BaseModelSaleUpload(), // Create this widget
                  ),
                ],
              ),
            ),

            // View Sales History Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 20),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to sales history
                },
                icon: const Icon(Icons.history),
                label: const Text(
                  'View Sales History',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.green.shade400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build sales option card
  Widget _buildSalesOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
