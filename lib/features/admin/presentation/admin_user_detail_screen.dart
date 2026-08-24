import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _acting = false;

  Future<String?> _askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason (required)'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      if (mounted) showAppSnackBar(context, 'Account updated.');
    } on AdminActionException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not update this account.', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _verify(bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason('Reject Account');
      if (reason == null || reason.isEmpty) return;
    } else {
      final confirmed = await showConfirmDialog(context, title: 'Approve Account', message: 'Verify this account and grant full access?', confirmLabel: 'Approve');
      if (!confirmed) return;
    }
    final user = ref.read(userByIdProvider(widget.userId)).valueOrNull;
    if (user == null) return;
    await _act(() => ref.read(adminRepositoryProvider).verifyAccount(targetUserId: user.id, targetType: user.role.name, approve: approve, reason: reason));
  }

  Future<void> _setStatus(String status) async {
    final reason = await _askReason('${status[0].toUpperCase()}${status.substring(1)} Account');
    if (reason == null || reason.isEmpty) return;
    await _act(() => ref.read(adminRepositoryProvider).setAccountStatus(targetUserId: widget.userId, status: status, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userByIdProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(userByIdProvider(widget.userId))),
          data: (user) {
            if (user == null) return const EmptyStateView(icon: Icons.person_off_outlined, title: 'Account not found', message: '');

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    StatusBadge(label: user.status.label, tone: _tone(user.status)),
                  ],
                ),
                const SizedBox(height: 12),
                _row('Role', user.role.label),
                _row('Email', user.email),
                if (user.phone != null) _row('Phone', user.phone!),
                _row('Email Verified', user.emailVerified ? 'Yes' : 'No'),
                _row('Joined', AppFormatters.dateTime(user.createdAt)),
                if (user.statusReason?.isNotEmpty == true) _row('Status Reason', user.statusReason!),
                const SizedBox(height: 24),
                if (user.status == AccountStatus.pendingVerification && (user.role == UserRole.merchant || user.role == UserRole.supplier)) ...[
                  PrimaryButton(label: 'Approve', onPressed: () => _verify(true), loading: _acting),
                  const SizedBox(height: 10),
                  PrimaryButton(label: 'Reject', outlined: true, onPressed: () => _verify(false), loading: _acting),
                ] else ...[
                  if (user.status != AccountStatus.suspended)
                    PrimaryButton(label: 'Suspend Account', outlined: true, onPressed: () => _setStatus('suspended'), loading: _acting),
                  if (user.status == AccountStatus.suspended || user.status == AccountStatus.deactivated) ...[
                    const SizedBox(height: 10),
                    PrimaryButton(label: 'Reactivate Account', onPressed: () => _setStatus('active'), loading: _acting),
                  ],
                  if (user.status != AccountStatus.deactivated) ...[
                    const SizedBox(height: 10),
                    PrimaryButton(label: 'Deactivate Account', outlined: true, onPressed: () => _setStatus('deactivated'), loading: _acting),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  BadgeTone _tone(AccountStatus s) => switch (s) {
        AccountStatus.active => BadgeTone.success,
        AccountStatus.pendingVerification => BadgeTone.warning,
        AccountStatus.suspended || AccountStatus.rejected => BadgeTone.error,
        AccountStatus.deactivated => BadgeTone.neutral,
      };

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
