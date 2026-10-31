import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/product.dart';
import '../data/product_repository.dart';
import '../data/subscription_repository.dart';

/// Add/Edit product form. Stock quantities are only settable at creation
/// (initial stock) — after that, changes must go through an audited
/// inventory movement (module 4), so this form shows current numbers
/// read-only once a product exists (§3, §21).
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _brand = TextEditingController();
  final _costPrice = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _initialStock = TextEditingController(text: '0');
  final _minStockLevel = TextEditingController(text: '5');
  final _unit = TextEditingController(text: 'pc');
  final _batchNumber = TextEditingController();
  final _barcode = TextEditingController();

  bool _seeded = false;
  bool _saving = false;
  String? _imageUrl;
  DateTime? _expirationDate;

  @override
  void dispose() {
    for (final c in [_name, _description, _category, _brand, _costPrice, _sellingPrice, _initialStock, _minStockLevel, _unit, _batchNumber, _barcode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(Product product) {
    if (_seeded) return;
    _seeded = true;
    _name.text = product.name;
    _description.text = product.description;
    _category.text = product.category;
    _brand.text = product.brand;
    _costPrice.text = product.costPrice.toString();
    _sellingPrice.text = product.sellingPrice.toString();
    _minStockLevel.text = product.minStockLevel.toString();
    _unit.text = product.unit;
    _batchNumber.text = product.batchNumber ?? '';
    _barcode.text = product.barcode ?? '';
    _imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    _expirationDate = product.expirationDate;
  }

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _submit(String merchantId, String merchantName, Product? existing) async {
    if (!_formKey.currentState!.validate()) return;

    // Plan-enforced product limit (§14) — only checked on create, so a
    // merchant who exceeds their limit after a downgrade can still edit
    // existing products, just not add new ones.
    if (existing == null) {
      final plan = ref.read(effectivePlanProvider);
      final currentCount = ref.read(storeProductsProvider(merchantId)).valueOrNull?.length ?? 0;
      if (plan != null && plan.productLimit >= 0 && currentCount >= plan.productLimit) {
        showAppSnackBar(
          context,
          'Your ${plan.name} plan allows up to ${plan.productLimit} products. Upgrade to add more.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      if (existing == null) {
        await repo.createProduct(
          storeId: merchantId,
          merchantId: merchantId,
          name: _name.text.trim(),
          description: _description.text.trim(),
          category: _category.text.trim(),
          brand: _brand.text.trim(),
          imageUrls: _imageUrl != null ? [_imageUrl!] : const [],
          costPrice: double.parse(_costPrice.text.trim()),
          sellingPrice: double.parse(_sellingPrice.text.trim()),
          initialStock: int.parse(_initialStock.text.trim()),
          minStockLevel: int.parse(_minStockLevel.text.trim()),
          unit: _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim(),
          batchNumber: _batchNumber.text.trim().isEmpty ? null : _batchNumber.text.trim(),
          expirationDate: _expirationDate,
          barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
          performedByUserId: merchantId,
          performedByName: merchantName,
        );
      } else {
        await repo.updateProductDetails(existing.id, {
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'category': _category.text.trim(),
          'brand': _brand.text.trim(),
          'imageUrls': _imageUrl != null ? [_imageUrl!] : const [],
          'costPrice': double.parse(_costPrice.text.trim()),
          'sellingPrice': double.parse(_sellingPrice.text.trim()),
          'minStockLevel': int.parse(_minStockLevel.text.trim()),
          'unit': _unit.text.trim().isEmpty ? 'pc' : _unit.text.trim(),
          'batchNumber': _batchNumber.text.trim().isEmpty ? null : _batchNumber.text.trim(),
          'expirationDate': _expirationDate,
          'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        });
      }
      if (mounted) {
        showAppSnackBar(context, existing == null ? 'Product added.' : 'Product updated.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save this product. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());

    if (!widget.isEditing) {
      return _buildForm(context, user.id, user.fullName, null);
    }

    final productAsync = ref.watch(_singleProductProvider(widget.productId!));
    return productAsync.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Edit Product')), body: const LoadingListView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Product')),
        body: ErrorStateView(onRetry: () => ref.invalidate(_singleProductProvider(widget.productId!))),
      ),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Product')),
            body: const EmptyStateView(icon: Icons.error_outline_rounded, title: 'Product not found', message: 'This product may have been removed.'),
          );
        }
        return _buildForm(context, user.id, user.fullName, product);
      },
    );
  }

  Widget _buildForm(BuildContext context, String merchantId, String merchantName, Product? existing) {
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Add Product' : 'Edit Product')),
      body: SafeArea(
        child: ResponsiveFormBody(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing != null) _seedOnce(existing),
                ImagePickerField(
                  initialUrl: _imageUrl,
                  label: 'Add Product Photo',
                  storagePathBuilder: () => 'products/$merchantId/${DateTime.now().millisecondsSinceEpoch}.jpg',
                  onUploaded: (url) => setState(() => _imageUrl = url),
                ),
                const SizedBox(height: 16),
                AppTextField(controller: _name, label: 'Product Name', validator: (v) => Validators.required(v, field: 'Product name')),
                const SizedBox(height: 14),
                AppTextField(controller: _description, label: 'Description', maxLines: 3, validator: (v) => Validators.required(v, field: 'Description')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _CategoryField(controller: _category, merchantId: merchantId, onChanged: () => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _brand, label: 'Brand', validator: (v) => Validators.required(v, field: 'Brand'))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: AppTextField(controller: _costPrice, label: 'Cost Price', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.nonNegativeNumber(v, field: 'Cost price'))),
                  const SizedBox(width: 12),
                  Expanded(child: AppTextField(controller: _sellingPrice, label: 'Selling Price', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => Validators.positiveNumber(v, field: 'Selling price'))),
                ]),
                const SizedBox(height: 14),
                if (existing == null)
                  Row(children: [
                    Expanded(child: AppTextField(controller: _initialStock, label: 'Initial Stock', keyboardType: TextInputType.number, validator: (v) => Validators.nonNegativeNumber(v, field: 'Initial stock'))),
                    const SizedBox(width: 12),
                    Expanded(child: AppTextField(controller: _unit, label: 'Unit', hint: 'pc, kg, box...', validator: (v) => Validators.required(v, field: 'Unit'))),
                  ])
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current stock: ${existing.currentStock} ${existing.unit} · Available: ${existing.availableStock} · Reserved: ${existing.reservedStock}. '
                            'Adjust stock from Inventory movements, not here.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                AppTextField(controller: _minStockLevel, label: 'Minimum Stock Level', keyboardType: TextInputType.number, validator: (v) => Validators.nonNegativeNumber(v, field: 'Minimum stock level')),
                const SizedBox(height: 14),
                AppTextField(controller: _batchNumber, label: 'Batch Number (optional)'),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickExpirationDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Expiration Date (optional)'),
                    child: Text(
                      _expirationDate == null ? 'Not set' : AppFormatters.date(_expirationDate!),
                      style: TextStyle(color: _expirationDate == null ? AppColors.textDisabled : AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _barcode, label: 'Barcode (optional)'),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: existing == null ? 'Add Product' : 'Save Changes',
                  onPressed: () => _submit(merchantId, merchantName, existing),
                  loading: _saving,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _seedOnce(Product product) {
    _seed(product);
    return const SizedBox.shrink();
  }
}



class _CategoryField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String merchantId;
  final VoidCallback onChanged;
  const _CategoryField({required this.controller, required this.merchantId, required this.onChanged});

  @override
  ConsumerState<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends ConsumerState<_CategoryField> {
  Future<void> _openPicker(BuildContext context) async {
    final categories = ref.read(merchantCategoriesProvider(widget.merchantId));
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _CategoryPickerSheet(
        categories: categories,
        selected: widget.controller.text.trim(),
      ),
    );
    if (chosen != null) {
      widget.controller.text = chosen;
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => Validators.required(widget.controller.text, field: 'Category'),
      builder: (state) {
        return InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Category',
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            child: Text(
              widget.controller.text.trim().isEmpty ? 'Select category' : widget.controller.text.trim(),
              style: TextStyle(
                fontSize: 14,
                color: widget.controller.text.trim().isEmpty ? AppColors.textDisabled : AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<String> categories;
  final String selected;
  const _CategoryPickerSheet({required this.categories, required this.selected});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _search = TextEditingController();
  final _newCat = TextEditingController();
  bool _showAdd = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _newCat.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.categories;
    return widget.categories.where((c) => c.toLowerCase().contains(q)).toList();
  }

  void _addNew() {
    final value = _newCat.text.trim();
    if (value.isEmpty) return;
    // prevent duplicates case-insensitively - reuse the existing canonical form
    final existing = widget.categories.firstWhere(
      (c) => c.toLowerCase() == value.toLowerCase(),
      orElse: () => value,
    );
    Navigator.of(context).pop(existing);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('Select Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search categories',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No matching categories', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          return ListTile(
                            title: Text(c),
                            trailing: c == widget.selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                            onTap: () => Navigator.of(context).pop(c),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _showAdd
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newCat,
                              autofocus: true,
                              decoration: const InputDecoration(labelText: 'New category', isDense: true, border: OutlineInputBorder()),
                              onSubmitted: (_) => _addNew(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addNew,
                            icon: const Icon(Icons.check_rounded),
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _showAdd = false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(() => _showAdd = true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add New Category'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _singleProductProvider = StreamProvider.family<Product?, String>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchProduct(productId);
});
