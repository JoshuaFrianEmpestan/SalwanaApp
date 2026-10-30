import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/product.dart';
import '../../merchant/data/product_repository.dart';
import '../data/reservation_repository.dart';

class ReserveProductScreen extends ConsumerStatefulWidget {
  final String productId;
  final int initialQuantity;
  const ReserveProductScreen({super.key, required this.productId, this.initialQuantity = 1});

  @override
  ConsumerState<ReserveProductScreen> createState() => _ReserveProductScreenState();
}

class _ReserveProductScreenState extends ConsumerState<ReserveProductScreen> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(1, 1 << 30);
  }
  FulfillmentType _fulfillmentType = FulfillmentType.pickup;
  DateTime? _scheduledFor;
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit(Product product) async {
    if (_scheduledFor == null) {
      showAppSnackBar(context, 'Choose a reservation date and time.', isError: true);
      return;
    }
    if (_fulfillmentType == FulfillmentType.delivery && _address.text.trim().isEmpty) {
      showAppSnackBar(context, 'Enter a delivery address.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(reservationRepositoryProvider).createReservation(
            productId: product.id,
            quantity: _quantity,
            fulfillmentType: _fulfillmentType,
            scheduledFor: _scheduledFor!,
            deliveryAddressText: _fulfillmentType == FulfillmentType.delivery ? _address.text.trim() : null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) {
        showAppSnackBar(context, 'Reservation requested.');
        context.go('/consumer/orders');
      }
    } on ReservationException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not create reservation. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reserve Product')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_productProvider(widget.productId))),
          data: (product) {
            if (product == null) {
              return const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Product not found', message: '');
            }
            if (product.availableStock <= 0) {
              return const EmptyStateView(icon: Icons.inventory_2_outlined, title: 'Out of stock', message: 'This product has no available stock to reserve right now.');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${AppFormatters.currency(product.sellingPrice)} · ${product.availableStock} ${product.unit} available',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 24),
                  const Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        tooltip: 'Decrease quantity',
                      ),
                      Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      IconButton(
                        onPressed: _quantity < product.availableStock ? () => setState(() => _quantity++) : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: 'Increase quantity',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Fulfillment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Pickup'),
                          selected: _fulfillmentType == FulfillmentType.pickup,
                          onSelected: (_) => setState(() => _fulfillmentType = FulfillmentType.pickup),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Delivery'),
                          selected: _fulfillmentType == FulfillmentType.delivery,
                          onSelected: (_) => setState(() => _fulfillmentType = FulfillmentType.delivery),
                        ),
                      ),
                    ],
                  ),
                  if (_fulfillmentType == FulfillmentType.delivery) ...[
                    const SizedBox(height: 14),
                    TextField(controller: _address, decoration: const InputDecoration(labelText: 'Delivery Address'), maxLines: 2),
                  ],
                  const SizedBox(height: 16),
                  const Text('Pickup / Delivery Date & Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      child: Text(_scheduledFor == null ? 'Select date & time' : AppFormatters.dateTime(_scheduledFor!)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Confirm Reservation', onPressed: () => _submit(product), loading: _submitting),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final _productProvider = StreamProvider.family((ref, String productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});
