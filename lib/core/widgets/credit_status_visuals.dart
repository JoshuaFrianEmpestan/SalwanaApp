import '../constants/enums.dart';
import 'status_badge.dart';

BadgeTone creditStatusTone(CreditStatus status) => switch (status) {
      CreditStatus.active => BadgeTone.info,
      CreditStatus.partiallyPaid => BadgeTone.warning,
      CreditStatus.fullyPaid => BadgeTone.success,
      CreditStatus.overdue => BadgeTone.error,
      CreditStatus.cancelled => BadgeTone.neutral,
    };
