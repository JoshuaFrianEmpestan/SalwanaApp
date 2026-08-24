import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_notification.dart';
import '../data/notification_repository.dart';
import '../notification_routing.dart';

IconData _iconFor(NotificationType type) => switch (type) {
      NotificationType.newOrder || NotificationType.orderStatusUpdate => Icons.receipt_long_outlined,
      NotificationType.reservationRequest ||
      NotificationType.reservationApproved ||
      NotificationType.reservationRejected ||
      NotificationType.reservationExpiring =>
        Icons.event_available_outlined,
      NotificationType.paymentSuccessful || NotificationType.paymentFailed => Icons.payments_outlined,
      NotificationType.deliveryStatusUpdate => Icons.local_shipping_outlined,
      NotificationType.lowStock => Icons.warning_amber_rounded,
      NotificationType.backInStock => Icons.inventory_2_outlined,
      NotificationType.restockRequest || NotificationType.supplierResponse => Icons.assignment_outlined,
      NotificationType.loanDueReminder || NotificationType.creditDueReminder => Icons.account_balance_wallet_outlined,
      NotificationType.subscriptionExpiring => Icons.workspace_premium_outlined,
      NotificationType.accountVerification => Icons.verified_user_outlined,
      NotificationType.securityAlert => Icons.shield_outlined,
      NotificationType.reviewReceived => Icons.star_border_rounded,
      NotificationType.general => Icons.notifications_outlined,
    };

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: appUser == null ? null : () => ref.read(notificationRepositoryProvider).markAllRead(appUser.id),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(myNotificationsProvider)),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const EmptyStateView(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: "You'll see updates about orders, reservations, payments, and more here.",
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () async {
                    if (!n.read) await ref.read(notificationRepositoryProvider).markRead(n.id);
                    if (appUser == null) return;
                    final link = notificationDeepLink(n, appUser.role);
                    if (link != null && context.mounted) context.push(link);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: unread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
              child: Icon(_iconFor(notification.type), size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: TextStyle(fontSize: 13, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(notification.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
                  const SizedBox(height: 6),
                  Text(AppFormatters.relative(notification.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
