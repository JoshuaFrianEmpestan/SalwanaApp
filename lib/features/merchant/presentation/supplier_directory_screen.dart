import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/restock_request_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../data/restock_repository.dart';

class SupplierDirectoryScreen extends StatelessWidget {
  const SupplierDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suppliers'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Browse'), Tab(text: 'My Requests')],
          ),
        ),
        body: const TabBarView(children: [_BrowseSuppliers(), _MyRequests()]),
      ),
    );
  }
}

class _BrowseSuppliers extends ConsumerWidget {
  const _BrowseSuppliers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(activeSuppliersProvider);
    return SafeArea(
      child: suppliersAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(activeSuppliersProvider)),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const EmptyStateView(
              icon: Icons.local_shipping_outlined,
              title: 'No suppliers yet',
              message: 'Verified suppliers will appear here once they join Salwana.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = suppliers[i];
              return InkWell(
                onTap: () => context.push('/merchant/suppliers/${s.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                        child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.companyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(
                              s.suppliedCategories.isEmpty ? s.address : s.suppliedCategories.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MyRequests extends ConsumerWidget {
  const _MyRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(merchantRestockRequestsProvider);
    return SafeArea(
      child: requestsAsync.when(
        loading: () => const LoadingListView(),
        error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(merchantRestockRequestsProvider)),
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyStateView(
              icon: Icons.assignment_outlined,
              title: 'No restocking requests yet',
              message: 'Requests you send to suppliers will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => RestockRequestTile(
              request: requests[i],
              showSupplierName: true,
              onTap: () => context.push('/merchant/restock-requests/${requests[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
