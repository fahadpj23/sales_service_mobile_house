import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'accessories_sale_upload.dart';
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

            // Grid of Sales Options with auto-sizing
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive layout based on available space
                  final crossAxisCount = constraints.maxWidth > 600 ? 2 : 2;
                  final spacing = constraints.maxWidth < 350 ? 8.0 : 16.0;
                  final childAspectRatio = constraints.maxWidth < 350
                      ? 1.0
                      : 1.2;

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return _buildResponsiveSalesOptionCard(
                        context: context,
                        index: index,
                        maxWidth: constraints.maxWidth,
                      );
                    },
                  );
                },
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

  Widget _buildResponsiveSalesOptionCard({
    required BuildContext context,
    required int index,
    required double maxWidth,
  }) {
    final List<Map<String, dynamic>> options = [
      {
        'icon': Icons.shopping_bag_outlined,
        'title': 'Accessories and Service',
        'subtitle': 'Upload accessories & Service sales',
        'color': Colors.blue,
        'screen': const AccessoriesSaleUpload(),
      },
      {
        'icon': Icons.phone_iphone,
        'title': 'Phone Sales',
        'subtitle': 'Upload new phone sales',
        'color': Colors.green,
        'screen': const PhoneSaleUpload(),
      },
      {
        'icon': Icons.phone_android,
        'title': 'Second Phones',
        'subtitle': 'Upload used phone sales',
        'color': Colors.orange,
        'screen': const SecondPhoneSaleUpload(),
      },
      {
        'icon': Icons.devices,
        'title': 'Base Models',
        'subtitle': 'Upload base model sales',
        'color': Colors.purple,
        'screen': const BaseModelSaleUpload(),
      },
    ];

    final option = options[index];

    // Calculate responsive sizes based on available width
    final iconSize = maxWidth < 350 ? 24.0 : 28.0;
    final iconContainerSize = maxWidth < 350 ? 48.0 : 56.0;
    final titleFontSize = maxWidth < 350 ? 13.0 : 15.0;
    final subtitleFontSize = maxWidth < 350 ? 10.0 : 12.0;
    final padding = maxWidth < 350 ? 8.0 : 12.0;
    final spacing = maxWidth < 350 ? 6.0 : 10.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => option['screen'] as Widget),
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
              colors: [
                (option['color'] as Color).withOpacity(0.1),
                (option['color'] as Color).withOpacity(0.05),
              ],
            ),
          ),
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: (option['color'] as Color).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option['icon'] as IconData,
                  size: iconSize,
                  color: option['color'] as Color,
                ),
              ),
              SizedBox(height: spacing),

              // Title with auto-sizing
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth * 0.4 - (padding * 2),
                    ),
                    child: Text(
                      option['title'] as String,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: option['color'] as Color,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              SizedBox(height: spacing / 2),

              // Subtitle with auto-sizing
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth * 0.4 - (padding * 2),
                    ),
                    child: Text(
                      option['subtitle'] as String,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Alternative version with AutoSizeText package (if you want to add it)
  // First add to pubspec.yaml: auto_size_text: ^3.0.0
  /*
  Widget _buildAutoSizeSalesOptionCard({
    required BuildContext context,
    required int index,
  }) {
    final List<Map<String, dynamic>> options = [
      // ... same options array
    ];

    final option = options[index];
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => option['screen'] as Widget),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (option['color'] as Color).withOpacity(0.1),
                (option['color'] as Color).withOpacity(0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (option['color'] as Color).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  option['icon'] as IconData,
                  size: 28,
                  color: option['color'] as Color,
                ),
              ),
              const SizedBox(height: 10),
              
              // Title with AutoSizeText
              Expanded(
                child: AutoSizeText(
                  option['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: option['color'] as Color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  minFontSize: 10,
                  maxFontSize: 16,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 5),
              
              // Subtitle with AutoSizeText
              Expanded(
                child: AutoSizeText(
                  option['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  minFontSize: 8,
                  maxFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  */
}
