import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/review_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/review_repository.dart';

class StoreReviewsScreen extends ConsumerWidget {
  final String storeId;
  const StoreReviewsScreen({super.key, required this.storeId});

  Future<void> _report(BuildContext context, WidgetRef ref, String reviewId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Review'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Why are you reporting this review?'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Report')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(reviewRepositoryProvider).report(reviewId: reviewId, reason: reason);
      if (context.mounted) showAppSnackBar(context, 'Review reported for moderation.');
    } on ReviewException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String reviewId) async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respond to Review'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Your response'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Post Response')),
        ],
      ),
    );
    if (response == null || response.isEmpty) return;
    try {
      await ref.read(reviewRepositoryProvider).respond(reviewId: reviewId, response: response);
      if (context.mounted) showAppSnackBar(context, 'Response posted.');
    } on ReviewException catch (e) {
      if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(storeReviewsProvider(storeId));
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Store Reviews')),
      body: SafeArea(
        child: reviewsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(storeReviewsProvider(storeId))),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const EmptyStateView(
                icon: Icons.star_border_rounded,
                title: 'No reviews yet',
                message: 'Reviews from consumers with a completed order will appear here.',
              );
            }
            final avg = reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
            final distribution = <int, int>{for (var i = 5; i >= 1; i--) i: 0};
            for (final r in reviews) {
              distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                          StarRow(rating: avg.round()),
                          const SizedBox(height: 4),
                          Text('${reviews.length} reviews', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            for (final star in [5, 4, 3, 2, 1])
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Text('$star', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: reviews.isEmpty ? 0 : (distribution[star] ?? 0) / reviews.length,
                                          backgroundColor: AppColors.neutralBg,
                                          color: AppColors.warning,
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final review in reviews) ...[
                  ReviewTile(
                    review: review,
                    isAuthor: appUser?.id == review.consumerId,
                    isStoreOwner: appUser?.role == UserRole.merchant && appUser?.id == storeId,
                    onEdit: appUser?.id == review.consumerId ? () => context.push('/consumer/orders/${review.orderId}/review') : null,
                    onRespond: appUser?.role == UserRole.merchant ? () => _respond(context, ref, review.id) : null,
                    onReport: appUser != null ? () => _report(context, ref, review.id) : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
