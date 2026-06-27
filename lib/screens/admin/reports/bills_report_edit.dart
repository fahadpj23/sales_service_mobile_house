// lib/screens/admin/reports/bills_report_edit.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class BillsReportEdit {
  final FirebaseFirestore firestore;
  final Function(double) formatNumber;
  final Color primaryGreen;
  final Color editPrimaryColor;
  final Color editSecondaryColor;
  final Color warningColor;

  BillsReportEdit({
    required this.firestore,
    required this.formatNumber,
    required this.primaryGreen,
    required this.editPrimaryColor,
    required this.editSecondaryColor,
    required this.warningColor,
  });

  void calculateEditGST({
    required TextEditingController totalAmountController,
    required TextEditingController taxableAmountController,
    required TextEditingController gstAmountController,
    required void Function(void Function()) setState,
  }) {
    if (totalAmountController.text.isNotEmpty) {
      try {
        double totalAmount = double.parse(totalAmountController.text);
        double gstPercent = 18.0;
        double taxableAmount = totalAmount / (1 + gstPercent / 100);
        double gstAmount = totalAmount - taxableAmount;

        setState(() {
          taxableAmountController.text = taxableAmount.toStringAsFixed(2);
          gstAmountController.text = gstAmount.toStringAsFixed(2);
        });
      } catch (e) {
        setState(() {
          taxableAmountController.text = '';
          gstAmountController.text = '';
        });
      }
    } else {
      setState(() {
        taxableAmountController.text = '';
        gstAmountController.text = '';
      });
    }
  }

  Future<void> updateBill({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required String? billId,
    required String? editBillType,
    required TextEditingController customerNameController,
    required TextEditingController mobileController,
    required TextEditingController addressController,
    required TextEditingController totalAmountController,
    required TextEditingController taxableAmountController,
    required TextEditingController gstAmountController,
    required TextEditingController productNameController,
    required TextEditingController imeiController,
    required TextEditingController serialController,
    required String? selectedPurchaseMode,
    required String? selectedFinanceType,
    required bool sealChecked,
    required void Function(void Function()) setState,
    required VoidCallback onUpdateSuccess,
  }) async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      // isUpdating will be set in the parent
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      final updateData = {
        'customerName': customerNameController.text.trim(),
        'customerMobile': mobileController.text.trim(),
        'customerAddress': addressController.text.trim(),
        'totalAmount': double.parse(totalAmountController.text),
        'taxableAmount': double.parse(taxableAmountController.text),
        'gstAmount': double.parse(gstAmountController.text),
        'purchaseMode': selectedPurchaseMode,
        'financeType': selectedFinanceType,
        'sealApplied': sealChecked,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.email,
      };

      // Add type-specific fields
      if (editBillType == 'phone') {
        updateData['productName'] = productNameController.text.trim();
        updateData['imei'] = imeiController.text.trim();
      } else if (editBillType == 'tv') {
        updateData['modelName'] = productNameController.text.trim();
        updateData['serialNumber'] = serialController.text.trim();
        updateData['productName'] = productNameController.text.trim();
      } else {
        updateData['productName'] = productNameController.text.trim();
        if (imeiController.text.trim().isNotEmpty) {
          updateData['imei'] = imeiController.text.trim();
        }
      }

      await firestore.collection('bills').doc(billId).update(updateData);

      // Update phone stock if phone bill
      if (editBillType == 'phone') {
        final imei = imeiController.text.trim();
        if (imei.isNotEmpty) {
          final querySnapshot = await firestore
              .collection('phoneStock')
              .where('imei', isEqualTo: imei)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            await firestore
                .collection('phoneStock')
                .doc(querySnapshot.docs.first.id)
                .update({
                  'soldTo': customerNameController.text.trim(),
                  'soldAmount': double.parse(totalAmountController.text),
                  'purchaseMode': selectedPurchaseMode,
                  'financeType': selectedFinanceType,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      // Update TV stock if TV bill
      if (editBillType == 'tv') {
        final serialNumber = serialController.text.trim();
        if (serialNumber.isNotEmpty) {
          final querySnapshot = await firestore
              .collection('tvStock')
              .where('serialNumber', isEqualTo: serialNumber)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            await firestore
                .collection('tvStock')
                .doc(querySnapshot.docs.first.id)
                .update({
                  'soldTo': customerNameController.text.trim(),
                  'soldAmount': double.parse(totalAmountController.text),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      onUpdateSuccess();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Widget buildEditForm({
    required GlobalKey<FormState> editFormKey,
    required Map<String, dynamic>? editingBill,
    required String? editBillType,
    required TextEditingController customerNameController,
    required TextEditingController mobileController,
    required TextEditingController addressController,
    required TextEditingController totalAmountController,
    required TextEditingController taxableAmountController,
    required TextEditingController gstAmountController,
    required TextEditingController productNameController,
    required TextEditingController imeiController,
    required TextEditingController serialController,
    required String? selectedPurchaseMode,
    required String? selectedFinanceType,
    required bool sealChecked,
    required bool isUpdating,
    required Function(double) formatNumber,
    required Color primaryGreen,
    required Color editPrimaryColor,
    required Color editSecondaryColor,
    required Color warningColor,
    required VoidCallback onCancel,
    required VoidCallback onUpdate,
    required VoidCallback onCalculateGST,
    required void Function(String?) onPurchaseModeChanged,
    required void Function(String?) onFinanceTypeChanged,
    required void Function(bool?) onSealChanged,
  }) {
    final List<String> purchaseModes = ['Ready Cash', 'Credit Card', 'EMI'];
    final List<String> financeCompaniesList = [
      'Bajaj Finance',
      'TVS Credit',
      'HDB Financial',
      'Samsung Finance',
      'Oppo Finance',
      'Vivo Finance',
      'yoga kshema Finance',
      'MI Finance',
      'First credit private Finance',
      'Chola Murugappa',
      'Other',
    ];

    // Get bill type icon
    IconData billIcon;
    String billTypeName;
    if (editBillType == 'tv') {
      billIcon = Icons.tv;
      billTypeName = 'TV Bill';
    } else if (editBillType == 'accessories') {
      billIcon = Icons.shopping_bag;
      billTypeName = 'Accessories Bill';
    } else {
      billIcon = Icons.phone_android;
      billTypeName = 'Phone Bill';
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Form(
        key: editFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill info header
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [editPrimaryColor, editSecondaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: editPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(billIcon, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editing $billTypeName',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          editingBill?['billNumber'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(
                        editingBill?['billDate'] is Timestamp
                            ? (editingBill!['billDate'] as Timestamp).toDate()
                            : DateTime.now(),
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // Product info card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 16,
                          color: editPrimaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Product Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: productNameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(
                          Icons.production_quantity_limits,
                          size: 18,
                          color: editPrimaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      validator: (value) =>
                          value?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    if (editBillType == 'phone' ||
                        editBillType == 'accessories') ...[
                      SizedBox(height: 10),
                      TextFormField(
                        controller: imeiController,
                        decoration: InputDecoration(
                          labelText: 'IMEI Number',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(
                            Icons.qr_code,
                            size: 18,
                            color: editPrimaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                    if (editBillType == 'tv') ...[
                      SizedBox(height: 10),
                      TextFormField(
                        controller: serialController,
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          labelStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(
                            Icons.confirmation_number,
                            size: 18,
                            color: editPrimaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Customer details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: editPrimaryColor),
                        SizedBox(width: 6),
                        Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: customerNameController,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      validator: (value) =>
                          value?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.phone, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.trim().isEmpty == true) return 'Required';
                        if (value?.trim().length != 10)
                          return 'Enter 10-digit number';
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.location_on, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Amount details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.currency_rupee,
                          size: 16,
                          color: editPrimaryColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Amount Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: totalAmountController,
                      decoration: InputDecoration(
                        labelText: 'Total Amount *',
                        labelStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.currency_rupee, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) => onCalculateGST(),
                      validator: (value) {
                        if (value?.trim().isEmpty == true) return 'Required';
                        if (double.tryParse(value!.trim()) == null)
                          return 'Invalid amount';
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: editPrimaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: editPrimaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taxable Amount (18% GST):',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '₹${taxableAmountController.text}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GST Amount:',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '₹${gstAmountController.text}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: warningColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Payment details card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: editPrimaryColor),
                        SizedBox(width: 6),
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: editPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedPurchaseMode,
                      decoration: InputDecoration(
                        labelText: 'Purchase Mode',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                      dropdownColor: Colors.white,
                      iconEnabledColor: Colors.black87,
                      items: purchaseModes.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(
                            mode,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: onPurchaseModeChanged,
                    ),
                    if (selectedPurchaseMode == 'EMI') ...[
                      SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedFinanceType,
                        decoration: InputDecoration(
                          labelText: 'Finance Company',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        dropdownColor: Colors.white,
                        iconEnabledColor: Colors.black87,
                        items: financeCompaniesList.map((company) {
                          return DropdownMenuItem<String>(
                            value: company,
                            child: Text(
                              company,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: onFinanceTypeChanged,
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: sealChecked,
                            onChanged: onSealChanged,
                            activeColor: editPrimaryColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Apply Seal on Bill',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel, // This now calls _cancelEdit properly
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Cancel', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUpdating ? null : onUpdate,
                    icon: isUpdating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.save, size: 18),
                    label: Text(
                      isUpdating ? 'Updating...' : 'Update Bill',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: editPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
