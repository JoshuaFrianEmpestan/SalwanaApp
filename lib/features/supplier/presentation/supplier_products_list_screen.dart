import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/supplier_product_repository.dart';

class SupplierProductsListScreen extends ConsumerWidget {
  const SupplierProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(mySupplierProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Supplies')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/supplier/products/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Supply'),
      ),
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(mySupplierProductsProvider)),
          data: (products) {
            if (products.isEmpty) {
              return EmptyStateView(
                icon: Icons.inventory_outlined,
                title: 'No supplies listed yet',
                message: 'Add the items you offer so merchants can find you.',
                actionLabel: 'Add Supply',
                onAction: () => context.push('/supplier/products/new'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = products[i];
                return InkWell(
                  onTap: () => context.push('/supplier/products/${p.id}/edit'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text('${p.category} · min. order ${p.minOrderQuantity} ${p.unit}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(AppFormatters.currency(p.unitCost), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(label: p.isAvailable ? 'Available' : 'Unavailable', tone: p.isAvailable ? BadgeTone.success : BadgeTone.neutral),
                            const SizedBox(height: 8),
                            Switch(
                              value: p.isAvailable,
                              onChanged: (v) => ref.read(supplierProductRepositoryProvider).setAvailability(p.id, v),
                            ),
                          ],
                        ),
                      ],
                    ),
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
