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
  Map<String, bool> shopLoadingStatus = {};
  bool isLoading = false;
  bool isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _calculateAllShopIncentives();
  }

  Future<void> _calculateAllShopIncentives() async {
    setState(() {
      isLoading = true;
      isInitialLoad = true;
      shopIncentives.clear();
      shopLoadingStatus.clear();

      // Initialize loading status for all shops
      for (var shop in widget.shops) {
        String shopId = shop['id'];
        shopLoadingStatus[shopId] = true;
      }
    });

    // Fetch data for all shops in parallel
    final List<Future> fetchFutures = [];
    for (var shop in widget.shops) {
      String shopId = shop['id'];
      String shopName = shop['name'];
      fetchFutures.add(_fetchShopData(shopId, shopName));
    }

    await Future.wait(fetchFutures);

    setState(() {
      isLoading = false;
      isInitialLoad = false;
    });
  }

  Future<void> _fetchShopData(String shopId, String shopName) async {
    try {
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

      // Fetch all sales data from Firestore collections in parallel
      final results = await Future.wait([
        _fetchAccessoriesSales(shopId, startDate, endDate),
        _fetchPhoneSales(shopId, startDate, endDate),
        _fetchTvSales(shopId, startDate, endDate),
        _fetchSecondPhoneSales(shopId, startDate, endDate),
        _fetchBaseModelSales(shopId, startDate, endDate),
      ]);

      final accessoriesData = results[0];
      final phoneData = results[1];
      final tvData = results[2];
      final secondPhoneData = results[3];
      final baseModelData = results[4];

      final accessoriesIncentive = _calculateAccessoriesIncentive(
        accessoriesData,
      );
      final phoneIncentive = _calculatePhoneIncentive(phoneData);
      final tvIncentive = _calculateTvIncentive(tvData);
      final secondPhoneIncentive = _calculateSecondPhoneIncentive(
        secondPhoneData,
      );
      final baseModelIncentive = _calculateBaseModelIncentive(baseModelData);

      final incentiveData = ShopIncentiveData(
        shopName: shopName,
        totalSales:
            (accessoriesData['totalAmount'] as double? ?? 0) +
            (phoneData['totalAmount'] as double? ?? 0) +
            (tvData['totalAmount'] as double? ?? 0) +
            (secondPhoneData['totalAmount'] as double? ?? 0) +
            (baseModelData['totalAmount'] as double? ?? 0),
        accessoriesTotal: accessoriesData['totalAmount'] as double? ?? 0,
        accessoriesIncentive: accessoriesIncentive['amount'] as double? ?? 0,
        accessoriesBreakdown: List<Map<String, dynamic>>.from(
          accessoriesIncentive['breakdown'] as List? ?? [],
        ),
        accessoriesSalesList: List<Map<String, dynamic>>.from(
          accessoriesData['sales'] as List? ?? [],
        ),
        phoneTotalAmount: phoneData['totalAmount'] as double? ?? 0,
        phoneCount: phoneData['count'] as int? ?? 0,
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
        tvCount: tvData['count'] as int? ?? 0,
        tvIncentive: tvIncentive['amount'] as double? ?? 0,
        tvBreakdown: List<Map<String, dynamic>>.from(
          tvIncentive['breakdown'] as List? ?? [],
        ),
        tvSalesList: List<Map<String, dynamic>>.from(
          tvData['sales'] as List? ?? [],
        ),
        secondPhoneTotalAmount: secondPhoneData['totalAmount'] as double? ?? 0,
        secondPhoneCount: secondPhoneData['count'] as int? ?? 0,
        secondPhoneIncentive: secondPhoneIncentive['amount'] as double? ?? 0,
        secondPhoneBreakdown: List<Map<String, dynamic>>.from(
          secondPhoneIncentive['breakdown'] as List? ?? [],
        ),
        secondPhoneSalesList: List<Map<String, dynamic>>.from(
          secondPhoneData['sales'] as List? ?? [],
        ),
        baseModelTotalAmount: baseModelData['totalAmount'] as double? ?? 0,
        baseModelCount: baseModelData['count'] as int? ?? 0,
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

      setState(() {
        shopIncentives[shopId] = incentiveData;
        shopLoadingStatus[shopId] = false;
      });
    } catch (e) {
      print('Error fetching data for shop $shopName: $e');
      setState(() {
        shopIncentives[shopId] = ShopIncentiveData(
          shopName: shopName,
          totalSales: 0,
          accessoriesTotal: 0,
          accessoriesIncentive: 0,
          accessoriesBreakdown: [],
          accessoriesSalesList: [],
          phoneTotalAmount: 0,
          phoneCount: 0,
          phoneIncentive: 0,
          phoneBreakdown: [],
          phonePriceDetails: [],
          phoneSalesList: [],
          tvTotalAmount: 0,
          tvCount: 0,
          tvIncentive: 0,
          tvBreakdown: [],
          tvSalesList: [],
          secondPhoneTotalAmount: 0,
          secondPhoneCount: 0,
          secondPhoneIncentive: 0,
          secondPhoneBreakdown: [],
          secondPhoneSalesList: [],
          baseModelTotalAmount: 0,
          baseModelCount: 0,
          baseModelIncentive: 0,
          baseModelBreakdown: [],
          baseModelSalesList: [],
          totalIncentive: 0,
        );
        shopLoadingStatus[shopId] = false;
      });
    }
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

        if (_isDateInRange(saleDate, startDate, endDate)) {
          final totalSaleAmount =
              (saleData['totalSaleAmount'] as num?)?.toDouble() ?? 0;
          final accessoriesAmount =
              (saleData['accessoriesAmount'] as num?)?.toDouble() ?? 0;
          final serviceAmount =
              (saleData['serviceAmount'] as num?)?.toDouble() ?? 0;

          double amount;
          if (totalSaleAmount > 0) {
            amount = totalSaleAmount;
          } else {
            amount = accessoriesAmount + serviceAmount;
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
        }
      }
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
    if (data['dateString'] != null && data['dateString'] is String) {
      try {
        return DateTime.parse(data['dateString']);
      } catch (e) {
        print('Error parsing dateString: $e');
      }
    }
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
    return DateTime.now();
  }

  bool _isDateInRange(DateTime date, DateTime startDate, DateTime endDate) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return dateOnly.isAfter(startOnly.subtract(const Duration(days: 1))) &&
        dateOnly.isBefore(endOnly.add(const Duration(days: 1)));
  }

  Map<String, dynamic> _calculateAccessoriesIncentive(
    Map<String, dynamic> salesData,
  ) {
    final totalAmount = salesData['totalAmount'] as double? ?? 0;

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
                          '₹${_formatNumber(data.totalIncentive)}',
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
                          'Total Sales: ₹${_formatNumber(data.totalSales)}',
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
                            margin: const EdgeInsets.only(bottom: 8),
                            child: _buildPeriodHeader(
                              _getPeriodDisplayText(),
                              Icons.today,
                            ),
                          ),
                          _buildIncentiveDetailCard(
                            title: 'Accessories & Service',
                            icon: Icons.shopping_bag,
                            color: Colors.blue,
                            totalAmount: data.accessoriesTotal,
                            incentive: data.accessoriesIncentive,
                            breakdown: data.accessoriesBreakdown,
                            salesList: data.accessoriesSalesList,
                            rule: 'Above ₹1,00,000: ₹1000 + ₹200/₹10k',
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Phone Sales',
                            icon: Icons.phone_iphone,
                            color: Colors.green,
                            totalAmount: data.phoneTotalAmount,
                            count: data.phoneCount,
                            incentive: data.phoneIncentive,
                            breakdown: data.phoneBreakdown,
                            salesList: data.phoneSalesList,
                            rule: '20+ phones & ₹3L+: Only per-phone incentive',
                            showPriceDetails: true,
                            priceDetails: data.phonePriceDetails,
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'TV Sales',
                            icon: Icons.tv,
                            color: Colors.red,
                            count: data.tvCount,
                            incentive: data.tvIncentive,
                            breakdown: data.tvBreakdown,
                            salesList: data.tvSalesList,
                            rule: data.tvCount == 0
                                ? 'No sales recorded'
                                : (data.tvCount <= 10
                                      ? '₹30/piece (1-10 pieces)'
                                      : '₹50/piece (10+ pieces)'),
                            detailType: 'tv',
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Second Phones',
                            icon: Icons.phone_android,
                            color: Colors.orange,
                            count: data.secondPhoneCount,
                            incentive: data.secondPhoneIncentive,
                            breakdown: data.secondPhoneBreakdown,
                            salesList: data.secondPhoneSalesList,
                            rule: data.secondPhoneCount == 0
                                ? 'No sales recorded'
                                : (data.secondPhoneCount <= 10
                                      ? '₹30/piece (1-10 pieces)'
                                      : '₹40/piece (10+ pieces)'),
                          ),
                          const SizedBox(height: 12),
                          _buildIncentiveDetailCard(
                            title: 'Base Models',
                            icon: Icons.devices,
                            color: Colors.purple,
                            count: data.baseModelCount,
                            incentive: data.baseModelIncentive,
                            breakdown: data.baseModelBreakdown,
                            salesList: data.baseModelSalesList,
                            rule: data.baseModelCount == 0
                                ? 'No sales recorded'
                                : (data.baseModelCount <= 10
                                      ? '₹15/piece (1-10 pieces)'
                                      : '₹25/piece (10+ pieces)'),
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

  Widget _buildPeriodHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A4D2E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0A4D2E)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0A4D2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncentiveDetailCard({
    required String title,
    required IconData icon,
    required Color color,
    double totalAmount = 0,
    int count = 0,
    double incentive = 0,
    required List<Map<String, dynamic>> breakdown,
    required List<Map<String, dynamic>> salesList,
    required String rule,
    bool showPriceDetails = false,
    List<Map<String, dynamic>>? priceDetails,
    String detailType = 'default',
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
                    incentive > 0 ? '₹${_formatNumber(incentive)}' : '₹0',
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
                                  '₹${_formatNumber(totalAmount)}',
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
                _buildBreakdownSection(breakdown, color),
                if (salesList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildSalesDetailsSection(
                    salesList,
                    title,
                    color,
                    detailType,
                  ),
                ],
                if (showPriceDetails &&
                    priceDetails != null &&
                    priceDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPriceDetailsSection(priceDetails, color),
                ],
              ],
            ),
          ),
        ],
      ),
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
    String detailType,
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
                      if (detailType == 'tv' && sale['modelBrand'] != null)
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

  Widget _buildPriceDetailsSection(
    List<Map<String, dynamic>> priceDetails,
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
                Icon(Icons.emoji_events, size: 16, color: color),
                const SizedBox(width: 8),
                const Text(
                  'Phone-wise Breakdown',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: priceDetails.take(10).map((phone) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            '₹${_formatNumber(phone['amount'])}',
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
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoading ? null : _calculateAllShopIncentives,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTimePeriodSelector(),
          if (!isInitialLoad && shopIncentives.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildSummaryCard(
                title: _getPeriodDisplayText(),
                totalIncentive: totalIncentiveAllShops,
                shopsWithIncentive: totalShopsWithIncentive,
                totalShops: shopIncentives.length,
                icon: Icons.today,
              ),
            ),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Show initial loading state
    if (isInitialLoad && shopIncentives.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4D2E)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading shop data...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show loading state while refreshing but shops already exist
    if (isLoading && shopIncentives.isNotEmpty) {
      return Stack(
        children: [
          _buildShopList(),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0A4D2E),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Refreshing data...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Show empty state if no shops
    if (shopIncentives.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No shops available',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show the shop list
    return _buildShopList();
  }

  Widget _buildShopList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.shops.length,
      itemBuilder: (context, index) {
        final shop = widget.shops[index];
        final String shopId = shop['id'];
        final bool isShopLoading = shopLoadingStatus[shopId] ?? false;
        final ShopIncentiveData? entry = shopIncentives[shopId];

        // Show loading skeleton for shops still loading
        if (isShopLoading || entry == null) {
          return _buildLoadingShopCard(shop['name'] ?? 'Loading...');
        }

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: entry.totalIncentive > 0
                                  ? const Color(0xFF0A4D2E).withOpacity(0.1)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
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
                            ? const Color(0xFF0A4D2E).withOpacity(0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.totalIncentive > 0
                            ? '₹${_formatNumber(entry.totalIncentive)}'
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
                      'TV',
                      entry.tvIncentive,
                      Colors.red,
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
                const SizedBox(height: 4),
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
    );
  }

  Widget _buildLoadingShopCard(String shopName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
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
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(
                  width: 40,
                  height: 14,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 8,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 12,
                        color: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Loading data...',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double totalIncentive,
    required int shopsWithIncentive,
    required int totalShops,
    required IconData icon,
  }) {
    return Container(
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
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_formatNumber(totalIncentive)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$shopsWithIncentive/$totalShops shops',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9),
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
              value > 0 ? '₹${_formatNumber(value)}' : '₹0',
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

  // Accessories
  final double accessoriesTotal;
  final double accessoriesIncentive;
  final List<Map<String, dynamic>> accessoriesBreakdown;
  final List<Map<String, dynamic>> accessoriesSalesList;

  // Phone
  final double phoneTotalAmount;
  final int phoneCount;
  final double phoneIncentive;
  final List<Map<String, dynamic>> phoneBreakdown;
  final List<Map<String, dynamic>> phonePriceDetails;
  final List<Map<String, dynamic>> phoneSalesList;

  // TV
  final double tvTotalAmount;
  final int tvCount;
  final double tvIncentive;
  final List<Map<String, dynamic>> tvBreakdown;
  final List<Map<String, dynamic>> tvSalesList;

  // Second Phone
  final double secondPhoneTotalAmount;
  final int secondPhoneCount;
  final double secondPhoneIncentive;
  final List<Map<String, dynamic>> secondPhoneBreakdown;
  final List<Map<String, dynamic>> secondPhoneSalesList;

  // Base Model
  final double baseModelTotalAmount;
  final int baseModelCount;
  final double baseModelIncentive;
  final List<Map<String, dynamic>> baseModelBreakdown;
  final List<Map<String, dynamic>> baseModelSalesList;

  final double totalIncentive;

  ShopIncentiveData({
    required this.shopName,
    required this.totalSales,
    required this.accessoriesTotal,
    required this.accessoriesIncentive,
    required this.accessoriesBreakdown,
    required this.accessoriesSalesList,
    required this.phoneTotalAmount,
    required this.phoneCount,
    required this.phoneIncentive,
    required this.phoneBreakdown,
    required this.phonePriceDetails,
    required this.phoneSalesList,
    required this.tvTotalAmount,
    required this.tvCount,
    required this.tvIncentive,
    required this.tvBreakdown,
    required this.tvSalesList,
    required this.secondPhoneTotalAmount,
    required this.secondPhoneCount,
    required this.secondPhoneIncentive,
    required this.secondPhoneBreakdown,
    required this.secondPhoneSalesList,
    required this.baseModelTotalAmount,
    required this.baseModelCount,
    required this.baseModelIncentive,
    required this.baseModelBreakdown,
    required this.baseModelSalesList,
    required this.totalIncentive,
  });
}
