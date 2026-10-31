import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/restock_request.dart';
import '../../../models/supplier.dart';
import '../../supplier/data/supplier_product_repository.dart';
import '../data/restock_repository.dart';

class RestockRequestFormScreen extends ConsumerStatefulWidget {
  final String supplierId;
  const RestockRequestFormScreen({super.key, required this.supplierId});

  @override
  ConsumerState<RestockRequestFormScreen> createState() => _RestockRequestFormScreenState();
}

class _RestockRequestFormScreenState extends ConsumerState<RestockRequestFormScreen> {
  final Map<String, SupplierProduct> _selected = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _costControllers = {};
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    for (final c in _costControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(SupplierProduct p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
        _quantityControllers.remove(p.id)?.dispose();
        _costControllers.remove(p.id)?.dispose();
      } else {
        _selected[p.id] = p;
        _quantityControllers[p.id] = TextEditingController(text: '${p.minOrderQuantity > 0 ? p.minOrderQuantity : 1}');
        _costControllers[p.id] = TextEditingController(text: p.unitCost.toString());
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      showAppSnackBar(context, 'Select at least one product.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final items = _selected.values.map((p) {
        final qty = int.tryParse(_quantityControllers[p.id]!.text.trim()) ?? 0;
        final cost = double.tryParse(_costControllers[p.id]!.text.trim()) ?? p.unitCost;
        if (qty < p.minOrderQuantity) {
          throw Exception('${p.name}: minimum order quantity is ${p.minOrderQuantity}.');
        }
        return RestockRequestItem(productId: p.id, productName: p.name, requestedQuantity: qty, estimatedUnitCost: cost);
      }).toList();

      if (items.any((i) => i.requestedQuantity <= 0)) {
        showAppSnackBar(context, 'Enter a valid quantity for every selected product.', isError: true);
        setState(() => _submitting = false);
        return;
      }

      await ref.read(restockRepositoryProvider).createRequest(
            supplierId: widget.supplierId,
            items: items,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) {
        showAppSnackBar(context, 'Restocking request sent.');
        context.pop();
      }
    } on RestockException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double get _total {
    double sum = 0;
    for (final p in _selected.values) {
      final qty = int.tryParse(_quantityControllers[p.id]?.text ?? '0') ?? 0;
      final cost = double.tryParse(_costControllers[p.id]?.text ?? '') ?? p.unitCost;
      sum += cost * qty;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());

    final productsAsync = ref.watch(supplierCatalogProvider(widget.supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('New Restocking Request')),
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(supplierCatalogProvider(widget.supplierId))),
          data: (products) {
            if (products.isEmpty) {
              return const EmptyStateView(icon: Icons.inventory_2_outlined, title: 'No products available', message: 'This supplier has no products in their catalog.');
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Select products to restock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      for (final p in products) ...[
                        _ProductPickerTile(
                          product: p,
                          selected: _selected.containsKey(p.id),
                          onToggle: () => _toggle(p),
                          quantityController: _quantityControllers[p.id],
                          costController: _costControllers[p.id],
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selected.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                                Text(AppFormatters.currency(_total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        PrimaryButton(label: 'Send Request (${_selected.length})', onPressed: _submit, loading: _submitting),
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

class _ProductPickerTile extends StatelessWidget {
  final SupplierProduct product;
  final bool selected;
  final VoidCallback onToggle;
  final TextEditingController? quantityController;
  final TextEditingController? costController;

  const _ProductPickerTile({required this.product, required this.selected, required this.onToggle, this.quantityController, this.costController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.primary,
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${product.category} · ${AppFormatters.currency(product.unitCost)}/${product.unit} · Min order: ${product.minOrderQuantity}', style: const TextStyle(fontSize: 11)),
            onTap: onToggle,
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(controller: quantityController!, label: 'Quantity', keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(controller: costController!, label: 'Est. Unit Cost', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
