import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/store_card.dart';
import '../data/catalog_repository.dart';

class StoreBrowseScreen extends ConsumerStatefulWidget {
  const StoreBrowseScreen({super.key});

  @override
  ConsumerState<StoreBrowseScreen> createState() => _StoreBrowseScreenState();
}

class _StoreBrowseScreenState extends ConsumerState<StoreBrowseScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _category = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storesAsync = ref.watch(activeStoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      body: SafeArea(
        child: storesAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(activeStoresProvider)),
          data: (stores) {
            if (stores.isEmpty) {
              return const EmptyStateView(
                icon: Icons.storefront_outlined,
                title: 'No stores yet',
                message: 'Verified merchant stores will appear here once they join Salwana.',
              );
            }

            final categories = {'all', ...stores.map((s) => s.category)}.toList();
            final filtered = stores.where((s) {
              if (_search.isNotEmpty && !s.name.toLowerCase().contains(_search.toLowerCase())) return false;
              if (_category != 'all' && s.category != _category) return false;
              return true;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search stores',
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
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c == 'all' ? 'All' : c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                            selectedColor: AppColors.primarySurface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _category == c ? AppColors.primary : AppColors.textSecondary,
                            ),
                            side: BorderSide(color: _category == c ? AppColors.primary : AppColors.border),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No matching stores',
                          message: 'Try a different search or category.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => StoreCard(
                            store: filtered[i],
                            onTap: () => context.push('/consumer/stores/${filtered[i].id}'),
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
