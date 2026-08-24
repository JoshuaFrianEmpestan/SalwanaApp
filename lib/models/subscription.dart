import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `subscription_plans` collection — admin-configurable plan definitions.
class SubscriptionPlan {
  final String id;
  final SubscriptionPlanTier tier;
  final String name;
  final double monthlyPrice;
  final int productLimit; // -1 = unlimited
  final bool advancedAnalytics;
  final bool pdfExcelReports;
  final bool lowStockAutomation;
  final bool supplierManagement;
  final bool barcodeFeatures;
  final int transactionHistoryDays; // -1 = unlimited
  final bool prioritySupport;

  const SubscriptionPlan({
    required this.id,
    required this.tier,
    required this.name,
    required this.monthlyPrice,
    required this.productLimit,
    this.advancedAnalytics = false,
    this.pdfExcelReports = false,
    this.lowStockAutomation = false,
    this.supplierManagement = false,
    this.barcodeFeatures = false,
    this.transactionHistoryDays = 90,
    this.prioritySupport = false,
  });

  factory SubscriptionPlan.fromMap(String id, Map<String, dynamic> map) => SubscriptionPlan(
        id: id,
        tier: SubscriptionPlanTierX.fromName(map['tier'] ?? 'free'),
        name: map['name'] ?? '',
        monthlyPrice: asDouble(map['monthlyPrice']),
        productLimit: asInt(map['productLimit'], 20),
        advancedAnalytics: map['advancedAnalytics'] ?? false,
        pdfExcelReports: map['pdfExcelReports'] ?? false,
        lowStockAutomation: map['lowStockAutomation'] ?? false,
        supplierManagement: map['supplierManagement'] ?? false,
        barcodeFeatures: map['barcodeFeatures'] ?? false,
        transactionHistoryDays: asInt(map['transactionHistoryDays'], 90),
        prioritySupport: map['prioritySupport'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'tier': tier.name,
        'name': name,
        'monthlyPrice': monthlyPrice,
        'productLimit': productLimit,
        'advancedAnalytics': advancedAnalytics,
        'pdfExcelReports': pdfExcelReports,
        'lowStockAutomation': lowStockAutomation,
        'supplierManagement': supplierManagement,
        'barcodeFeatures': barcodeFeatures,
        'transactionHistoryDays': transactionHistoryDays,
        'prioritySupport': prioritySupport,
      };
}

/// `subscriptions` collection — a merchant's active/expired subscription.
class MerchantSubscription {
  final String id;
  final String merchantId;
  final String storeId;
  final String planId;
  final SubscriptionPlanTier tier;
  final DateTime startedAt;
  final DateTime expiresAt;
  final bool autoRenew;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MerchantSubscription({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.planId,
    required this.tier,
    required this.startedAt,
    required this.expiresAt,
    this.autoRenew = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => tier == SubscriptionPlanTier.premium && DateTime.now().isBefore(expiresAt);

  factory MerchantSubscription.fromMap(String id, Map<String, dynamic> map) => MerchantSubscription(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        planId: map['planId'] ?? '',
        tier: SubscriptionPlanTierX.fromName(map['tier'] ?? 'free'),
        startedAt: tsToDateOrNow(map['startedAt']),
        expiresAt: tsToDateOrNow(map['expiresAt']),
        autoRenew: map['autoRenew'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'planId': planId,
        'tier': tier.name,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'autoRenew': autoRenew,
      };
}
