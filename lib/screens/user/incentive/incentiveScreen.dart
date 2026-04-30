// screens/user/incentive/incentive_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class IncentiveScreen extends StatefulWidget {
  const IncentiveScreen({super.key});

  @override
  State<IncentiveScreen> createState() => _IncentiveScreenState();
}

class _IncentiveScreenState extends State<IncentiveScreen> {
  bool isLoading = true;
  IncentiveData? incentiveData;
  String? errorMessage;

  // Current month info
  late DateTime currentMonthStart;
  late DateTime currentMonthEnd;
  String currentMonthName = '';
  int currentYear = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    currentMonthStart = DateTime(now.year, now.month, 1);
    currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    currentMonthName = _getMonthName(now.month);
    currentYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<AuthProvider>(context, listen: false).user;
      if (userData?.shopId != null && userData!.shopId!.isNotEmpty) {
        fetchIncentiveData(userData.shopId!);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Shop ID not found. Please contact administrator.';
        });
      }
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<void> fetchIncentiveData(String shopId) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final accessoriesData = await _fetchAccessoriesSalesWithDetails(shopId);
      final phoneData = await _fetchPhoneSalesWithDetails(shopId);
      final secondPhoneData = await _fetchSecondPhoneSalesWithDetails(shopId);
      final baseModelData = await _fetchBaseModelSalesWithDetails(shopId);

      final accessoriesIncentive = _calculateAccessoriesIncentive(
        accessoriesData,
      );
      final phoneIncentive = _calculatePhoneIncentive(phoneData);
      final secondPhoneIncentive = _calculateSecondPhoneIncentive(
        secondPhoneData,
      );
      final baseModelIncentive = _calculateBaseModelIncentive(baseModelData);

      incentiveData = IncentiveData(
        accessoriesTotalAmount: accessoriesData['totalAmount'] ?? 0,
        accessoriesSaleCount: accessoriesData['count'] ?? 0,
        accessoriesIncentive: accessoriesIncentive['amount'],
        accessoriesBreakdown: accessoriesIncentive['breakdown'] ?? [],
        phoneTotalAmount: phoneData['totalAmount'] ?? 0,
        phoneSaleCount: phoneData['count'] ?? 0,
        phoneIncentive: phoneIncentive['amount'],
        phoneBreakdown: phoneIncentive['breakdown'] ?? [],
        phonePriceDetails: phoneData['priceDetails'] ?? [],
        secondPhoneTotalAmount: secondPhoneData['totalAmount'] ?? 0,
        secondPhoneSaleCount: secondPhoneData['count'] ?? 0,
        secondPhoneIncentive: secondPhoneIncentive['amount'],
        secondPhoneBreakdown: secondPhoneIncentive['breakdown'] ?? [],
        baseModelTotalAmount: baseModelData['totalAmount'] ?? 0,
        baseModelSaleCount: baseModelData['count'] ?? 0,
        baseModelIncentive: baseModelIncentive['amount'],
        baseModelBreakdown: baseModelIncentive['breakdown'] ?? [],
        totalIncentive:
            (accessoriesIncentive['amount'] ?? 0) +
            (phoneIncentive['amount'] ?? 0) +
            (secondPhoneIncentive['amount'] ?? 0) +
            (baseModelIncentive['amount'] ?? 0),
      );

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<Map<String, dynamic>> _fetchAccessoriesSalesWithDetails(
    String shopId,
  ) async {
    double totalAmount = 0;
    int count = 0;
    List<Map<String, dynamic>> sales = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('accessories_service_sales')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final saleDate = _getSaleDate(data);

        if (_isDateInCurrentMonth(saleDate)) {
          final amount = (data['totalSaleAmount'] ?? 0).toDouble();
          totalAmount += amount;
          count++;
          sales.add({
            'amount': amount,
            'date': saleDate,
            'customerName': data['customerName'] ?? 'Walk-in Customer',
          });
        }
      }
    } catch (e) {
      print('Error fetching accessories sales: $e');
    }

    return {'totalAmount': totalAmount, 'count': count, 'sales': sales};
  }

  Future<Map<String, dynamic>> _fetchPhoneSalesWithDetails(
    String shopId,
  ) async {
    double totalAmount = 0;
    int count = 0;
    List<Map<String, dynamic>> priceDetails = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('phoneSales')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final saleDate = _getSaleDate(data);

        if (_isDateInCurrentMonth(saleDate)) {
          final amount = (data['effectivePrice'] ?? data['price'] ?? 0)
              .toDouble();
          totalAmount += amount;
          count++;

          String bracket;
          double incentiveAmount;
          if (amount < 15000) {
            bracket = 'Below ₹15,000';
            incentiveAmount = 30;
          } else if (amount < 25000) {
            bracket = '₹15,000 - ₹24,999';
            incentiveAmount = 40;
          } else if (amount < 35000) {
            bracket = '₹25,000 - ₹34,999';
            incentiveAmount = 50;
          } else if (amount < 45000) {
            bracket = '₹35,000 - ₹44,999';
            incentiveAmount = 70;
          } else if (amount < 60000) {
            bracket = '₹45,000 - ₹59,999';
            incentiveAmount = 90;
          } else if (amount < 80000) {
            bracket = '₹60,000 - ₹79,999';
            incentiveAmount = 130;
          } else if (amount < 100000) {
            bracket = '₹80,000 - ₹99,999';
            incentiveAmount = 150;
          } else {
            bracket = '₹1,00,000+';
            incentiveAmount = 200;
          }

          priceDetails.add({
            'amount': amount,
            'bracket': bracket,
            'incentive': incentiveAmount,
            'productName':
                data['productModel'] ?? data['productName'] ?? 'Phone',
            'date': saleDate,
          });
        }
      }
    } catch (e) {
      print('Error fetching phone sales: $e');
    }

    return {
      'totalAmount': totalAmount,
      'count': count,
      'priceDetails': priceDetails,
    };
  }

  Future<Map<String, dynamic>> _fetchSecondPhoneSalesWithDetails(
    String shopId,
  ) async {
    double totalAmount = 0;
    int count = 0;
    List<Map<String, dynamic>> sales = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('seconds_phone_sale')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final saleDate = _getSaleDate(data);

        if (_isDateInCurrentMonth(saleDate)) {
          final amount = (data['price'] ?? data['totalPayment'] ?? 0)
              .toDouble();
          totalAmount += amount;
          count++;
          sales.add({
            'amount': amount,
            'date': saleDate,
            'customerName': data['customerName'] ?? 'Walk-in Customer',
            'productName': data['productName'] ?? 'Second Phone',
          });
        }
      }
    } catch (e) {
      print('Error fetching second phone sales: $e');
    }

    return {'totalAmount': totalAmount, 'count': count, 'sales': sales};
  }

  Future<Map<String, dynamic>> _fetchBaseModelSalesWithDetails(
    String shopId,
  ) async {
    double totalAmount = 0;
    int count = 0;
    List<Map<String, dynamic>> sales = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('base_model_sale')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final saleDate = _getSaleDate(data);

        if (_isDateInCurrentMonth(saleDate)) {
          final amount = (data['price'] ?? data['totalPayment'] ?? 0)
              .toDouble();
          totalAmount += amount;
          count++;
          sales.add({
            'amount': amount,
            'date': saleDate,
            'customerName': data['customerName'] ?? 'Walk-in Customer',
            'productName':
                data['productModel'] ?? data['productName'] ?? 'Base Model',
          });
        }
      }
    } catch (e) {
      print('Error fetching base model sales: $e');
    }

    return {'totalAmount': totalAmount, 'count': count, 'sales': sales};
  }

  DateTime _getSaleDate(Map<String, dynamic> data) {
    try {
      List<String> dateFields = [
        'date',
        'uploadedAt',
        'timestamp',
        'saleDate',
        'addedAt',
        'createdAt',
      ];

      for (var field in dateFields) {
        if (data[field] != null) {
          if (data[field] is Timestamp) {
            return (data[field] as Timestamp).toDate();
          } else if (data[field] is int) {
            return DateTime.fromMillisecondsSinceEpoch(data[field]);
          } else if (data[field] is String) {
            try {
              return DateTime.parse(data[field]);
            } catch (_) {
              return _parseDateString(data[field].toString());
            }
          }
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseDateString(String dateString) {
    try {
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length >= 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      }
      return DateTime.parse(dateString);
    } catch (_) {
      return DateTime.now();
    }
  }

  bool _isDateInCurrentMonth(DateTime date) {
    return date.isAfter(
          currentMonthStart.subtract(const Duration(seconds: 1)),
        ) &&
        date.isBefore(currentMonthEnd.add(const Duration(seconds: 1)));
  }

  // Updated: Accessories Incentive - ₹1000 base + ₹200 per ₹10,000 above ₹1L
  Map<String, dynamic> _calculateAccessoriesIncentive(
    Map<String, dynamic> salesData,
  ) {
    final totalAmount = salesData['totalAmount'] as double;

    if (totalAmount <= 100000) {
      return {
        'amount': 0.0,
        'breakdown': [
          {
            'message': 'Total sales below ₹1,00,000 - No incentive',
            'amount': 0,
          },
        ],
      };
    }

    double incentive = 1000;
    List<Map<String, dynamic>> breakdown = [
      {
        'title': 'Base Incentive',
        'calculation': 'Sales > ₹1,00,000',
        'amount': 1000,
      },
    ];

    final amountAboveLakh = totalAmount - 100000;
    final additionalThousands = (amountAboveLakh / 10000).floor();
    final additionalIncentive = additionalThousands * 200;

    if (additionalThousands > 0) {
      incentive += additionalIncentive;
      breakdown.add({
        'title': 'Additional Incentive',
        'calculation':
            '₹${amountAboveLakh.toStringAsFixed(0)} above → ${additionalThousands} × ₹200',
        'amount': additionalIncentive,
      });
    }

    return {'amount': incentive, 'breakdown': breakdown};
  }

  Map<String, dynamic> _calculatePhoneIncentive(
    Map<String, dynamic> salesData,
  ) {
    final totalAmount = salesData['totalAmount'] as double;
    final saleCount = salesData['count'] as int;
    final priceDetails =
        salesData['priceDetails'] as List<Map<String, dynamic>>;

    if (saleCount >= 20 && totalAmount >= 300000) {
      double totalIncentive = 0;
      List<Map<String, dynamic>> breakdown = [
        {
          'title': 'Qualification Met',
          'calculation':
              '$saleCount phones | ₹${(totalAmount / 1000).toStringAsFixed(0)}k',
          'amount': 0,
          'note': 'No base incentive, only per-phone incentives apply',
        },
      ];

      Map<String, Map<String, dynamic>> bracketGroups = {};

      for (var phone in priceDetails) {
        final bracket = phone['bracket'];
        final incentiveAmount = phone['incentive'];

        if (!bracketGroups.containsKey(bracket)) {
          bracketGroups[bracket] = {
            'count': 0,
            'totalIncentive': 0,
            'incentivePerPhone': incentiveAmount,
          };
        }
        bracketGroups[bracket]!['count']++;
        bracketGroups[bracket]!['totalIncentive'] += incentiveAmount;
        totalIncentive += incentiveAmount;
      }

      for (var entry in bracketGroups.entries) {
        breakdown.add({
          'title': entry.key,
          'calculation':
              '${entry.value['count']} phones × ₹${entry.value['incentivePerPhone']}',
          'amount': entry.value['totalIncentive'],
        });
      }

      if (totalIncentive == 0) {
        breakdown.add({
          'title': 'Note',
          'calculation': 'No per-phone incentives earned',
          'amount': 0,
          'note': 'Phone prices below incentive brackets',
        });
      }

      return {'amount': totalIncentive, 'breakdown': breakdown};
    } else {
      String reason = saleCount < 20 && totalAmount < 300000
          ? 'Need 20+ phones ($saleCount) AND ₹3L+ value (₹${(totalAmount / 1000).toStringAsFixed(0)}k)'
          : saleCount < 20
          ? 'Need 20+ phones (currently $saleCount)'
          : 'Need ₹3,00,000+ value (currently ₹${(totalAmount / 1000).toStringAsFixed(0)}k)';

      return {
        'amount': 0.0,
        'breakdown': [
          {'message': reason, 'amount': 0},
        ],
      };
    }
  }

  // Second Phone Incentive - 1-10 pieces: ₹30, Above 10 pieces: ₹40
  Map<String, dynamic> _calculateSecondPhoneIncentive(
    Map<String, dynamic> salesData,
  ) {
    final saleCount = salesData['count'] as int;

    if (saleCount < 1) {
      return {
        'amount': 0.0,
        'breakdown': [
          {'message': 'No sales recorded', 'amount': 0},
        ],
      };
    }

    // 1-10 pieces: ₹30 per piece, Above 10 pieces: ₹40 per piece
    double perPieceIncentive = saleCount <= 10 ? 30 : 40;
    String rateText = saleCount <= 10 ? '₹30 per piece' : '₹40 per piece';
    final totalIncentive = saleCount * perPieceIncentive;

    return {
      'amount': totalIncentive,
      'breakdown': [
        {
          'title': 'Quantity Bonus',
          'calculation': '$saleCount × $rateText',
          'amount': totalIncentive,
        },
      ],
    };
  }

  // Base Model Incentive - 1-10 pieces: ₹15, Above 10 pieces: ₹25
  Map<String, dynamic> _calculateBaseModelIncentive(
    Map<String, dynamic> salesData,
  ) {
    final saleCount = salesData['count'] as int;

    if (saleCount < 1) {
      return {
        'amount': 0.0,
        'breakdown': [
          {'message': 'No sales recorded', 'amount': 0},
        ],
      };
    }

    // 1-10 pieces: ₹15 per piece, Above 10 pieces: ₹25 per piece
    double perPieceIncentive = saleCount <= 10 ? 15 : 25;
    String rateText = saleCount <= 10 ? '₹15 per piece' : '₹25 per piece';
    final totalIncentive = saleCount * perPieceIncentive;

    return {
      'amount': totalIncentive,
      'breakdown': [
        {
          'title': 'Quantity Bonus',
          'calculation': '$saleCount × $rateText',
          'amount': totalIncentive,
        },
      ],
    };
  }

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
                    'Current Month Performance',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          _buildDetailedConditionCard(
                            title: 'Accessories & Service',
                            icon: Icons.shopping_bag,
                            color: Colors.blue,
                            rules: [
                              '🎯 Base Incentive: ₹1,000 when sales exceed ₹1,00,000',
                              '📈 Additional: ₹200 for every ₹10,000 above ₹1,00,000',
                            ],
                            currentAmount:
                                incentiveData?.accessoriesTotalAmount ?? 0,
                            currentCount:
                                incentiveData?.accessoriesSaleCount ?? 0,
                            currentIncentive:
                                incentiveData?.accessoriesIncentive ?? 0,
                            unit: '₹',
                          ),
                          const SizedBox(height: 12),

                          _buildDetailedConditionCard(
                            title: 'Phone Sales',
                            icon: Icons.phone_iphone,
                            color: Colors.green,
                            rules: [
                              '🎯 Qualification: 20+ phones AND ₹3,00,000+ total value',
                              '📱 Per Phone Incentive (based on price) after qualification:',
                              '   • Below ₹15,000 → ₹30',
                              '   • ₹15,000 - ₹24,999 → ₹40',
                              '   • ₹25,000 - ₹34,999 → ₹50',
                              '   • ₹35,000 - ₹44,999 → ₹70',
                              '   • ₹45,000 - ₹59,999 → ₹90',
                              '   • ₹60,000 - ₹79,999 → ₹130',
                              '   • ₹80,000 - ₹99,999 → ₹150',
                              '   • ₹1,00,000+ → ₹200',
                              '⚠️ Note: No base incentive, only per-phone incentives',
                            ],
                            currentAmount: incentiveData?.phoneTotalAmount ?? 0,
                            currentCount: incentiveData?.phoneSaleCount ?? 0,
                            currentIncentive:
                                incentiveData?.phoneIncentive ?? 0,
                            unit: '₹',
                            showQualification: true,
                            requiredCount: 20,
                            requiredAmount: 300000,
                          ),
                          const SizedBox(height: 12),

                          _buildDetailedConditionCard(
                            title: 'Second Phones',
                            icon: Icons.phone_android,
                            color: Colors.orange,
                            rules: [
                              '💰 Incentive Structure (per piece):',
                              '   • 1-10 pieces → ₹30 per piece',
                              '   • Above 10 pieces → ₹40 per piece',
                              '✨ No minimum quantity required',
                            ],
                            currentAmount:
                                incentiveData?.secondPhoneTotalAmount ?? 0,
                            currentCount:
                                incentiveData?.secondPhoneSaleCount ?? 0,
                            currentIncentive:
                                incentiveData?.secondPhoneIncentive ?? 0,
                            unit: '₹',
                            showQualification: false,
                          ),
                          const SizedBox(height: 12),

                          _buildDetailedConditionCard(
                            title: 'Base Models',
                            icon: Icons.devices,
                            color: Colors.purple,
                            rules: [
                              '💰 Incentive Structure (per piece):',
                              '   • 1-10 pieces → ₹15 per piece',
                              '   • Above 10 pieces → ₹25 per piece',
                              '✨ No minimum quantity required',
                            ],
                            currentAmount:
                                incentiveData?.baseModelTotalAmount ?? 0,
                            currentCount:
                                incentiveData?.baseModelSaleCount ?? 0,
                            currentIncentive:
                                incentiveData?.baseModelIncentive ?? 0,
                            unit: '₹',
                            showQualification: false,
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
                      backgroundColor: Colors.green,
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

  Widget _buildDetailedConditionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> rules,
    required double currentAmount,
    required int currentCount,
    required double currentIncentive,
    required String unit,
    bool showQualification = false,
    int? requiredCount,
    double? requiredAmount,
  }) {
    bool isQualified = true;
    if (showQualification) {
      if (requiredAmount != null) {
        isQualified =
            currentCount >= (requiredCount ?? 0) &&
            currentAmount >= requiredAmount;
      } else if (requiredCount != null) {
        isQualified = currentCount >= requiredCount;
      }
    }

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
                if (showQualification)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isQualified
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isQualified ? '✓ Qualified' : '✗ Not Qualified',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isQualified
                            ? Colors.green.shade700
                            : Colors.red.shade700,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Total ${unit == '₹' ? 'Sales' : 'Units'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              unit == '₹'
                                  ? '₹${(currentAmount / 1000).toStringAsFixed(0)}k'
                                  : '$currentCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Units Sold',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$currentCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Incentive',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${currentIncentive.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                ...rules.map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      rule,
                      style: const TextStyle(fontSize: 10, height: 1.4),
                    ),
                  ),
                ),

                if (showQualification && !isQualified) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        if (requiredCount != null)
                          LinearProgressIndicator(
                            value: (currentCount / requiredCount).clamp(
                              0.0,
                              1.0,
                            ),
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.amber,
                            minHeight: 4,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          requiredAmount != null
                              ? 'Progress: $currentCount/$requiredCount phones | ${(currentAmount / 1000).toStringAsFixed(0)}k/${(requiredAmount / 1000).toStringAsFixed(0)}k value'
                              : 'Progress: $currentCount/$requiredCount units',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCalculationDetails(
    String title,
    List<Map<String, dynamic>> breakdown,
    Color color,
  ) {
    // Check if breakdown is empty or null
    if (breakdown.isEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: color, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calculate,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No calculation details available',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Incentive not earned for this category',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
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
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.7,
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
                      Icon(Icons.calculate, color: color, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: breakdown.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = breakdown[index];

                        if (item.containsKey('message')) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['message'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final isTotal = item['isTotal'] == true;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: TextStyle(
                                        fontWeight: isTotal
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: isTotal ? 13 : 12,
                                      ),
                                    ),
                                    if (item['calculation'] != null &&
                                        item['calculation']
                                            .toString()
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          item['calculation'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    if (item['note'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          item['note'],
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (item['amount'] != null)
                                Text(
                                  '₹${(item['amount'] as double).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: isTotal
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: isTotal ? 14 : 12,
                                    color: isTotal
                                        ? Colors.green.shade700
                                        : color,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentive', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, size: 22),
            onPressed: _showConditions,
            tooltip: 'View Conditions',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              final userData = Provider.of<AuthProvider>(
                context,
                listen: false,
              ).user;
              if (userData?.shopId != null && userData!.shopId!.isNotEmpty) {
                fetchIncentiveData(userData.shopId!);
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
            SizedBox(height: 12),
            Text('Calculating incentives...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final userData = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).user;
                if (userData?.shopId != null && userData!.shopId!.isNotEmpty) {
                  fetchIncentiveData(userData.shopId!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(100, 36),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    if (incentiveData == null) {
      return const Center(
        child: Text('No data available', style: TextStyle(fontSize: 13)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade600, Colors.green.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Current Month',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currentMonthName $currentYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade600, Colors.deepOrange.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Incentive Earned',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${incentiveData!.totalIncentive.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildIncentiveCard(
            title: 'Accessories & Service',
            icon: Icons.shopping_bag,
            color: Colors.blue,
            totalAmount: incentiveData!.accessoriesTotalAmount,
            saleCount: incentiveData!.accessoriesSaleCount,
            incentive: incentiveData!.accessoriesIncentive,
            ruleText: 'Above ₹1L: ₹1000 + ₹200/₹10k',
            breakdown: incentiveData!.accessoriesBreakdown,
            onInfoTap: () => _showCalculationDetails(
              'Accessories Calculation',
              incentiveData!.accessoriesBreakdown,
              Colors.blue,
            ),
          ),
          const SizedBox(height: 10),

          _buildIncentiveCard(
            title: 'Phone Sales',
            icon: Icons.phone_iphone,
            color: Colors.green,
            totalAmount: incentiveData!.phoneTotalAmount,
            saleCount: incentiveData!.phoneSaleCount,
            incentive: incentiveData!.phoneIncentive,
            ruleText: '20+ phones & ₹3L+: Only per-phone incentive',
            breakdown: incentiveData!.phoneBreakdown,
            onInfoTap: () => _showCalculationDetails(
              'Phone Calculation',
              incentiveData!.phoneBreakdown,
              Colors.green,
            ),
          ),
          const SizedBox(height: 10),

          _buildIncentiveCard(
            title: 'Second Phones',
            icon: Icons.phone_android,
            color: Colors.orange,
            totalAmount: incentiveData!.secondPhoneTotalAmount,
            saleCount: incentiveData!.secondPhoneSaleCount,
            incentive: incentiveData!.secondPhoneIncentive,
            ruleText: incentiveData!.secondPhoneSaleCount <= 10
                ? '₹30/piece (1-10 pieces)'
                : '₹40/piece (10+ pieces)',
            breakdown: incentiveData!.secondPhoneBreakdown,
            onInfoTap: () => _showCalculationDetails(
              'Second Phones Calculation',
              incentiveData!.secondPhoneBreakdown,
              Colors.orange,
            ),
          ),
          const SizedBox(height: 10),

          _buildIncentiveCard(
            title: 'Base Models',
            icon: Icons.devices,
            color: Colors.purple,
            totalAmount: incentiveData!.baseModelTotalAmount,
            saleCount: incentiveData!.baseModelSaleCount,
            incentive: incentiveData!.baseModelIncentive,
            ruleText: incentiveData!.baseModelSaleCount <= 10
                ? '₹15/piece (1-10 pieces)'
                : '₹25/piece (10+ pieces)',
            breakdown: incentiveData!.baseModelBreakdown,
            onInfoTap: () => _showCalculationDetails(
              'Base Models Calculation',
              incentiveData!.baseModelBreakdown,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncentiveCard({
    required String title,
    required IconData icon,
    required Color color,
    required double totalAmount,
    required int saleCount,
    required double incentive,
    required String ruleText,
    required List<Map<String, dynamic>> breakdown,
    required VoidCallback onInfoTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹${incentive.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onInfoTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.info_outline, color: color, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Sales',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '₹${(totalAmount / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Units Sold',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '$saleCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    ruleText,
                    style: TextStyle(fontSize: 9, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class IncentiveData {
  final double accessoriesTotalAmount;
  final int accessoriesSaleCount;
  final double accessoriesIncentive;
  final List<Map<String, dynamic>> accessoriesBreakdown;

  final double phoneTotalAmount;
  final int phoneSaleCount;
  final double phoneIncentive;
  final List<Map<String, dynamic>> phoneBreakdown;
  final List<Map<String, dynamic>> phonePriceDetails;

  final double secondPhoneTotalAmount;
  final int secondPhoneSaleCount;
  final double secondPhoneIncentive;
  final List<Map<String, dynamic>> secondPhoneBreakdown;

  final double baseModelTotalAmount;
  final int baseModelSaleCount;
  final double baseModelIncentive;
  final List<Map<String, dynamic>> baseModelBreakdown;

  final double totalIncentive;

  IncentiveData({
    required this.accessoriesTotalAmount,
    required this.accessoriesSaleCount,
    required this.accessoriesIncentive,
    required this.accessoriesBreakdown,
    required this.phoneTotalAmount,
    required this.phoneSaleCount,
    required this.phoneIncentive,
    required this.phoneBreakdown,
    required this.phonePriceDetails,
    required this.secondPhoneTotalAmount,
    required this.secondPhoneSaleCount,
    required this.secondPhoneIncentive,
    required this.secondPhoneBreakdown,
    required this.baseModelTotalAmount,
    required this.baseModelSaleCount,
    required this.baseModelIncentive,
    required this.baseModelBreakdown,
    required this.totalIncentive,
  });
}
