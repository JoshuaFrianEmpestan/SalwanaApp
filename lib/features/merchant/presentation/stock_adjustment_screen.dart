import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/product.dart';
import '../data/inventory_repository.dart';
import '../data/product_repository.dart';

const _adjustmentTypes = [
  MovementType.stockIn,
  MovementType.returned,
  MovementType.damage,
  MovementType.expired,
  MovementType.manualAdjustment,
];

String _typeHint(MovementType type) => switch (type) {
      MovementType.stockIn => 'Newly received stock not tied to a supplier delivery record.',
      MovementType.returned => 'A customer returned this product and it was restocked.',
      MovementType.damage => 'Stock removed because it was damaged.',
      MovementType.expired => 'Stock removed because it expired.',
      MovementType.manualAdjustment => 'Correct the stock count after a physical inventory count.',
      _ => '',
    };

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final String productId;
  const StockAdjustmentScreen({super.key, required this.productId});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  MovementType _type = MovementType.stockIn;
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(Product product) async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final qty = int.parse(_quantity.text.trim());

      if (_type == MovementType.manualAdjustment) {
        await repo.setStockCount(
          productId: product.id,
          storeId: product.storeId,
          newCount: qty,
          reason: _reason.text.trim(),
          performedByUserId: user.id,
          performedByName: user.fullName,
        );
      } else {
        await repo.recordAdjustment(
          productId: product.id,
          storeId: product.storeId,
          type: _type,
          quantity: qty,
          reason: _reason.text.trim(),
          performedByUserId: user.id,
          performedByName: user.fullName,
        );
      }
      if (mounted) {
        showAppSnackBar(context, 'Stock updated.');
        context.pop();
      }
    } on InsufficientStockException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not update stock. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(_productProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Stock')),
      body: SafeArea(
        child: productAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(_productProvider(widget.productId))),
          data: (product) {
            if (product == null) {
              return const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Product not found', message: '');
            }
            final isManual = _type == MovementType.manualAdjustment;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('Current stock: ${product.currentStock} ${product.unit}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Movement Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _adjustmentTypes)
                          ChoiceChip(
                            label: Text(t.label),
                            selected: _type == t,
                            onSelected: (_) => setState(() => _type = t),
                            selectedColor: AppColors.primarySurface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _type == t ? AppColors.primary : AppColors.textSecondary,
                            ),
                            side: BorderSide(color: _type == t ? AppColors.primary : AppColors.border),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_typeHint(_type), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _quantity,
                      label: isManual ? 'New Stock Count' : 'Quantity',
                      keyboardType: TextInputType.number,
                      validator: (v) => isManual
                          ? Validators.nonNegativeNumber(v, field: 'New stock count')
                          : Validators.positiveNumber(v, field: 'Quantity'),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _reason,
                      label: 'Reason',
                      maxLines: 2,
                      validator: (v) => Validators.required(v, field: 'Reason'),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Save', onPressed: () => _submit(product), loading: _saving),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final _productProvider = StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});
