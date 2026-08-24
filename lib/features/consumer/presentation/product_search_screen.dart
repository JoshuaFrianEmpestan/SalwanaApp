import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/consumer_product_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/catalog_repository.dart';

enum _AvailabilityFilter { all, inStockOnly }
enum _SortBy { newest, priceLowHigh, priceHighLow }

class ProductSearchScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const ProductSearchScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _category = 'all';
  String _brand = 'all';
  _AvailabilityFilter _availability = _AvailabilityFilter.all;
  _SortBy _sort = _SortBy.newest;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialCategory == null,
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Search products, brands...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(
        child: catalogAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(catalogFeedProvider)),
          data: (products) {
            final categories = {'all', ...products.map((p) => p.category)}.toList()..sort();
            final brands = {'all', ...products.map((p) => p.brand).where((b) => b.isNotEmpty)}.toList()..sort();

            var filtered = products.where((p) {
              if (_search.isNotEmpty &&
                  !p.name.toLowerCase().contains(_search.toLowerCase()) &&
                  !p.brand.toLowerCase().contains(_search.toLowerCase())) {
                return false;
              }
              if (_category != 'all' && p.category != _category) return false;
              if (_brand != 'all' && p.brand != _brand) return false;
              if (_availability == _AvailabilityFilter.inStockOnly && p.isOutOfStock) return false;
              return true;
            }).toList();

            switch (_sort) {
              case _SortBy.priceLowHigh:
                filtered.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
                break;
              case _SortBy.priceHighLow:
                filtered.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
                break;
              case _SortBy.newest:
                break;
            }

            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      _FilterMenu(
                        label: _category == 'all' ? 'Category' : _category,
                        active: _category != 'all',
                        options: categories,
                        selected: _category,
                        display: (c) => c == 'all' ? 'All Categories' : c,
                        onSelected: (v) => setState(() => _category = v),
                      ),
                      const SizedBox(width: 8),
                      _FilterMenu(
                        label: _brand == 'all' ? 'Brand' : _brand,
                        active: _brand != 'all',
                        options: brands,
                        selected: _brand,
                        display: (b) => b == 'all' ? 'All Brands' : b,
                        onSelected: (v) => setState(() => _brand = v),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('In Stock Only'),
                        selected: _availability == _AvailabilityFilter.inStockOnly,
                        onSelected: (v) => setState(
                            () => _availability = v ? _AvailabilityFilter.inStockOnly : _AvailabilityFilter.all),
                        selectedColor: AppColors.primarySurface,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _availability == _AvailabilityFilter.inStockOnly ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterMenu(
                        label: switch (_sort) {
                          _SortBy.newest => 'Newest',
                          _SortBy.priceLowHigh => 'Price: Low to High',
                          _SortBy.priceHighLow => 'Price: High to Low',
                        },
                        active: _sort != _SortBy.newest,
                        options: _SortBy.values,
                        selected: _sort,
                        display: (_SortBy s) => switch (s) {
                          _SortBy.newest => 'Newest',
                          _SortBy.priceLowHigh => 'Price: Low to High',
                          _SortBy.priceHighLow => 'Price: High to Low',
                        },
                        onSelected: (v) => setState(() => _sort = v),
                        icon: Icons.sort_rounded,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          message: 'Try a different search term or clear some filters.',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, i) => ConsumerProductCard(
                            product: filtered[i],
                            onTap: () => context.push('/consumer/products/${filtered[i].id}'),
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

class _FilterMenu<T> extends StatelessWidget {
  final String label;
  final bool active;
  final List<T> options;
  final T selected;
  final String Function(T) display;
  final void Function(T) onSelected;
  final IconData icon;

  const _FilterMenu({
    required this.label,
    required this.active,
    required this.options,
    required this.selected,
    required this.display,
    required this.onSelected,
    this.icon = Icons.expand_more_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(display(o))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySurface : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? AppColors.primary : AppColors.textSecondary)),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
