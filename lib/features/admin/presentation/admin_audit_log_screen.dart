import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';

class AdminAuditLogScreen extends ConsumerWidget {
  const AdminAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: SafeArea(
        child: logsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(auditLogsProvider)),
          data: (logs) {
            if (logs.isEmpty) {
              return const EmptyStateView(
                icon: Icons.fact_check_outlined,
                title: 'No activity yet',
                message: 'Administrative actions — verifications, suspensions, moderation — are recorded here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final l = logs[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('${l.actorName} (${l.actorRole}) · ${l.targetType} ${l.targetId}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(l.reason, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(AppFormatters.dateTime(l.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textDisabled)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
