import '../../core/constants/enums.dart';
import '../../models/app_notification.dart';

/// Where selecting a notification should navigate (§12, §17 "selecting an
/// order notification opens the order details"). Returns null when there's
/// no specific destination — the notification just gets marked read.
String? notificationDeepLink(AppNotification n, UserRole viewerRole) {
  final id = n.relatedRecordId;
  if (id == null) return null;

  switch (n.relatedRecordType) {
    case 'order':
      return viewerRole == UserRole.merchant ? '/merchant/order-details/$id' : '/consumer/order-details/$id';
    case 'reservation':
      return viewerRole == UserRole.merchant ? '/merchant/reservations/$id' : '/consumer/reservations/$id';
    case 'product':
      return viewerRole == UserRole.merchant ? '/merchant/products/$id' : '/consumer/products/$id';
    case 'restock_request':
      return viewerRole == UserRole.supplier ? '/supplier/requests/$id' : '/merchant/restock-requests/$id';
    case 'store_review':
      return viewerRole == UserRole.merchant ? '/merchant/reviews' : null;
    case 'user':
      // Account verification / suspension notices — route to the
      // recipient's own profile so they can see their current status.
      return switch (viewerRole) {
        UserRole.merchant => '/merchant/profile',
        UserRole.supplier => '/supplier/profile',
        UserRole.admin => '/admin/settings',
        UserRole.consumer => '/consumer/profile',
      };
    case 'subscription':
      return viewerRole == UserRole.merchant ? '/merchant/subscription' : null;
    default:
      return null;
  }
}
