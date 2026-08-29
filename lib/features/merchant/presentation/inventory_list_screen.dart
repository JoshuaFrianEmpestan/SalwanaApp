import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/product_list_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/product.dart';
import '../data/product_repository.dart';
import '../data/store_repository.dart';
import 'barcode_scanner_screen.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyFilters(List<Product> products) {
    return products.where((p) {
      if (_search.isNotEmpty && !p.name.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_statusFilter != 'all' && p.status.name != _statusFilter) return false;
      if (_categoryFilter != 'all' && p.category != _categoryFilter) return false;
      return true;
    }).toList();
  }

  Future<void> _scanToFind(String merchantId) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(title: 'Scan to Find Product')),
    );
    if (code == null || !mounted) return;

    final products = ref.read(storeProductsProvider(merchantId)).valueOrNull ?? const [];
    final matches = products.where((p) => p.barcode == code).toList();
    final match = matches.isNotEmpty ? matches.first : null;
    if (match != null) {
      if (mounted) context.push('/merchant/products/${match.id}');
    } else if (mounted) {
      showAppSnackBar(context, 'No product found with that code.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: LoadingSpinner());

    final productsAsync = ref.watch(storeProductsProvider(user.id));
    final store = ref.watch(myStoreProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (store?.barcodeEnabled ?? false)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan to find product',
              onPressed: () => _scanToFind(user.id),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/merchant/products/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(storeProductsProvider(user.id))),
          data: (allProducts) {
            if (allProducts.isEmpty) {
              return EmptyStateView(
                icon: Icons.inventory_2_outlined,
                title: 'No products yet',
                message: 'Add your first product to start tracking inventory and sales.',
                actionLabel: 'Add Product',
                onAction: () => context.push('/merchant/products/new'),
              );
            }

            final categories = {'all', ...allProducts.map((p) => p.category)}.toList();
            final filtered = _applyFilters(allProducts);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(label: 'All', selected: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all')),
                      for (final s in ProductStatus.values)
                        _FilterChip(label: s.label, selected: _statusFilter == s.name, onTap: () => setState(() => _statusFilter = s.name)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final c in categories)
                        _FilterChip(
                          label: c == 'all' ? 'All Categories' : c,
                          selected: _categoryFilter == c,
                          onTap: () => setState(() => _categoryFilter = c),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No matching products',
                          message: 'Try adjusting your search or filters.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => ProductListTile(
                            product: filtered[i],
                            onTap: () => context.push('/merchant/products/${filtered[i].id}'),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primarySurface,
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
