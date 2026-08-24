import '../core/utils/firestore_helpers.dart';

/// `addresses` collection — saved consumer delivery addresses.
class Address {
  final String id;
  final String userId;
  final String label;
  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String province;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;

  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    this.line2,
    required this.city,
    required this.province,
    required this.postalCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    required this.createdAt,
  });

  String get fullAddress => <String>[
        line1,
        if (line2 != null && line2!.isNotEmpty) line2!,
        city,
        province,
        postalCode,
      ].where((e) => e.isNotEmpty).join(', ');

  factory Address.fromMap(String id, Map<String, dynamic> map) => Address(
        id: id,
        userId: map['userId'] ?? '',
        label: map['label'] ?? 'Home',
        recipientName: map['recipientName'] ?? '',
        phone: map['phone'] ?? '',
        line1: map['line1'] ?? '',
        line2: map['line2'],
        city: map['city'] ?? '',
        province: map['province'] ?? '',
        postalCode: map['postalCode'] ?? '',
        latitude: map['latitude']?.toDouble(),
        longitude: map['longitude']?.toDouble(),
        isDefault: map['isDefault'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'line1': line1,
        'line2': line2,
        'city': city,
        'province': province,
        'postalCode': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'isDefault': isDefault,
      };
}
