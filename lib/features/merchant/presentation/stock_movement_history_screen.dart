import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/inventory_movement.dart';
import '../data/inventory_repository.dart';
import '../data/product_repository.dart';

(IconData, Color) _movementVisual(MovementType type) => switch (type) {
      MovementType.stockIn => (Icons.add_circle_outline_rounded, AppColors.success),
      MovementType.supplierDelivery => (Icons.local_shipping_outlined, AppColors.success),
      MovementType.returned => (Icons.undo_rounded, AppColors.success),
      MovementType.reservationReleased => (Icons.lock_open_rounded, AppColors.info),
      MovementType.sale => (Icons.point_of_sale_outlined, AppColors.textSecondary),
      MovementType.reservation => (Icons.lock_outline_rounded, AppColors.pending),
      MovementType.damage => (Icons.broken_image_outlined, AppColors.error),
      MovementType.expired => (Icons.event_busy_outlined, AppColors.error),
      MovementType.manualAdjustment => (Icons.tune_rounded, AppColors.warning),
    };

class StockMovementHistoryScreen extends ConsumerWidget {
  final String productId;
  const StockMovementHistoryScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productNameProvider(productId));
    final movementsAsync = ref.watch(productMovementsProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: Text(productAsync.valueOrNull?.let((p) => p.name) ?? 'Stock Movements'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/merchant/products/$productId/adjust-stock'),
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Adjust Stock'),
      ),
      body: SafeArea(
        child: movementsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(productMovementsProvider(productId))),
          data: (movements) {
            if (movements.isEmpty) {
              return const EmptyStateView(
                icon: Icons.swap_vert_rounded,
                title: 'No stock movements yet',
                message: 'Stock-ins, sales, reservations, and adjustments for this product will show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: movements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _MovementTile(movement: movements[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final InventoryMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _movementVisual(movement.type);
    final isPositive = movement.quantityChanged >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(movement.type.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    Text(
                      '${isPositive ? '+' : ''}${movement.quantityChanged}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(movement.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(
                  '${movement.quantityBefore} → ${movement.quantityAfter} · by ${movement.performedByName} · ${AppFormatters.relative(movement.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

final _productNameProvider = StreamProvider.family((ref, String productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});
