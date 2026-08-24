import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `stores` collection — one per merchant. `merchantId` == owning user id.
class Store {
  final String id;
  final String merchantId;
  final String name;
  final String description;
  final String? logoUrl;
  final String? bannerUrl;
  final String category;
  final String phone;
  final String email;
  final String addressLine;
  final String city;
  final double? latitude;
  final double? longitude;
  final AccountStatus verificationStatus;
  final String? verificationNote;
  final bool barcodeEnabled;
  final int reservationExpirationMinutes;
  final double averageRating;
  final int ratingCount;
  final SubscriptionPlanTier planTier;
  final bool isOpen;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.category,
    required this.phone,
    required this.email,
    required this.addressLine,
    required this.city,
    this.latitude,
    this.longitude,
    required this.verificationStatus,
    this.verificationNote,
    this.barcodeEnabled = false,
    this.reservationExpirationMinutes = 120,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.planTier = SubscriptionPlanTier.free,
    this.isOpen = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Store.fromMap(String id, Map<String, dynamic> map) => Store(
        id: id,
        merchantId: map['merchantId'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        logoUrl: map['logoUrl'],
        bannerUrl: map['bannerUrl'],
        category: map['category'] ?? 'General',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        addressLine: map['addressLine'] ?? '',
        city: map['city'] ?? '',
        latitude: map['latitude']?.toDouble(),
        longitude: map['longitude']?.toDouble(),
        verificationStatus: AccountStatusX.fromName(map['verificationStatus'] ?? 'pendingVerification'),
        verificationNote: map['verificationNote'],
        barcodeEnabled: map['barcodeEnabled'] ?? false,
        reservationExpirationMinutes: map['reservationExpirationMinutes'] ?? 120,
        averageRating: asDouble(map['averageRating']),
        ratingCount: asInt(map['ratingCount']),
        planTier: SubscriptionPlanTierX.fromName(map['planTier'] ?? 'free'),
        isOpen: map['isOpen'] ?? true,
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'category': category,
        'phone': phone,
        'email': email,
        'addressLine': addressLine,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'verificationStatus': verificationStatus.name,
        'verificationNote': verificationNote,
        'barcodeEnabled': barcodeEnabled,
        'reservationExpirationMinutes': reservationExpirationMinutes,
        'averageRating': averageRating,
        'ratingCount': ratingCount,
        'planTier': planTier.name,
        'isOpen': isOpen,
      };

  bool get isVerified => verificationStatus == AccountStatus.active;
}
