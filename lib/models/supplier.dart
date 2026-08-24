import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `suppliers` collection — one per supplier user.
class SupplierProfile {
  final String id;
  final String userId;
  final String companyName;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final List<String> suppliedCategories;
  final AccountStatus verificationStatus;
  final String? verificationNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierProfile({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    this.suppliedCategories = const [],
    required this.verificationStatus,
    this.verificationNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierProfile.fromMap(String id, Map<String, dynamic> map) => SupplierProfile(
        id: id,
        userId: map['userId'] ?? '',
        companyName: map['companyName'] ?? '',
        contactName: map['contactName'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        address: map['address'] ?? '',
        suppliedCategories: List<String>.from(map['suppliedCategories'] ?? const []),
        verificationStatus: AccountStatusX.fromName(map['verificationStatus'] ?? 'pendingVerification'),
        verificationNote: map['verificationNote'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'companyName': companyName,
        'contactName': contactName,
        'phone': phone,
        'email': email,
        'address': address,
        'suppliedCategories': suppliedCategories,
        'verificationStatus': verificationStatus.name,
        'verificationNote': verificationNote,
      };
}

/// `supplier_products` collection — items/supplies a supplier offers.
class SupplierProduct {
  final String id;
  final String supplierId;
  final String name;
  final String description;
  final String category;
  final double unitCost;
  final String unit;
  final int minOrderQuantity;
  final bool isAvailable;
  final DateTime createdAt;

  const SupplierProduct({
    required this.id,
    required this.supplierId,
    required this.name,
    required this.description,
    required this.category,
    required this.unitCost,
    required this.unit,
    this.minOrderQuantity = 1,
    this.isAvailable = true,
    required this.createdAt,
  });

  factory SupplierProduct.fromMap(String id, Map<String, dynamic> map) => SupplierProduct(
        id: id,
        supplierId: map['supplierId'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        category: map['category'] ?? 'General',
        unitCost: asDouble(map['unitCost']),
        unit: map['unit'] ?? 'pc',
        minOrderQuantity: asInt(map['minOrderQuantity'], 1),
        isAvailable: map['isAvailable'] ?? true,
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'name': name,
        'description': description,
        'category': category,
        'unitCost': unitCost,
        'unit': unit,
        'minOrderQuantity': minOrderQuantity,
        'isAvailable': isAvailable,
      };
}
