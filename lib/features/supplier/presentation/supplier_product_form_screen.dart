import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/supplier.dart';
import '../data/supplier_product_repository.dart';

class SupplierProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const SupplierProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  ConsumerState<SupplierProductFormScreen> createState() => _SupplierProductFormScreenState();
}

class _SupplierProductFormScreenState extends ConsumerState<SupplierProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _unitCost = TextEditingController();
  final _unit = TextEditingController(text: 'pc');
  final _minOrderQuantity = TextEditingController(text: '1');
  bool _seeded = false;
  bool _saving = false;

  void _seed(SupplierProduct p) {
    if (_seeded) return;
    _seeded = true;
    _name.text = p.name;
    _description.text = p.description;
    _category.text = p.category;
    _unitCost.text = p.unitCost.toString();
    _unit.text = p.unit;
    _minOrderQuantity.text = p.minOrderQuantity.toString();
  }

  Future<void> _submit(String supplierId, SupplierProduct? existing) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierProductRepositoryProvider);
      if (existing == null) {
        await repo.create(
          supplierId: supplierId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: _category.text.trim(),
          unitCost: double.parse(_unitCost.text.trim()),
          unit: _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim(),
          minOrderQuantity: int.parse(_minOrderQuantity.text.trim()),
        );
      } else {
        await repo.update(existing.id, {
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'category': _category.text.trim(),
          'unitCost': double.parse(_unitCost.text.trim()),
          'unit': _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim(),
          'minOrderQuantity': int.parse(_minOrderQuantity.text.trim()),
        });
      }
      if (mounted) {
        showAppSnackBar(context, existing == null ? 'Product added.' : 'Product updated.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save this product.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());

    if (!widget.isEditing) return _buildForm(context, user.id, null);

    final productAsync = ref.watch(_productProvider(widget.productId!));
    return productAsync.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Edit Supply')), body: const LoadingListView()),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Edit Supply')), body: ErrorStateView(onRetry: () => ref.invalidate(_productProvider(widget.productId!)))),
      data: (product) {
        if (product == null) {
          return Scaffold(appBar: AppBar(title: const Text('Edit Supply')), body: const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Not found', message: ''));
        }
        return _buildForm(context, user.id, product);
      },
    );
  }

  Widget _buildForm(BuildContext context, String supplierId, SupplierProduct? existing) {
    if (existing != null) _seed(existing);
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Add Supply' : 'Edit Supply')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(controller: _name, label: 'Item Name', validator: (v) => Validators.required(v, field: 'Item name')),
                const SizedBox(height: 14),
                AppTextField(controller: _description, label: 'Description', maxLines: 3, validator: (v) => Validators.required(v, field: 'Description')),
                const SizedBox(height: 14),
                AppTextField(controller: _category, label: 'Category', validator: (v) => Validators.required(v, field: 'Category')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: AppTextField(controller: _unitCost, label: 'Unit Cost', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Unit cost'))),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _unit, label: 'Unit', hint: 'pc, kg, box...', validator: (v) => Validators.required(v, field: 'Unit'))),
                ]),
                const SizedBox(height: 14),
                AppTextField(controller: _minOrderQuantity, label: 'Minimum Order Quantity', keyboardType: TextInputType.number, validator: (v) => Validators.positiveNumber(v, field: 'Minimum order quantity')),
                const SizedBox(height: 24),
                PrimaryButton(label: existing == null ? 'Add Supply' : 'Save Changes', onPressed: () => _submit(supplierId, existing), loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _productProvider = StreamProvider.family((ref, String id) {
  return ref.watch(supplierProductRepositoryProvider).watchProduct(id);
});
