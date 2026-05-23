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
  IncentiveData? currentIncentiveData;
  String? errorMessage;

  // Time period selection
  String selectedTimePeriod = 'current_month';
  DateTime? customStartDate;
  DateTime? customEndDate;
  bool isCustomPeriod = false;

  // Date ranges
  DateTime currentStartDate = DateTime.now();
  DateTime currentEndDate = DateTime.now();
  String currentPeriodName = '';

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<AuthProvider>(context, listen: false).user;
      if (userData?.shopId != null && userData!.shopId!.isNotEmpty) {
        _fetchData(userData.shopId!);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Shop ID not found. Please contact administrator.';
        });
      }
    });
  }

  void _updateDateRange() {
    final now = DateTime.now();

    if (selectedTimePeriod == 'last_month') {
      currentStartDate = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
      currentEndDate = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
      currentPeriodName = DateFormat('MMMM yyyy').format(currentStartDate);
    } else if (selectedTimePeriod == 'last_year') {
      currentStartDate = DateTime(now.year - 1, 1, 1, 0, 0, 0);
      currentEndDate = DateTime(now.year - 1, 12, 31, 23, 59, 59, 999);
      currentPeriodName = '${now.year - 1}';
    } else if (selectedTimePeriod == 'current_month') {
      currentStartDate = DateTime(now.year, now.month, 1, 0, 0, 0);
      currentEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      currentPeriodName = DateFormat('MMMM yyyy').format(now);
    } else if (selectedTimePeriod == 'current_year') {
      currentStartDate = DateTime(now.year, 1, 1, 0, 0, 0);
      currentEndDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      currentPeriodName = '${now.year}';
    } else if (selectedTimePeriod == 'daily') {
      currentStartDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
      currentEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      currentPeriodName = DateFormat('dd MMM yyyy').format(now);
    } else if (selectedTimePeriod == 'custom' && isCustomPeriod) {
      currentStartDate = DateTime(
        customStartDate!.year,
        customStartDate!.month,
        customStartDate!.day,
        0,
        0,
        0,
      );
      currentEndDate = DateTime(
        customEndDate!.year,
        customEndDate!.month,
        customEndDate!.day,
        23,
        59,
        59,
        999,
      );
      currentPeriodName =
          '${DateFormat('dd MMM').format(currentStartDate)} - ${DateFormat('dd MMM yyyy').format(currentEndDate)}';
    }
  }

  Future<void> _fetchData(String shopId) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _fetchIncentiveDataForPeriod(
        shopId,
        currentStartDate,
        currentEndDate,
      );
      setState(() {
        currentIncentiveData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<IncentiveData> _fetchIncentiveDataForPeriod(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final accessoriesData = await _fetchAccessoriesSales(
      shopId,
      startDate,
      endDate,
    );
    final phoneData = await _fetchPhoneSales(shopId, startDate, endDate);
    final tvData = await _fetchTvSales(shopId, startDate, endDate);
    final secondPhoneData = await _fetchSecondPhoneSales(
      shopId,
      startDate,
      endDate,
    );
    final baseModelData = await _fetchBaseModelSales(
      shopId,
      startDate,
      endDate,
    );

    final accessoriesIncentive = _calculateAccessoriesIncentive(
      accessoriesData,
    );
    final phoneIncentive = _calculatePhoneIncentive(phoneData);
    final tvIncentive = _calculateTvIncentive(tvData);
    final secondPhoneIncentive = _calculateSecondPhoneIncentive(
      secondPhoneData,
    );
    final baseModelIncentive = _calculateBaseModelIncentive(baseModelData);

    return IncentiveData(
      accessoriesTotalAmount: accessoriesData['totalAmount'] as double? ?? 0,
      accessoriesSaleCount: accessoriesData['count'] as int? ?? 0,
      accessoriesIncentive: accessoriesIncentive['amount'] as double? ?? 0,
      accessoriesBreakdown: List<Map<String, dynamic>>.from(
        accessoriesIncentive['breakdown'] as List? ?? [],
      ),
      accessoriesSalesList: List<Map<String, dynamic>>.from(
        accessoriesData['sales'] as List? ?? [],
      ),
      phoneTotalAmount: phoneData['totalAmount'] as double? ?? 0,
      phoneSaleCount: phoneData['count'] as int? ?? 0,
      phoneIncentive: phoneIncentive['amount'] as double? ?? 0,
      phoneBreakdown: List<Map<String, dynamic>>.from(
        phoneIncentive['breakdown'] as List? ?? [],
      ),
      phonePriceDetails: List<Map<String, dynamic>>.from(
        phoneData['priceDetails'] as List? ?? [],
      ),
      phoneSalesList: List<Map<String, dynamic>>.from(
        phoneData['sales'] as List? ?? [],
      ),
      tvTotalAmount: tvData['totalAmount'] as double? ?? 0,
      tvSaleCount: tvData['count'] as int? ?? 0,
      tvIncentive: tvIncentive['amount'] as double? ?? 0,
      tvBreakdown: List<Map<String, dynamic>>.from(
        tvIncentive['breakdown'] as List? ?? [],
      ),
      tvSalesList: List<Map<String, dynamic>>.from(
        tvData['sales'] as List? ?? [],
      ),
      secondPhoneTotalAmount: secondPhoneData['totalAmount'] as double? ?? 0,
      secondPhoneSaleCount: secondPhoneData['count'] as int? ?? 0,
      secondPhoneIncentive: secondPhoneIncentive['amount'] as double? ?? 0,
      secondPhoneBreakdown: List<Map<String, dynamic>>.from(
        secondPhoneIncentive['breakdown'] as List? ?? [],
      ),
      secondPhoneSalesList: List<Map<String, dynamic>>.from(
        secondPhoneData['sales'] as List? ?? [],
      ),
      baseModelTotalAmount: baseModelData['totalAmount'] as double? ?? 0,
      baseModelSaleCount: baseModelData['count'] as int? ?? 0,
      baseModelIncentive: baseModelIncentive['amount'] as double? ?? 0,
      baseModelBreakdown: List<Map<String, dynamic>>.from(
        baseModelIncentive['breakdown'] as List? ?? [],
      ),
      baseModelSalesList: List<Map<String, dynamic>>.from(
        baseModelData['sales'] as List? ?? [],
      ),
      totalIncentive:
          (accessoriesIncentive['amount'] as double? ?? 0) +
          (phoneIncentive['amount'] as double? ?? 0) +
          (tvIncentive['amount'] as double? ?? 0) +
          (secondPhoneIncentive['amount'] as double? ?? 0) +
          (baseModelIncentive['amount'] as double? ?? 0),
    );
  }

  Future<Map<String, dynamic>> _fetchAccessoriesSales(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> data = {
      'totalAmount': 0.0,
      'count': 0,
      'sales': <Map<String, dynamic>>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('accessories_service_sales')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final saleData = doc.data();
        final saleDate = _getSaleDate(saleData);
        final dateStr = _formatDate(saleDate);

        final isInRange = _isDateInRange(saleDate, startDate, endDate);

        if (isInRange) {
          // Calculate amount - prioritize totalSaleAmount
          final totalSaleAmount =
              (saleData['totalSaleAmount'] as num?)?.toDouble() ?? 0;
          final accessoriesAmount =
              (saleData['accessoriesAmount'] as num?)?.toDouble() ?? 0;
          final serviceAmount =
              (saleData['serviceAmount'] as num?)?.toDouble() ?? 0;

          double amount;
          if (totalSaleAmount > 0) {
            amount = totalSaleAmount;
            print('Using totalSaleAmount: $amount');
          } else {
            amount = accessoriesAmount + serviceAmount;
            print('Using sum (accessories + service): $amount');
          }

          data['totalAmount'] = (data['totalAmount'] as double) + amount;
          data['count'] = (data['count'] as int) + 1;

          (data['sales'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'date': saleDate,
            'customerName': saleData['customerName'] ?? 'Walk-in Customer',
            'productName': 'Accessories & Service',
            'accessoriesAmount': accessoriesAmount,
            'serviceAmount': serviceAmount,
            'totalSaleAmount': totalSaleAmount,
            'items': saleData['items'] ?? [],
            'paymentBreakdown': {
              'cash': saleData['cashAmount'] ?? 0,
              'gpay': saleData['gpayAmount'] ?? 0,
              'card': saleData['cardAmount'] ?? 0,
            },
          });

          print('✓ INCLUDED - Amount: $amount');
          print('  Running total: ${data['totalAmount']}');
          print('  Running count: ${data['count']}');
        } else {
          print('✗ EXCLUDED - Date out of range');
          print(
            '  Required between: ${_formatDate(startDate)} and ${_formatDate(endDate)}',
          );
        }
      }

      print('\n========== ACCESSORIES SUMMARY ==========');
      print('Total Amount: ${data['totalAmount']}');
      print('Total Count: ${data['count']}');
      print('========================================\n');
    } catch (e) {
      print('Error fetching accessories sales: $e');
    }

    return data;
  }

  Future<Map<String, dynamic>> _fetchPhoneSales(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> data = {
      'totalAmount': 0.0,
      'count': 0,
      'priceDetails': <Map<String, dynamic>>[],
      'sales': <Map<String, dynamic>>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('phoneSales')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final saleData = doc.data();
        final saleDate = _getSaleDate(saleData);

        if (_isDateInRange(saleDate, startDate, endDate)) {
          final amount =
              (saleData['effectivePrice'] as num?)?.toDouble() ??
              (saleData['price'] as num?)?.toDouble() ??
              0;

          data['totalAmount'] = (data['totalAmount'] as double) + amount;
          data['count'] = (data['count'] as int) + 1;

          final incentiveInfo = _getPhoneIncentiveInfo(amount);

          (data['priceDetails'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'bracket': incentiveInfo['bracket'] as String,
            'incentive': incentiveInfo['incentive'] as double,
            'productName':
                saleData['productModel'] ?? saleData['productName'] ?? 'Phone',
            'date': saleDate,
          });

          (data['sales'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'productName':
                saleData['productModel'] ?? saleData['productName'] ?? 'Phone',
            'customerName': saleData['customerName'] ?? 'Walk-in Customer',
            'date': saleDate,
            'bracket': incentiveInfo['bracket'] as String,
            'incentive': incentiveInfo['incentive'] as double,
          });
        }
      }
    } catch (e) {
      print('Error fetching phone sales: $e');
    }

    return data;
  }

  Future<Map<String, dynamic>> _fetchTvSales(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> data = {
      'totalAmount': 0.0,
      'count': 0,
      'sales': <Map<String, dynamic>>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .where('shopId', isEqualTo: shopId)
          .where('type', isEqualTo: 'tv')
          .get();

      for (var doc in snapshot.docs) {
        final saleData = doc.data();
        final saleDate = _getSaleDate(saleData);

        if (_isDateInRange(saleDate, startDate, endDate)) {
          final amount = (saleData['totalAmount'] as num?)?.toDouble() ?? 0;

          data['totalAmount'] = (data['totalAmount'] as double) + amount;
          data['count'] = (data['count'] as int) + 1;

          (data['sales'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'productName':
                saleData['modelName'] ?? saleData['productName'] ?? 'TV',
            'customerName': saleData['customerName'] ?? 'Walk-in Customer',
            'date': saleDate,
            'modelBrand':
                saleData['originalTvData']?['modelBrand'] ?? 'Unknown',
            'serialNumber': saleData['serialNumber'] ?? '',
          });
        }
      }
    } catch (e) {
      print('Error fetching TV sales: $e');
    }

    return data;
  }

  Future<Map<String, dynamic>> _fetchSecondPhoneSales(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> data = {
      'totalAmount': 0.0,
      'count': 0,
      'sales': <Map<String, dynamic>>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('seconds_phone_sale')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final saleData = doc.data();
        final saleDate = _getSaleDate(saleData);

        if (_isDateInRange(saleDate, startDate, endDate)) {
          final amount =
              (saleData['price'] as num?)?.toDouble() ??
              (saleData['totalPayment'] as num?)?.toDouble() ??
              0;

          data['totalAmount'] = (data['totalAmount'] as double) + amount;
          data['count'] = (data['count'] as int) + 1;

          (data['sales'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'productName': saleData['productName'] ?? 'Second Phone',
            'customerName': saleData['customerName'] ?? 'Walk-in Customer',
            'date': saleDate,
            'imei': saleData['imei'] ?? '',
            'brand': saleData['brand'] ?? '',
          });
        }
      }
    } catch (e) {
      print('Error fetching second phone sales: $e');
    }

    return data;
  }

  Future<Map<String, dynamic>> _fetchBaseModelSales(
    String shopId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> data = {
      'totalAmount': 0.0,
      'count': 0,
      'sales': <Map<String, dynamic>>[],
    };

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('base_model_sale')
          .where('shopId', isEqualTo: shopId)
          .get();

      for (var doc in snapshot.docs) {
        final saleData = doc.data();
        final saleDate = _getSaleDate(saleData);

        if (_isDateInRange(saleDate, startDate, endDate)) {
          final amount =
              (saleData['price'] as num?)?.toDouble() ??
              (saleData['totalPayment'] as num?)?.toDouble() ??
              0;

          data['totalAmount'] = (data['totalAmount'] as double) + amount;
          data['count'] = (data['count'] as int) + 1;

          (data['sales'] as List<Map<String, dynamic>>).add({
            'amount': amount,
            'productName':
                saleData['modelName'] ??
                saleData['productName'] ??
                'Base Model',
            'customerName': saleData['customerName'] ?? 'Walk-in Customer',
            'date': saleDate,
            'brand': saleData['brand'] ?? '',
          });
        }
      }
    } catch (e) {
      print('Error fetching base model sales: $e');
    }

    return data;
  }

  Map<String, dynamic> _getPhoneIncentiveInfo(double amount) {
    String bracket;
    double incentive;
    if (amount < 15000) {
      bracket = 'Below ₹15,000';
      incentive = 30;
    } else if (amount < 25000) {
      bracket = '₹15,000 - ₹24,999';
      incentive = 40;
    } else if (amount < 35000) {
      bracket = '₹25,000 - ₹34,999';
      incentive = 50;
    } else if (amount < 45000) {
      bracket = '₹35,000 - ₹44,999';
      incentive = 70;
    } else if (amount < 60000) {
      bracket = '₹45,000 - ₹59,999';
      incentive = 90;
    } else if (amount < 80000) {
      bracket = '₹60,000 - ₹79,999';
      incentive = 130;
    } else if (amount < 100000) {
      bracket = '₹80,000 - ₹99,999';
      incentive = 150;
    } else {
      bracket = '₹1,00,000+';
      incentive = 200;
    }
    return {'bracket': bracket, 'incentive': incentive};
  }

  DateTime _getSaleDate(Map<String, dynamic> data) {
    // Try to get date from Timestamp fields
    if (data['date'] is Timestamp) {
      return (data['date'] as Timestamp).toDate();
    }
    if (data['uploadedAt'] is Timestamp) {
      return (data['uploadedAt'] as Timestamp).toDate();
    }
    if (data['billDate'] is Timestamp) {
      return (data['billDate'] as Timestamp).toDate();
    }
    if (data['timestamp'] is Timestamp) {
      return (data['timestamp'] as Timestamp).toDate();
    }
    if (data['saleDate'] is Timestamp) {
      return (data['saleDate'] as Timestamp).toDate();
    }

    // Try dateString field
    if (data['dateString'] != null && data['dateString'] is String) {
      try {
        return DateTime.parse(data['dateString']);
      } catch (e) {
        print('Error parsing dateString: $e');
      }
    }

    // Try individual date components
    if (data['year'] != null && data['month'] != null && data['day'] != null) {
      try {
        return DateTime(
          (data['year'] as num).toInt(),
          (data['month'] as num).toInt(),
          (data['day'] as num).toInt(),
        );
      } catch (e) {
        print('Error parsing date components: $e');
      }
    }

    // Fallback to current date
    print('Could not parse date from data: $data');
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _isDateInRange(DateTime date, DateTime startDate, DateTime endDate) {
    // Create date-only versions (without time)
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);

    // Check if date is between start and end (inclusive)
    return dateOnly.isAfter(startOnly.subtract(const Duration(days: 1))) &&
        dateOnly.isBefore(endOnly.add(const Duration(days: 1)));
  }

  Map<String, dynamic> _calculateAccessoriesIncentive(
    Map<String, dynamic> salesData,
  ) {
    final totalAmount = salesData['totalAmount'] as double? ?? 0;

    print('Accessories Incentive Calculation - Total Amount: $totalAmount');

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

    print('Accessories Incentive Calculated: $incentive');
    return {'amount': incentive, 'breakdown': breakdown};
  }

  Map<String, dynamic> _calculatePhoneIncentive(
    Map<String, dynamic> salesData,
  ) {
    final totalAmount = salesData['totalAmount'] as double? ?? 0;
    final saleCount = salesData['count'] as int? ?? 0;
    final priceDetails = List<Map<String, dynamic>>.from(
      salesData['priceDetails'] as List? ?? [],
    );

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
        final bracket = phone['bracket'] as String;
        final incentiveAmount = phone['incentive'] as double;

        if (!bracketGroups.containsKey(bracket)) {
          bracketGroups[bracket] = {
            'count': 0,
            'totalIncentive': 0,
            'incentivePerPhone': incentiveAmount,
          };
        }
        bracketGroups[bracket]!['count'] =
            (bracketGroups[bracket]!['count'] as int) + 1;
        bracketGroups[bracket]!['totalIncentive'] =
            (bracketGroups[bracket]!['totalIncentive'] as double) +
            incentiveAmount;
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

  Map<String, dynamic> _calculateTvIncentive(Map<String, dynamic> salesData) {
    final saleCount = salesData['count'] as int? ?? 0;

    if (saleCount < 1) {
      return {
        'amount': 0.0,
        'breakdown': [
          {'message': 'No TV sales recorded', 'amount': 0},
        ],
      };
    }

    double perPieceIncentive = saleCount <= 10 ? 30 : 50;
    String rateText = saleCount <= 10 ? '₹30 per piece' : '₹50 per piece';
    final totalIncentive = saleCount * perPieceIncentive;

    return {
      'amount': totalIncentive,
      'breakdown': [
        {
          'title': 'TV Sales Incentive',
          'calculation': '$saleCount × $rateText',
          'amount': totalIncentive,
        },
      ],
    };
  }

  Map<String, dynamic> _calculateSecondPhoneIncentive(
    Map<String, dynamic> salesData,
  ) {
    final saleCount = salesData['count'] as int? ?? 0;

    if (saleCount < 1) {
      return {
        'amount': 0.0,
        'breakdown': [
          {'message': 'No second phone sales recorded', 'amount': 0},
        ],
      };
    }

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

  Map<String, dynamic> _calculateBaseModelIncentive(
    Map<String, dynamic> salesData,
  ) {
    final saleCount = salesData['count'] as int? ?? 0;

    if (saleCount < 1) {
      return {
        'amount': 0.0,
        'breakdown': [
          {'message': 'No base model sales recorded', 'amount': 0},
        ],
      };
    }

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

  String _formatNumber(double number) {
    return NumberFormat('#,###').format(number);
  }

  void _showDetailedCalculation(
    String title,
    IncentiveData data,
    Color color,
    String type,
  ) {
    List<Map<String, dynamic>> breakdown = [];
    List<Map<String, dynamic>> salesList = [];
    double totalAmount = 0;
    int saleCount = 0;
    double incentive = 0;

    switch (type) {
      case 'accessories':
        breakdown = data.accessoriesBreakdown;
        salesList = data.accessoriesSalesList;
        totalAmount = data.accessoriesTotalAmount;
        saleCount = data.accessoriesSaleCount;
        incentive = data.accessoriesIncentive;
        break;
      case 'phone':
        breakdown = data.phoneBreakdown;
        salesList = data.phoneSalesList;
        totalAmount = data.phoneTotalAmount;
        saleCount = data.phoneSaleCount;
        incentive = data.phoneIncentive;
        break;
      case 'tv':
        breakdown = data.tvBreakdown;
        salesList = data.tvSalesList;
        totalAmount = data.tvTotalAmount;
        saleCount = data.tvSaleCount;
        incentive = data.tvIncentive;
        break;
      case 'secondPhone':
        breakdown = data.secondPhoneBreakdown;
        salesList = data.secondPhoneSalesList;
        totalAmount = data.secondPhoneTotalAmount;
        saleCount = data.secondPhoneSaleCount;
        incentive = data.secondPhoneIncentive;
        break;
      case 'baseModel':
        breakdown = data.baseModelBreakdown;
        salesList = data.baseModelSalesList;
        totalAmount = data.baseModelTotalAmount;
        saleCount = data.baseModelSaleCount;
        incentive = data.baseModelIncentive;
        break;
    }

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
                    children: [
                      Icon(Icons.calculate, color: color, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${_formatNumber(incentive)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
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
                          'Total Sales: ₹${_formatNumber(totalAmount)} | Units: $saleCount',
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: _buildBreakdownSection(breakdown, color),
                          ),
                          if (salesList.isNotEmpty)
                            _buildSalesDetailsSection(salesList, title, color),
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

  Widget _buildBreakdownSection(
    List<Map<String, dynamic>> breakdown,
    Color color,
  ) {
    if (breakdown.isEmpty ||
        (breakdown.length == 1 && breakdown[0].containsKey('message'))) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              breakdown.isNotEmpty
                  ? breakdown[0]['message'] as String
                  : 'No calculation details available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

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
                Icon(Icons.calculate, size: 16, color: color),
                const SizedBox(width: 8),
                const Text(
                  'Calculation Breakdown',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: breakdown.map((item) {
                if (item.containsKey('message')) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['message'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (item['calculation'] != null)
                              Text(
                                item['calculation'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (item['note'] != null)
                              Text(
                                item['note'] as String,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (item['amount'] != null)
                        Text(
                          '₹${_formatNumber((item['amount'] as num).toDouble())}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: (item['amount'] as num) > 0
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesDetailsSection(
    List<Map<String, dynamic>> salesList,
    String title,
    Color color,
  ) {
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
                Icon(Icons.list_alt, size: 16, color: color),
                const SizedBox(width: 8),
                const Text(
                  'Sales Details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: salesList.take(10).map((sale) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              sale['productName'] as String? ?? 'Product',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₹${_formatNumber((sale['amount'] as num).toDouble())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 10,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sale['customerName'] as String? ??
                                'Walk-in Customer',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 10,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'dd MMM',
                            ).format(sale['date'] as DateTime),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (sale['accessoriesAmount'] != null ||
                          sale['serviceAmount'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.build,
                                size: 10,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Accessories: ₹${_formatNumber((sale['accessoriesAmount'] as num).toDouble())} | Service: ₹${_formatNumber((sale['serviceAmount'] as num).toDouble())}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sale['paymentBreakdown'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 10,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cash: ₹${_formatNumber((sale['paymentBreakdown']['cash'] as num).toDouble())} | GPay: ₹${_formatNumber((sale['paymentBreakdown']['gpay'] as num).toDouble())} | Card: ₹${_formatNumber((sale['paymentBreakdown']['card'] as num).toDouble())}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sale['brand'] != null &&
                          sale['brand'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Brand: ${sale['brand']}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      if (sale['imei'] != null &&
                          sale['imei'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'IMEI: ${sale['imei']}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      if (sale['bracket'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 10,
                                color: Colors.amber.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+₹${sale['incentive']} (${sale['bracket']})',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sale['modelBrand'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tv,
                                size: 10,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Brand: ${sale['modelBrand']} | SN: ${sale['serialNumber']}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (salesList.length > 10)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  '+ ${salesList.length - 10} more items',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
            ),
        ],
      ),
    );
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
                    currentPeriodName,
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
                              '📦 Source: accessories_service_sale collection',
                              '💰 Amount = totalSaleAmount OR accessoriesAmount + serviceAmount',
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
                              '   • ₹35,000 - ₹44,999 → ₹70',
                              '   • ₹45,000 - ₹59,999 → ₹90',
                              '   • ₹60,000 - ₹79,999 → ₹130',
                              '   • ₹80,000 - ₹99,999 → ₹150',
                              '   • ₹1,00,000+ → ₹200',
                              '⚠️ Note: No base incentive, only per-phone incentives',
                              '📦 Source: phoneSales collection',
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildConditionCard(
                            title: 'TV Sales',
                            icon: Icons.tv,
                            color: Colors.red,
                            rules: [
                              '💰 Incentive Structure (per piece):',
                              '   • 1-10 pieces → ₹30 per piece',
                              '   • Above 10 pieces → ₹50 per piece',
                              '✨ No minimum quantity required',
                              '📦 Source: bills collection (type: "tv")',
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
                              '📦 Source: seconds_phone_sale collection',
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
                              '📦 Source: base_model_sale collection',
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

  Widget _buildTimePeriodSelector() {
    final now = DateTime.now();
    final lastMonthName = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(now.year, now.month - 1));
    final lastYear = '${now.year - 1}';

    return Container(
      padding: const EdgeInsets.all(8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Color(0xFF0A4D2E),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedTimePeriod,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0A4D2E),
                  ),
                  iconSize: 16,
                  items: [
                    const DropdownMenuItem(
                      value: 'current_month',
                      child: Text(
                        'Current Month',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'last_month',
                      child: Text(
                        'Last Month - $lastMonthName',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'current_year',
                      child: Text(
                        'Current Year',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'last_year',
                      child: Text(
                        'Last Year - $lastYear',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'daily',
                      child: Text('Today', style: TextStyle(fontSize: 11)),
                    ),
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text(
                        'Custom Range',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == 'custom') {
                      final result = await _showCustomDateRangePickerDialog();
                      if (result != null) {
                        setState(() {
                          customStartDate = result['start'];
                          customEndDate = result['end'];
                          isCustomPeriod = true;
                          selectedTimePeriod = 'custom';
                          _updateDateRange();
                          final userData = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).user;
                          if (userData?.shopId != null &&
                              userData!.shopId!.isNotEmpty) {
                            _fetchData(userData.shopId!);
                          }
                        });
                      }
                    } else if (value != null) {
                      setState(() {
                        selectedTimePeriod = value;
                        isCustomPeriod = false;
                        _updateDateRange();
                        final userData = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).user;
                        if (userData?.shopId != null &&
                            userData!.shopId!.isNotEmpty) {
                          _fetchData(userData.shopId!);
                        }
                      });
                    }
                  },
                ),
              ),
              if (isCustomPeriod && customStartDate != null)
                Text(
                  '${DateFormat('dd/MM').format(customStartDate!)} - ${DateFormat('dd/MM').format(customEndDate!)}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF0A4D2E)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, DateTime>?> _showCustomDateRangePickerDialog() async {
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
    if (start == null) return null;

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
    if (end == null) return null;

    return {'start': start, 'end': end};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentive', style: TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF0A4D2E),
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
                _fetchData(userData.shopId!);
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
            CircularProgressIndicator(color: Color(0xFF0A4D2E), strokeWidth: 2),
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
                  _fetchData(userData.shopId!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4D2E),
                minimumSize: const Size(100, 36),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    if (currentIncentiveData == null) {
      return const Center(
        child: Text('No data available', style: TextStyle(fontSize: 13)),
      );
    }

    return Column(
      children: [
        _buildTimePeriodSelector(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A4D2E), Color(0xFF1B6B43)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Period',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  currentPeriodName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Total Incentive',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  '₹${_formatNumber(currentIncentiveData!.totalIncentive)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildIncentiveCard(
                  title: 'Accessories & Service',
                  icon: Icons.shopping_bag,
                  color: Colors.blue,
                  data: currentIncentiveData!,
                  type: 'accessories',
                  onTap: () => _showDetailedCalculation(
                    'Accessories & Service Incentive',
                    currentIncentiveData!,
                    Colors.blue,
                    'accessories',
                  ),
                ),
                const SizedBox(height: 10),
                _buildIncentiveCard(
                  title: 'Phone Sales',
                  icon: Icons.phone_iphone,
                  color: Colors.green,
                  data: currentIncentiveData!,
                  type: 'phone',
                  onTap: () => _showDetailedCalculation(
                    'Phone Sales Incentive',
                    currentIncentiveData!,
                    Colors.green,
                    'phone',
                  ),
                ),
                const SizedBox(height: 10),
                _buildIncentiveCard(
                  title: 'TV Sales',
                  icon: Icons.tv,
                  color: Colors.red,
                  data: currentIncentiveData!,
                  type: 'tv',
                  onTap: () => _showDetailedCalculation(
                    'TV Sales Incentive',
                    currentIncentiveData!,
                    Colors.red,
                    'tv',
                  ),
                ),
                const SizedBox(height: 10),
                _buildIncentiveCard(
                  title: 'Second Phones',
                  icon: Icons.phone_android,
                  color: Colors.orange,
                  data: currentIncentiveData!,
                  type: 'secondPhone',
                  onTap: () => _showDetailedCalculation(
                    'Second Phones Incentive',
                    currentIncentiveData!,
                    Colors.orange,
                    'secondPhone',
                  ),
                ),
                const SizedBox(height: 10),
                _buildIncentiveCard(
                  title: 'Base Models',
                  icon: Icons.devices,
                  color: Colors.purple,
                  data: currentIncentiveData!,
                  type: 'baseModel',
                  onTap: () => _showDetailedCalculation(
                    'Base Models Incentive',
                    currentIncentiveData!,
                    Colors.purple,
                    'baseModel',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncentiveCard({
    required String title,
    required IconData icon,
    required Color color,
    required IncentiveData data,
    required String type,
    required VoidCallback onTap,
  }) {
    double totalAmount = 0;
    int saleCount = 0;
    double incentive = 0;
    String ruleText = '';

    switch (type) {
      case 'accessories':
        totalAmount = data.accessoriesTotalAmount;
        saleCount = data.accessoriesSaleCount;
        incentive = data.accessoriesIncentive;
        ruleText = 'Above ₹1L: ₹1000 + ₹200/₹10k';
        break;
      case 'phone':
        totalAmount = data.phoneTotalAmount;
        saleCount = data.phoneSaleCount;
        incentive = data.phoneIncentive;
        ruleText = '20+ phones & ₹3L+: Per-phone incentive';
        break;
      case 'tv':
        totalAmount = data.tvTotalAmount;
        saleCount = data.tvSaleCount;
        incentive = data.tvIncentive;
        ruleText = saleCount <= 10
            ? '₹30/piece (1-10 pieces)'
            : '₹50/piece (10+ pieces)';
        break;
      case 'secondPhone':
        totalAmount = data.secondPhoneTotalAmount;
        saleCount = data.secondPhoneSaleCount;
        incentive = data.secondPhoneIncentive;
        ruleText = saleCount <= 10
            ? '₹30/piece (1-10 pieces)'
            : '₹40/piece (10+ pieces)';
        break;
      case 'baseModel':
        totalAmount = data.baseModelTotalAmount;
        saleCount = data.baseModelSaleCount;
        incentive = data.baseModelIncentive;
        ruleText = saleCount <= 10
            ? '₹15/piece (1-10 pieces)'
            : '₹25/piece (10+ pieces)';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${_formatNumber(incentive)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onTap,
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
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view detailed calculation',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IncentiveData {
  final double accessoriesTotalAmount;
  final int accessoriesSaleCount;
  final double accessoriesIncentive;
  final List<Map<String, dynamic>> accessoriesBreakdown;
  final List<Map<String, dynamic>> accessoriesSalesList;

  final double phoneTotalAmount;
  final int phoneSaleCount;
  final double phoneIncentive;
  final List<Map<String, dynamic>> phoneBreakdown;
  final List<Map<String, dynamic>> phonePriceDetails;
  final List<Map<String, dynamic>> phoneSalesList;

  final double tvTotalAmount;
  final int tvSaleCount;
  final double tvIncentive;
  final List<Map<String, dynamic>> tvBreakdown;
  final List<Map<String, dynamic>> tvSalesList;

  final double secondPhoneTotalAmount;
  final int secondPhoneSaleCount;
  final double secondPhoneIncentive;
  final List<Map<String, dynamic>> secondPhoneBreakdown;
  final List<Map<String, dynamic>> secondPhoneSalesList;

  final double baseModelTotalAmount;
  final int baseModelSaleCount;
  final double baseModelIncentive;
  final List<Map<String, dynamic>> baseModelBreakdown;
  final List<Map<String, dynamic>> baseModelSalesList;

  final double totalIncentive;

  IncentiveData({
    required this.accessoriesTotalAmount,
    required this.accessoriesSaleCount,
    required this.accessoriesIncentive,
    required this.accessoriesBreakdown,
    required this.accessoriesSalesList,
    required this.phoneTotalAmount,
    required this.phoneSaleCount,
    required this.phoneIncentive,
    required this.phoneBreakdown,
    required this.phonePriceDetails,
    required this.phoneSalesList,
    required this.tvTotalAmount,
    required this.tvSaleCount,
    required this.tvIncentive,
    required this.tvBreakdown,
    required this.tvSalesList,
    required this.secondPhoneTotalAmount,
    required this.secondPhoneSaleCount,
    required this.secondPhoneIncentive,
    required this.secondPhoneBreakdown,
    required this.secondPhoneSalesList,
    required this.baseModelTotalAmount,
    required this.baseModelSaleCount,
    required this.baseModelIncentive,
    required this.baseModelBreakdown,
    required this.baseModelSalesList,
    required this.totalIncentive,
  });
}
