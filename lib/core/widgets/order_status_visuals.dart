import '../constants/enums.dart';
import 'status_badge.dart';

BadgeTone orderStatusTone(OrderStatus status) => switch (status) {
      OrderStatus.pendingPayment => BadgeTone.warning,
      OrderStatus.paid => BadgeTone.info,
      OrderStatus.confirmed => BadgeTone.info,
      OrderStatus.preparing => BadgeTone.info,
      OrderStatus.readyForPickup => BadgeTone.success,
      OrderStatus.outForDelivery => BadgeTone.success,
      OrderStatus.completed => BadgeTone.success,
      OrderStatus.cancelled => BadgeTone.neutral,
      OrderStatus.refunded => BadgeTone.neutral,
      OrderStatus.paymentFailed => BadgeTone.error,
    };
