import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/restock_request.dart';
import '../data/restock_repository.dart';

class ConfirmDeliveryScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ConfirmDeliveryScreen({super.key, required this.requestId});

  @override
  ConsumerState<ConfirmDeliveryScreen> createState() => _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends ConsumerState<ConfirmDeliveryScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _submitting = false;

  TextEditingController _controllerFor(RestockRequestItem item) {
    return _controllers.putIfAbsent(item.productId, () => TextEditingController(text: '${item.requestedQuantity}'));
  }

  Future<void> _submit(RestockRequest request) async {
    setState(() => _submitting = true);
    try {
      final receivedItems = request.items
          .map((i) => RestockRequestItem(
                productId: i.productId,
                productName: i.productName,
                requestedQuantity: i.requestedQuantity,
                receivedQuantity: int.tryParse(_controllers[i.productId]?.text.trim() ?? '0') ?? 0,
                estimatedUnitCost: i.estimatedUnitCost,
              ))
          .toList();
      await ref.read(restockRepositoryProvider).confirmDelivery(request.id, receivedItems);
      if (mounted) {
        showAppSnackBar(context, 'Delivery confirmed — inventory updated.');
        context.pop();
      }
    } on RestockException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not confirm delivery. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(restockRequestDetailProvider(widget.requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Delivery')),
      body: SafeArea(
        child: requestAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(restockRequestDetailProvider(widget.requestId))),
          data: (request) {
            if (request == null) {
              return const EmptyStateView(icon: Icons.local_shipping_outlined, title: 'Request not found', message: '');
            }
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Enter the quantity you actually received for each item. Inventory only increases by the amount you confirm here.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final item in request.items) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text('Requested: ${item.requestedQuantity}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: AppTextField(controller: _controllerFor(item), label: 'Received', keyboardType: TextInputType.number),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(top: false, child: PrimaryButton(label: 'Confirm Delivery', onPressed: () => _submit(request), loading: _submitting)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
