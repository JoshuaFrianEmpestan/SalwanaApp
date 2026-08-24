import '../constants/enums.dart';
import 'status_badge.dart';

BadgeTone restockStatusTone(RestockStatus status) => switch (status) {
      RestockStatus.draft => BadgeTone.neutral,
      RestockStatus.requested => BadgeTone.pending,
      RestockStatus.accepted => BadgeTone.info,
      RestockStatus.rejected => BadgeTone.error,
      RestockStatus.processing => BadgeTone.info,
      RestockStatus.dispatched => BadgeTone.info,
      RestockStatus.delivered => BadgeTone.success,
      RestockStatus.partiallyReceived => BadgeTone.warning,
      RestockStatus.received => BadgeTone.success,
      RestockStatus.cancelled => BadgeTone.neutral,
    };
