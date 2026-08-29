import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../data/profile_repository.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(appUserProvider)),
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: SwitchListTile(
                    value: user.notificationsEnabled,
                    onChanged: (v) => ref.read(profileRepositoryProvider).setNotificationsEnabled(user.id, v),
                    title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Orders, reservations, payments, restocking, and account alerts.', style: TextStyle(fontSize: 12)),
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'When enabled, you\'ll still see everything in your in-app Notification Center — this only controls whether new activity notifies you.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
