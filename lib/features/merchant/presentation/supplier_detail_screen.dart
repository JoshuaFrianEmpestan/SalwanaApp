import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../supplier/data/supplier_product_repository.dart' show supplierCatalogProvider;
import '../data/restock_repository.dart';

class SupplierDetailScreen extends ConsumerWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierProfileByIdProvider(supplierId));
    final catalogAsync = ref.watch(supplierCatalogProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier')),
      body: SafeArea(
        child: supplierAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(supplierProfileByIdProvider(supplierId))),
          data: (supplier) {
            if (supplier == null) {
              return const EmptyStateView(icon: Icons.local_shipping_outlined, title: 'Supplier not found', message: '');
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(supplier.companyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(supplier.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.call_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(supplier.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Catalog', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      catalogAsync.when(
                        loading: () => const LoadingSpinner(),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (items) {
                          if (items.isEmpty) {
                            return const EmptyStateView(
                              icon: Icons.inventory_outlined,
                              title: 'No supplies listed',
                              message: 'This supplier has not listed any items yet — you can still send a restocking request.',
                            );
                          }
                          return Column(
                            children: [
                              for (final item in items)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                            Text('${item.category} · min. ${item.minOrderQuantity} ${item.unit}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(AppFormatters.currency(item.unitCost), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: PrimaryButton(
                      label: 'Create Restocking Request',
                      onPressed: () => context.push('/merchant/suppliers/$supplierId/request'),
                    ),
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
