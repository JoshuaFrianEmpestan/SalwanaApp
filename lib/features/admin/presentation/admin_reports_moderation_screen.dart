import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/review_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';

class AdminReportsModerationScreen extends ConsumerWidget {
  const AdminReportsModerationScreen({super.key});

  Future<void> _moderate(BuildContext context, WidgetRef ref, String reviewId, bool hide) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hide ? 'Hide Review' : 'Unhide Review'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(hide ? 'Hide' : 'Unhide')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(adminRepositoryProvider).moderateReview(reviewId: reviewId, hidden: hide, reason: reason);
      if (context.mounted) showAppSnackBar(context, hide ? 'Review hidden.' : 'Review restored.');
    } on AdminActionException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reportedReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reported Reviews')),
      body: SafeArea(
        child: reviewsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(reportedReviewsProvider)),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const EmptyStateView(icon: Icons.flag_outlined, title: 'No reported reviews', message: 'Reviews flagged by consumers or merchants will appear here.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = reviews[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReviewTile(review: r),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(8)),
                      child: Text('Reported: ${r.reportReason ?? 'No reason given'}', style: const TextStyle(fontSize: 11, color: AppColors.error)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(r.hidden ? 'Currently hidden' : 'Currently visible', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _moderate(context, ref, r.id, !r.hidden),
                          child: Text(r.hidden ? 'Unhide' : 'Hide', style: TextStyle(color: r.hidden ? AppColors.success : AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
