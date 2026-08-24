import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/cart_item.dart';
import '../data/cart_repository.dart';
import '../data/checkout_repository.dart';

class _GroupConfig {
  FulfillmentType fulfillmentType = FulfillmentType.pickup;
  PaymentMethod paymentMethod = PaymentMethod.cashOnDelivery;
  final TextEditingController address = TextEditingController();
  final TextEditingController notes = TextEditingController();
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final Map<String, _GroupConfig> _configs = {};
  bool _placing = false;

  _GroupConfig _configFor(String storeId) => _configs.putIfAbsent(storeId, () => _GroupConfig());

  @override
  void dispose() {
    for (final c in _configs.values) {
      c.address.dispose();
      c.notes.dispose();
    }
    super.dispose();
  }

  Future<void> _placeOrder(Map<String, List<CartItem>> byStore) async {
    for (final entry in byStore.entries) {
      final config = _configFor(entry.key);
      if (config.fulfillmentType == FulfillmentType.delivery && config.address.text.trim().isEmpty) {
        showAppSnackBar(context, 'Enter a delivery address for ${entry.value.first.storeName}.', isError: true);
        return;
      }
    }

    setState(() => _placing = true);
    try {
      final groups = byStore.entries.map((entry) {
        final config = _configFor(entry.key);
        return CheckoutGroup(
          storeId: entry.key,
          fulfillmentType: config.fulfillmentType,
          deliveryAddressText: config.fulfillmentType == FulfillmentType.delivery ? config.address.text.trim() : null,
          notes: config.notes.text.trim().isEmpty ? null : config.notes.text.trim(),
          paymentMethod: config.paymentMethod,
          items: entry.value,
        );
      }).toList();

      final orderIds = await ref.read(checkoutRepositoryProvider).checkout(groups);
      if (mounted) {
        context.pushReplacement('/consumer/checkout-result', extra: orderIds);
      }
    } on CheckoutException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Checkout failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: cartAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(cartItemsProvider)),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyStateView(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', message: 'Add products before checking out.');
            }
            final byStore = <String, List<CartItem>>{};
            for (final item in items) {
              byStore.putIfAbsent(item.storeId, () => []).add(item);
            }
            final grandTotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in byStore.entries) ...[
                        _StoreCheckoutCard(storeId: entry.key, items: entry.value, config: _configFor(entry.key), onChanged: () => setState(() {})),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Total', style: TextStyle(color: AppColors.textSecondary)),
                            Text(AppFormatters.currency(grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Final total (with delivery/platform fees) is confirmed after you place the order.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        PrimaryButton(label: 'Place Order', onPressed: () => _placeOrder(byStore), loading: _placing),
                      ],
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

class _StoreCheckoutCard extends StatelessWidget {
  final String storeId;
  final List<CartItem> items;
  final _GroupConfig config;
  final VoidCallback onChanged;

  const _StoreCheckoutCard({required this.storeId, required this.items, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(items.first.storeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text('${item.quantity}x ${item.productName}', style: const TextStyle(fontSize: 12))),
                  Text(AppFormatters.currency(item.subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Divider(height: 20),
          const Text('Fulfillment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: 'Pickup',
                  selected: config.fulfillmentType == FulfillmentType.pickup,
                  onTap: () {
                    config.fulfillmentType = FulfillmentType.pickup;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                  label: 'Delivery',
                  selected: config.fulfillmentType == FulfillmentType.delivery,
                  onTap: () {
                    config.fulfillmentType = FulfillmentType.delivery;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (config.fulfillmentType == FulfillmentType.delivery) ...[
            const SizedBox(height: 10),
            TextField(
              controller: config.address,
              decoration: const InputDecoration(labelText: 'Delivery Address', isDense: true),
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 14),
          const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in PaymentMethod.values)
                _ChoiceButton(
                  label: method.label,
                  selected: config.paymentMethod == method,
                  onTap: () {
                    config.paymentMethod = method;
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: config.notes,
            decoration: const InputDecoration(labelText: 'Order Notes (optional)', isDense: true),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(AppFormatters.currency(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
        ),
      ),
    );
  }
}
