import '../constants/enums.dart';
import 'status_badge.dart';

BadgeTone reservationStatusTone(ReservationStatus status) => switch (status) {
      ReservationStatus.pending => BadgeTone.pending,
      ReservationStatus.approved => BadgeTone.info,
      ReservationStatus.preparing => BadgeTone.info,
      ReservationStatus.readyForPickup => BadgeTone.success,
      ReservationStatus.outForDelivery => BadgeTone.success,
      ReservationStatus.completed => BadgeTone.success,
      ReservationStatus.rejected => BadgeTone.error,
      ReservationStatus.cancelled => BadgeTone.neutral,
      ReservationStatus.expired => BadgeTone.neutral,
    };
