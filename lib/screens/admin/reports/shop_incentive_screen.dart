// screens/admin/incentive/shop_incentive_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/sale.dart';

class ShopIncentiveScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final List<Sale> allSales;
  final Function(double) formatNumber;

  const ShopIncentiveScreen({
    super.key,
    required this.shops,
    required this.allSales,
    required this.formatNumber,
  });

  @override
  State<ShopIncentiveScreen> createState() => _ShopIncentiveScreenState();
}

class _ShopIncentiveScreenState extends State<ShopIncentiveScreen> {
  String selectedTimePeriod = 'monthly';
  DateTime? customStartDate;
  DateTime? customEndDate;
  bool isCustomPeriod = false;
  Map<String, ShopIncentiveData> shopIncentives = {};

  @override
  void initState() {
    super.initState();
    _calculateAllShopIncentives();
  }

  void _calculateAllShopIncentives() {
    setState(() {
      shopIncentives.clear();

      for (var shop in widget.shops) {
        String shopId = shop['id'];
        String shopName = shop['name'];

        // Filter sales for this shop
        List<Sale> shopSales = widget.allSales
            .where((sale) => sale.shopId == shopId || sale.shopName == shopName)
            .toList();

        // Filter by time period
        List<Sale> filteredSales = _filterSalesByPeriod(shopSales);

        // Calculate incentive for this shop (even if zero)
        ShopIncentiveData incentiveData = _calculateShopIncentive(
          shopName,
          filteredSales,
        );

        // Always add the shop to the map, even if incentive is zero
        shopIncentives[shopId] = incentiveData;
      }
    });
  }

  List<Sale> _filterSalesByPeriod(List<Sale> sales) {
    DateTime startDate;
    DateTime endDate;
    final now = DateTime.now();

    if (isCustomPeriod && customStartDate != null && customEndDate != null) {
      startDate = DateTime(
        customStartDate!.year,
        customStartDate!.month,
        customStartDate!.day,
        0,
        0,
        0,
      );
      endDate = DateTime(
        customEndDate!.year,
        customEndDate!.month,
        customEndDate!.day,
        23,
        59,
        59,
        999,
      );
    } else {
      switch (selectedTimePeriod) {
        case 'daily':
          startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 'yearly':
          startDate = DateTime(now.year, 1, 1, 0, 0, 0);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      }
    }

    return sales.where((sale) {
      DateTime saleDate = sale.date;
      return saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          saleDate.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();
  }

  ShopIncentiveData _calculateShopIncentive(String shopName, List<Sale> sales) {
    // Calculate Accessories & Service Incentive
    double accessoriesTotal = sales
        .where((s) => s.type == 'accessories_service_sale')
        .fold(0.0, (sum, s) => sum + s.amount);

    double accessoriesIncentive = _calculateAccessoriesIncentive(
      accessoriesTotal,
    );

    // Calculate Phone Sales Incentive
    List<Sale> phoneSales = sales.where((s) => s.type == 'phone_sale').toList();
    double phoneTotalAmount = phoneSales.fold(0.0, (sum, s) => sum + s.amount);
    int phoneCount = phoneSales.length;
    double phoneIncentive = _calculatePhoneIncentive(
      phoneSales,
      phoneCount,
      phoneTotalAmount,
    );

    // Calculate Second Phone Incentive (1-10: ₹30, 10+: ₹40, No minimum)
    List<Sale> secondPhoneSales = sales
        .where((s) => s.type == 'seconds_phone_sale')
        .toList();
    int secondPhoneCount = secondPhoneSales.length;
    double secondPhoneIncentive = _calculateSecondPhoneIncentive(
      secondPhoneCount,
    );

    // Calculate Base Model Incentive (1-10: ₹15, 10+: ₹25, No minimum)
    List<Sale> baseModelSales = sales
        .where((s) => s.type == 'base_model_sale')
        .toList();
    int baseModelCount = baseModelSales.length;
    double baseModelIncentive = _calculateBaseModelIncentive(baseModelCount);

    return ShopIncentiveData(
      shopName: shopName,
      totalSales: sales.fold(0.0, (sum, s) => sum + s.amount),
      accessoriesTotal: accessoriesTotal,
      accessoriesIncentive: accessoriesIncentive,
      phoneTotalAmount: phoneTotalAmount,
      phoneCount: phoneCount,
      phoneIncentive: phoneIncentive,
      phonePriceDetails: _getPhonePriceDetails(phoneSales),
      secondPhoneCount: secondPhoneCount,
      secondPhoneIncentive: secondPhoneIncentive,
      baseModelCount: baseModelCount,
      baseModelIncentive: baseModelIncentive,
      totalIncentive:
          accessoriesIncentive +
          phoneIncentive +
          secondPhoneIncentive +
          baseModelIncentive,
    );
  }

  // Updated: Accessories Incentive - ₹1000 base + ₹200 per ₹10,000 above ₹1L
  double _calculateAccessoriesIncentive(double totalAmount) {
    if (totalAmount <= 100000) return 0;

    double incentive = 1000;
    final amountAboveLakh = totalAmount - 100000;
    final additionalThousands = (amountAboveLakh / 10000).floor();
    incentive += additionalThousands * 200; // Changed from 300 to 200

    return incentive;
  }

  double _calculatePhoneIncentive(
    List<Sale> phoneSales,
    int count,
    double totalAmount,
  ) {
    if (count < 20 || totalAmount < 300000) return 0;

    double totalIncentive = 0;
    for (var sale in phoneSales) {
      double price = sale.amount;
      if (price < 15000) {
        totalIncentive += 30;
      } else if (price < 25000) {
        totalIncentive += 40;
      } else if (price < 35000) {
        totalIncentive += 50;
      } else if (price < 45000) {
        totalIncentive += 80;
      } else if (price < 60000) {
        totalIncentive += 100;
      } else if (price < 80000) {
        totalIncentive += 150;
      } else {
        totalIncentive += 200;
      }
    }
    return totalIncentive;
  }

  double _calculateSecondPhoneIncentive(int count) {
    if (count == 0) return 0;
    // 1-10 pieces: ₹30 per piece, Above 10 pieces: ₹40 per piece
    return count <= 10 ? count * 30 : count * 40;
  }

  double _calculateBaseModelIncentive(int count) {
    if (count == 0) return 0;
    // 1-10 pieces: ₹15 per piece, Above 10 pieces: ₹25 per piece
    return count <= 10 ? count * 15 : count * 25;
  }

  List<Map<String, dynamic>> _getPhonePriceDetails(List<Sale> phoneSales) {
    List<Map<String, dynamic>> details = [];
    for (var sale in phoneSales) {
      double price = sale.amount;
      String bracket;
      double incentive;
      if (price < 15000) {
        bracket = 'Below ₹15,000';
        incentive = 30;
      } else if (price < 25000) {
        bracket = '₹15,000 - ₹24,999';
        incentive = 40;
      } else if (price < 35000) {
        bracket = '₹25,000 - ₹34,999';
        incentive = 50;
      } else if (price < 45000) {
        bracket = '₹35,000 - ₹44,999';
        incentive = 80;
      } else if (price < 60000) {
        bracket = '₹45,000 - ₹59,999';
        incentive = 100;
      } else if (price < 80000) {
        bracket = '₹60,000 - ₹79,999';
        incentive = 150;
      } else {
        bracket = '₹80,000+';
        incentive = 200;
      }
      details.add({
        'productName': sale.itemName,
        'price': price,
        'bracket': bracket,
        'incentive': incentive,
        'customerName': sale.customerName,
        'date': sale.date,
      });
    }
    return details;
  }

  // Show Incentive Conditions (same as IncentiveScreen)
  void _showConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Incentive Conditions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPeriodDisplayText(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          _buildConditionCard(
                            title: 'Accessories & Service',
                            icon: Icons.shopping_bag,
                            color: Colors.blue,
                            rules: [
                              '🎯 Base Incentive: ₹1,000 when sales exceed ₹1,00,000',
                              '📈 Additional: ₹200 for every ₹10,000 above ₹1,00,000',
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildConditionCard(
                            title: 'Phone Sales',
                            icon: Icons.phone_iphone,
                            color: Colors.green,
                            rules: [
                              '🎯 Qualification: 20+ phones AND ₹3,00,000+ total value',
                              '📱 Per Phone Incentive (based on price) after qualification:',
                              '   • Below ₹15,000 → ₹30',
                              '   • ₹15,000 - ₹24,999 → ₹40',
                              '   • ₹25,000 - ₹34,999 → ₹50',
                              '   • ₹35,000 - ₹44,999 → ₹80',
                              '   • ₹45,000 - ₹59,999 → ₹100',
                              '   • ₹60,000 - ₹79,999 → ₹150',
                              '   • ₹80,000+ → ₹200',
                              '⚠️ Note: No base incentive, only per-phone incentives',
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildConditionCard(
                            title: 'Second Phones',
                            icon: Icons.phone_android,
                            color: Colors.orange,
                            rules: [
                              '💰 Incentive Structure (per piece):',
                              '   • 1-10 pieces → ₹30 per piece',
                              '   • Above 10 pieces → ₹40 per piece',
                              '✨ No minimum quantity required',
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildConditionCard(
                            title: 'Base Models',
                            icon: Icons.devices,
                            color: Colors.purple,
                            rules: [
                              '💰 Incentive Structure (per piece):',
                              '   • 1-10 pieces → ₹15 per piece',
                              '   • Above 10 pieces → ₹25 per piece',
                              '✨ No minimum quantity required',
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4D2E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Got it', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConditionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> rules,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rules
                  .map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        rule,
                        style: const TextStyle(fontSize: 10, height: 1.4),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodDisplayText() {
    final now = DateTime.now();
    if (isCustomPeriod && customStartDate != null && customEndDate != null) {
      return '${DateFormat('dd MMM yyyy').format(customStartDate!)} - ${DateFormat('dd MMM yyyy').format(customEndDate!)}';
    }
    switch (selectedTimePeriod) {
      case 'daily':
        return DateFormat('dd MMM yyyy').format(now);
      case 'monthly':
        return DateFormat('MMMM yyyy').format(now);
      case 'yearly':
        return DateFormat('yyyy').format(now);
      default:
        return DateFormat('MMMM yyyy').format(now);
    }
  }

  void _showShopIncentiveDetails(ShopIncentiveData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.store,
                        color: Color(0xFF0A4D2E),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A4D2E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${widget.formatNumber(data.totalIncentive)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A4D2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Total Sales: ₹${widget.formatNumber(data.totalSales)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          _buildIncentiveDetailCard(
                            title: 'Accessories & Service',
                            icon: Icons.shopping_bag,
                            color: Colors.blue,
                            totalAmount: data.accessoriesTotal,
                            incentive: data.accessoriesIncentive,
                            rule: 'Above ₹1,00,000: ₹1000 + ₹200/₹10k',
                            calculation: _getAccessoriesCalculation(
                              data.accessoriesTotal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Phone Sales',
                            icon: Icons.phone_iphone,
                            color: Colors.green,
                            totalAmount: data.phoneTotalAmount,
                            count: data.phoneCount,
                            incentive: data.phoneIncentive,
                            rule: '20+ phones & ₹3L+: Only per-phone incentive',
                            calculation: _getPhoneCalculation(data),
                            showDetails: true,
                            details: data.phonePriceDetails,
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Second Phones',
                            icon: Icons.phone_android,
                            color: Colors.orange,
                            count: data.secondPhoneCount,
                            incentive: data.secondPhoneIncentive,
                            rule: data.secondPhoneCount == 0
                                ? 'No sales recorded'
                                : (data.secondPhoneCount <= 10
                                      ? '₹30/piece (1-10 pieces)'
                                      : '₹40/piece (10+ pieces)'),
                            calculation: data.secondPhoneCount > 0
                                ? '${data.secondPhoneCount} × ${data.secondPhoneCount <= 10 ? '₹30' : '₹40'} = ₹${widget.formatNumber(data.secondPhoneIncentive)}'
                                : 'No second phone sales',
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Base Models',
                            icon: Icons.devices,
                            color: Colors.purple,
                            count: data.baseModelCount,
                            incentive: data.baseModelIncentive,
                            rule: data.baseModelCount == 0
                                ? 'No sales recorded'
                                : (data.baseModelCount <= 10
                                      ? '₹15/piece (1-10 pieces)'
                                      : '₹25/piece (10+ pieces)'),
                            calculation: data.baseModelCount > 0
                                ? '${data.baseModelCount} × ${data.baseModelCount <= 10 ? '₹15' : '₹25'} = ₹${widget.formatNumber(data.baseModelIncentive)}'
                                : 'No base model sales',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4D2E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getAccessoriesCalculation(double totalAmount) {
    if (totalAmount <= 100000)
      return 'Not qualified (need > ₹1,00,000, currently ₹${widget.formatNumber(totalAmount)})';
    double incentive = 1000;
    final amountAboveLakh = totalAmount - 100000;
    final additionalThousands = (amountAboveLakh / 10000).floor();
    if (additionalThousands > 0) {
      incentive += additionalThousands * 200; // Changed from 300 to 200
      return '₹1000 + ($additionalThousands × ₹200) = ₹${widget.formatNumber(incentive)}';
    }
    return '₹1000 base incentive';
  }

  String _getPhoneCalculation(ShopIncentiveData data) {
    if (data.phoneCount < 20 || data.phoneTotalAmount < 300000) {
      if (data.phoneCount < 20 && data.phoneTotalAmount < 300000) {
        return 'Not qualified (need 20+ phones and ₹3L+ value) | Current: ${data.phoneCount} phones, ₹${widget.formatNumber(data.phoneTotalAmount)}';
      } else if (data.phoneCount < 20) {
        return 'Not qualified (need ${20 - data.phoneCount} more phones)';
      } else {
        return 'Not qualified (need ₹${widget.formatNumber(300000 - data.phoneTotalAmount)} more value)';
      }
    }
    return 'Qualified! Per-phone incentives total: ₹${widget.formatNumber(data.phoneIncentive)}';
  }

  Widget _buildIncentiveDetailCard({
    required String title,
    required IconData icon,
    required Color color,
    double totalAmount = 0,
    int count = 0,
    double incentive = 0,
    required String rule,
    required String calculation,
    bool showDetails = false,
    List<Map<String, dynamic>>? details,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: incentive > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    incentive > 0 ? '₹${widget.formatNumber(incentive)}' : '₹0',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: incentive > 0
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (totalAmount > 0 || count > 0)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (totalAmount > 0)
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Total Sales',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${widget.formatNumber(totalAmount)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (totalAmount > 0 && count > 0)
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.grey.shade200,
                          ),
                        if (count > 0)
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Units Sold',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (totalAmount == 0 && count == 0)
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No sales data',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rule,
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        size: 12,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          calculation,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDetails && details != null && details.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Phone-wise Breakdown:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...details
                          .take(5)
                          .map(
                            (phone) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          phone['productName'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          phone['bracket'],
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${widget.formatNumber(phone['price'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '+₹${phone['incentive']}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (details.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${details.length - 5} more phones',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total incentive across all shops
    double totalIncentiveAllShops = shopIncentives.values.fold(
      0.0,
      (sum, data) => sum + data.totalIncentive,
    );
    int totalShopsWithIncentive = shopIncentives.values
        .where((data) => data.totalIncentive > 0)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop Incentive Report',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0A4D2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: _showConditions,
            tooltip: 'View Conditions',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showTimePeriodDialog,
            tooltip: 'Select Period',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _calculateAllShopIncentives(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTimePeriodSelector(),

          // Total Incentive Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A4D2E), Color(0xFF1B6B43)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Incentive',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPeriodDisplayText(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${widget.formatNumber(totalIncentiveAllShops)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Across ${shopIncentives.length} shops',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$totalShopsWithIncentive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Earned',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (totalShopsWithIncentive > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: totalShopsWithIncentive / shopIncentives.length,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    color: Colors.amber,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(totalShopsWithIncentive / shopIncentives.length * 100).toInt()}% shops earned incentives',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: shopIncentives.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No shops available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: shopIncentives.length,
                    itemBuilder: (context, index) {
                      final entry = shopIncentives.values.toList()[index];
                      return GestureDetector(
                        onTap: () => _showShopIncentiveDetails(entry),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: entry.totalIncentive > 0
                                ? Colors.white
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: entry.totalIncentive > 0
                                  ? const Color(0xFF0A4D2E).withOpacity(0.2)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: entry.totalIncentive > 0
                                                ? const Color(
                                                    0xFF0A4D2E,
                                                  ).withOpacity(0.1)
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.store,
                                            color: entry.totalIncentive > 0
                                                ? const Color(0xFF0A4D2E)
                                                : Colors.grey.shade500,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            entry.shopName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: entry.totalIncentive > 0
                                                  ? const Color(0xFF0A4D2E)
                                                  : Colors.grey.shade700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.totalIncentive > 0
                                          ? const Color(
                                              0xFF0A4D2E,
                                            ).withOpacity(0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      entry.totalIncentive > 0
                                          ? '₹${widget.formatNumber(entry.totalIncentive)}'
                                          : '₹0',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: entry.totalIncentive > 0
                                            ? const Color(0xFF0A4D2E)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildMiniStat(
                                    'Accessories',
                                    entry.accessoriesIncentive,
                                    Colors.blue,
                                    entry.totalIncentive > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildMiniStat(
                                    'Phones',
                                    entry.phoneIncentive,
                                    Colors.green,
                                    entry.totalIncentive > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildMiniStat(
                                    'Second',
                                    entry.secondPhoneIncentive,
                                    Colors.orange,
                                    entry.totalIncentive > 0,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildMiniStat(
                                    'Base',
                                    entry.baseModelIncentive,
                                    Colors.purple,
                                    entry.totalIncentive > 0,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to view detailed calculation',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    double value,
    Color color,
    bool hasIncentive,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: hasIncentive && value > 0
              ? color.withOpacity(0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value > 0 ? '₹${widget.formatNumber(value)}' : '₹0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: value > 0 ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: Color(0xFF0A4D2E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedTimePeriod,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom Range'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == 'custom') {
                      _showCustomDateRangePicker();
                    } else {
                      setState(() {
                        selectedTimePeriod = value!;
                        isCustomPeriod = false;
                        _calculateAllShopIncentives();
                      });
                    }
                  },
                ),
              ),
              if (isCustomPeriod && customStartDate != null)
                Text(
                  '${DateFormat('dd/MM').format(customStartDate!)} - ${DateFormat('dd/MM').format(customEndDate!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0A4D2E),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomDateRangePicker() async {
    DateTime? start = await showDatePicker(
      context: context,
      initialDate: customStartDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0A4D2E),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0A4D2E)),
          ),
          child: child!,
        );
      },
    );
    if (start == null) return;

    DateTime? end = await showDatePicker(
      context: context,
      initialDate: customEndDate ?? DateTime.now(),
      firstDate: start,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF0A4D2E),
            colorScheme: const ColorScheme.light(primary: Color(0xFF0A4D2E)),
          ),
          child: child!,
        );
      },
    );
    if (end == null) return;

    setState(() {
      customStartDate = start;
      customEndDate = end;
      isCustomPeriod = true;
      selectedTimePeriod = 'custom';
      _calculateAllShopIncentives();
    });
  }

  void _showTimePeriodDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Time Period',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Daily'),
                onTap: () {
                  setState(() {
                    selectedTimePeriod = 'daily';
                    isCustomPeriod = false;
                    _calculateAllShopIncentives();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Monthly'),
                onTap: () {
                  setState(() {
                    selectedTimePeriod = 'monthly';
                    isCustomPeriod = false;
                    _calculateAllShopIncentives();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Yearly'),
                onTap: () {
                  setState(() {
                    selectedTimePeriod = 'yearly';
                    isCustomPeriod = false;
                    _calculateAllShopIncentives();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Custom Range'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomDateRangePicker();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ShopIncentiveData {
  final String shopName;
  final double totalSales;
  final double accessoriesTotal;
  final double accessoriesIncentive;
  final double phoneTotalAmount;
  final int phoneCount;
  final double phoneIncentive;
  final List<Map<String, dynamic>> phonePriceDetails;
  final int secondPhoneCount;
  final double secondPhoneIncentive;
  final int baseModelCount;
  final double baseModelIncentive;
  final double totalIncentive;

  ShopIncentiveData({
    required this.shopName,
    required this.totalSales,
    required this.accessoriesTotal,
    required this.accessoriesIncentive,
    required this.phoneTotalAmount,
    required this.phoneCount,
    required this.phoneIncentive,
    required this.phonePriceDetails,
    required this.secondPhoneCount,
    required this.secondPhoneIncentive,
    required this.baseModelCount,
    required this.baseModelIncentive,
    required this.totalIncentive,
  });
}
