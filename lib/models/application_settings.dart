/// `application_settings/global` singleton doc — admin-configurable
/// platform-wide defaults (§13 Admin dashboard "Settings", §14, §20).
class ApplicationSettings {
  final double platformFeePercent;
  final double defaultDeliveryFee;
  final int defaultReservationExpirationMinutes;
  final List<String> enabledPaymentMethods;
  final bool maintenanceMode;

  const ApplicationSettings({
    this.platformFeePercent = 0,
    this.defaultDeliveryFee = 0,
    this.defaultReservationExpirationMinutes = 120,
    this.enabledPaymentMethods = const ['gcash', 'maya', 'cashOnDelivery', 'simulated'],
    this.maintenanceMode = false,
  });

  factory ApplicationSettings.fromMap(Map<String, dynamic> map) => ApplicationSettings(
        platformFeePercent: (map['platformFeePercent'] ?? 0).toDouble(),
        defaultDeliveryFee: (map['defaultDeliveryFee'] ?? 0).toDouble(),
        defaultReservationExpirationMinutes: map['defaultReservationExpirationMinutes'] ?? 120,
        enabledPaymentMethods: List<String>.from(map['enabledPaymentMethods'] ?? const ['gcash', 'maya', 'cashOnDelivery', 'simulated']),
        maintenanceMode: map['maintenanceMode'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'platformFeePercent': platformFeePercent,
        'defaultDeliveryFee': defaultDeliveryFee,
        'defaultReservationExpirationMinutes': defaultReservationExpirationMinutes,
        'enabledPaymentMethods': enabledPaymentMethods,
        'maintenanceMode': maintenanceMode,
      };
}
