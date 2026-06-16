class Supplier {
  String? id;
  String supplierName;
  String phoneNumber;
  String address;
  String gstin;
  String email;
  DateTime createdAt;

  Supplier({
    this.id,
    required this.supplierName,
    required this.phoneNumber,
    required this.address,
    required this.gstin,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'phoneNumber': phoneNumber,
      'address': address,
      'gstin': gstin,
      'email': email,
      'createdAt': createdAt,
    };
  }

  factory Supplier.fromMap(String id, Map<String, dynamic> map) {
    return Supplier(
      id: id,
      supplierName: map['supplierName'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      gstin: map['gstin'],
      email: map['email'],
      createdAt: (map['createdAt'] as DateTime).toLocal(),
    );
  }
}
