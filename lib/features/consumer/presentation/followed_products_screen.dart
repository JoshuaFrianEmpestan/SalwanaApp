import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../data/followed_product_repository.dart';

class FollowedProductsScreen extends ConsumerWidget {
  const FollowedProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followsAsync = ref.watch(myFollowedProductsProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Followed Products')),
      body: SafeArea(
        child: followsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(myFollowedProductsProvider)),
          data: (follows) {
            if (follows.isEmpty) {
              return const EmptyStateView(
                icon: Icons.favorite_border_rounded,
                title: 'Not following any products',
                message: 'When an out-of-stock product interests you, tap "Notify Me When Back in Stock" to follow it here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: follows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final f = follows[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.productName ?? f.storeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(f.storeName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (f.productId != null)
                        TextButton(
                          onPressed: () => context.push('/consumer/products/${f.productId}'),
                          child: const Text('View'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                        onPressed: () async {
                          if (user == null || f.productId == null) return;
                          final confirmed = await showConfirmDialog(context, title: 'Unfollow', message: 'Stop watching this product for restock?', confirmLabel: 'Unfollow', destructive: true);
                          if (confirmed) await ref.read(followedProductRepositoryProvider).unfollow(user.id, f.productId!);
                        },
                      ),
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
