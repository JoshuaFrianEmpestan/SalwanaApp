import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/restock_request_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../merchant/data/restock_repository.dart';

class SupplierRequestsListScreen extends ConsumerWidget {
  const SupplierRequestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierRestockRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      body: SafeArea(
        child: requestsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(supplierRestockRequestsProvider)),
          data: (requests) {
            if (requests.isEmpty) {
              return const EmptyStateView(
                icon: Icons.assignment_outlined,
                title: 'No requests yet',
                message: 'Restocking requests from merchants will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => RestockRequestTile(
                request: requests[i],
                onTap: () => context.push('/supplier/requests/${requests[i].id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
