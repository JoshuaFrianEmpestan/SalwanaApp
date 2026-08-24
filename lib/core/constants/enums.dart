/// Central enum definitions shared by every module. Firestore stores the
/// `.name` string of each enum; always round-trip through `fromName`.
library;

enum UserRole { consumer, merchant, supplier, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.consumer => 'Consumer',
        UserRole.merchant => 'Merchant',
        UserRole.supplier => 'Supplier',
        UserRole.admin => 'Administrator',
      };

  static UserRole fromName(String name) =>
      UserRole.values.firstWhere((e) => e.name == name, orElse: () => UserRole.consumer);
}

/// Verification/account status shared by merchant & supplier profiles, and
/// generally by user accounts (admin can suspend/deactivate any account).
enum AccountStatus { pendingVerification, active, suspended, rejected, deactivated }

extension AccountStatusX on AccountStatus {
  String get label => switch (this) {
        AccountStatus.pendingVerification => 'Pending Verification',
        AccountStatus.active => 'Active',
        AccountStatus.suspended => 'Suspended',
        AccountStatus.rejected => 'Rejected',
        AccountStatus.deactivated => 'Deactivated',
      };

  static AccountStatus fromName(String name) => AccountStatus.values
      .firstWhere((e) => e.name == name, orElse: () => AccountStatus.pendingVerification);
}

enum ProductStatus { active, archived, outOfStock, deactivated }

extension ProductStatusX on ProductStatus {
  String get label => switch (this) {
        ProductStatus.active => 'Active',
        ProductStatus.archived => 'Archived',
        ProductStatus.outOfStock => 'Out of Stock',
        ProductStatus.deactivated => 'Deactivated',
      };

  static ProductStatus fromName(String name) =>
      ProductStatus.values.firstWhere((e) => e.name == name, orElse: () => ProductStatus.active);
}

/// Inventory movement types — every stock change must be one of these.
enum MovementType {
  stockIn,
  sale,
  reservation,
  reservationReleased,
  returned,
  damage,
  expired,
  manualAdjustment,
  supplierDelivery,
}

extension MovementTypeX on MovementType {
  String get label => switch (this) {
        MovementType.stockIn => 'Stock In',
        MovementType.sale => 'Sale',
        MovementType.reservation => 'Reservation',
        MovementType.reservationReleased => 'Reservation Released',
        MovementType.returned => 'Return',
        MovementType.damage => 'Damage',
        MovementType.expired => 'Expired',
        MovementType.manualAdjustment => 'Manual Adjustment',
        MovementType.supplierDelivery => 'Supplier Delivery',
      };

  static MovementType fromName(String name) =>
      MovementType.values.firstWhere((e) => e.name == name, orElse: () => MovementType.manualAdjustment);
}

enum ReservationStatus {
  pending,
  approved,
  preparing,
  readyForPickup,
  outForDelivery,
  completed,
  rejected,
  cancelled,
  expired,
}

extension ReservationStatusX on ReservationStatus {
  String get label => switch (this) {
        ReservationStatus.pending => 'Pending',
        ReservationStatus.approved => 'Approved',
        ReservationStatus.preparing => 'Preparing',
        ReservationStatus.readyForPickup => 'Ready for Pickup',
        ReservationStatus.outForDelivery => 'Out for Delivery',
        ReservationStatus.completed => 'Completed',
        ReservationStatus.rejected => 'Rejected',
        ReservationStatus.cancelled => 'Cancelled',
        ReservationStatus.expired => 'Expired',
      };

  bool get isTerminal => this == ReservationStatus.completed ||
      this == ReservationStatus.rejected ||
      this == ReservationStatus.cancelled ||
      this == ReservationStatus.expired;

  /// Statuses where the reserved quantity is still held (not yet released).
  bool get holdsStock => !isTerminal;

  static ReservationStatus fromName(String name) => ReservationStatus.values
      .firstWhere((e) => e.name == name, orElse: () => ReservationStatus.pending);
}

enum OrderStatus {
  pendingPayment,
  paid,
  confirmed,
  preparing,
  readyForPickup,
  outForDelivery,
  completed,
  cancelled,
  refunded,
  paymentFailed,
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pendingPayment => 'Pending Payment',
        OrderStatus.paid => 'Paid',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.readyForPickup => 'Ready for Pickup',
        OrderStatus.outForDelivery => 'Out for Delivery',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.refunded => 'Refunded',
        OrderStatus.paymentFailed => 'Payment Failed',
      };

  bool get isActive => !{
        OrderStatus.completed,
        OrderStatus.cancelled,
        OrderStatus.refunded,
        OrderStatus.paymentFailed,
      }.contains(this);

  static OrderStatus fromName(String name) =>
      OrderStatus.values.firstWhere((e) => e.name == name, orElse: () => OrderStatus.pendingPayment);
}

enum FulfillmentType { pickup, delivery }

extension FulfillmentTypeX on FulfillmentType {
  String get label => this == FulfillmentType.pickup ? 'Pickup' : 'Delivery';
  static FulfillmentType fromName(String name) =>
      FulfillmentType.values.firstWhere((e) => e.name == name, orElse: () => FulfillmentType.pickup);
}

enum PaymentMethod { gcash, maya, cashOnDelivery, simulated }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.gcash => 'GCash',
        PaymentMethod.maya => 'Maya',
        PaymentMethod.cashOnDelivery => 'Cash on Delivery',
        PaymentMethod.simulated => 'Simulated Payment',
      };

  static PaymentMethod fromName(String name) =>
      PaymentMethod.values.firstWhere((e) => e.name == name, orElse: () => PaymentMethod.simulated);
}

enum PaymentStatus { pending, processing, successful, failed, cancelled, refunded }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.processing => 'Processing',
        PaymentStatus.successful => 'Successful',
        PaymentStatus.failed => 'Failed',
        PaymentStatus.cancelled => 'Cancelled',
        PaymentStatus.refunded => 'Refunded',
      };

  static PaymentStatus fromName(String name) =>
      PaymentStatus.values.firstWhere((e) => e.name == name, orElse: () => PaymentStatus.pending);
}

enum RestockStatus {
  draft,
  requested,
  accepted,
  rejected,
  processing,
  dispatched,
  delivered,
  partiallyReceived,
  received,
  cancelled,
}

extension RestockStatusX on RestockStatus {
  String get label => switch (this) {
        RestockStatus.draft => 'Draft',
        RestockStatus.requested => 'Requested',
        RestockStatus.accepted => 'Accepted',
        RestockStatus.rejected => 'Rejected',
        RestockStatus.processing => 'Processing',
        RestockStatus.dispatched => 'Dispatched',
        RestockStatus.delivered => 'Delivered',
        RestockStatus.partiallyReceived => 'Partially Received',
        RestockStatus.received => 'Received',
        RestockStatus.cancelled => 'Cancelled',
      };

  static RestockStatus fromName(String name) =>
      RestockStatus.values.firstWhere((e) => e.name == name, orElse: () => RestockStatus.draft);
}

enum CreditStatus { active, partiallyPaid, fullyPaid, overdue, cancelled }

extension CreditStatusX on CreditStatus {
  String get label => switch (this) {
        CreditStatus.active => 'Active',
        CreditStatus.partiallyPaid => 'Partially Paid',
        CreditStatus.fullyPaid => 'Fully Paid',
        CreditStatus.overdue => 'Overdue',
        CreditStatus.cancelled => 'Cancelled',
      };

  static CreditStatus fromName(String name) =>
      CreditStatus.values.firstWhere((e) => e.name == name, orElse: () => CreditStatus.active);
}

enum SubscriptionPlanTier { free, premium }

extension SubscriptionPlanTierX on SubscriptionPlanTier {
  String get label => this == SubscriptionPlanTier.free ? 'Free' : 'Premium';
  static SubscriptionPlanTier fromName(String name) => SubscriptionPlanTier.values
      .firstWhere((e) => e.name == name, orElse: () => SubscriptionPlanTier.free);
}

enum NotificationType {
  newOrder,
  reservationRequest,
  reservationApproved,
  reservationRejected,
  reservationExpiring,
  paymentSuccessful,
  paymentFailed,
  orderStatusUpdate,
  deliveryStatusUpdate,
  lowStock,
  backInStock,
  restockRequest,
  supplierResponse,
  loanDueReminder,
  creditDueReminder,
  subscriptionExpiring,
  accountVerification,
  securityAlert,
  reviewReceived,
  general,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromName(String name) =>
      NotificationType.values.firstWhere((e) => e.name == name, orElse: () => NotificationType.general);
}

enum ExpenseCategory { rent, utilities, salaries, supplies, marketing, transportation, maintenance, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.rent => 'Rent',
        ExpenseCategory.utilities => 'Utilities',
        ExpenseCategory.salaries => 'Salaries',
        ExpenseCategory.supplies => 'Supplies',
        ExpenseCategory.marketing => 'Marketing',
        ExpenseCategory.transportation => 'Transportation',
        ExpenseCategory.maintenance => 'Maintenance',
        ExpenseCategory.other => 'Other',
      };

  static ExpenseCategory fromName(String name) =>
      ExpenseCategory.values.firstWhere((e) => e.name == name, orElse: () => ExpenseCategory.other);
}
