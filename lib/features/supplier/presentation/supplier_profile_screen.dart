import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/account_header_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/profile_menu_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';

class SupplierProfileScreen extends ConsumerWidget {
  const SupplierProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out of Salwana?',
      confirmLabel: 'Log Out',
      destructive: true,
    );
    if (confirmed) await ref.read(authRepositoryProvider).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const LoadingListView(itemCount: 4),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(appUserProvider)),
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AccountHeaderCard(user: user, subtitle: user.email),
                const SizedBox(height: 20),
                const Text('Business', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                 ProfileMenuTile(icon: Icons.business_outlined, label: 'Company Profile', onTap: () => context.push('/supplier/company')),
                 ProfileMenuTile(icon: Icons.receipt_long_outlined, label: 'Payment History', onTap: () => context.go('/supplier/transactions')),
                const SizedBox(height: 12),
                const Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ProfileMenuTile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () => context.push('/supplier/profile/edit')),
                ProfileMenuTile(icon: Icons.notifications_outlined, label: 'Notification Settings', onTap: () => context.push('/supplier/notification-settings')),
                ProfileMenuTile(icon: Icons.lock_outline_rounded, label: 'Security', onTap: () => context.push('/supplier/security')),
                const SizedBox(height: 12),
                ProfileMenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  iconColor: AppColors.error,
                  labelColor: AppColors.error,
                  onTap: () => _logout(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
