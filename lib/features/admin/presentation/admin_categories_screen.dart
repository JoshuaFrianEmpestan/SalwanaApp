import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  final _newCategory = TextEditingController();

  Future<void> _add() async {
    final name = _newCategory.text.trim();
    if (name.isEmpty) return;
    await ref.read(adminRepositoryProvider).addCategory(name);
    _newCategory.clear();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Categories')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategory,
                      decoration: const InputDecoration(hintText: 'New category name', isDense: true),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _add, child: const Text('Add')),
                ],
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const LoadingListView(),
                error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(productCategoriesProvider)),
                data: (categories) {
                  if (categories.isEmpty) {
                    return const EmptyStateView(icon: Icons.category_outlined, title: 'No categories yet', message: 'Add categories consumers can filter and merchants can pick from.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = categories[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            Switch(value: c.active, onChanged: (v) => ref.read(adminRepositoryProvider).setCategoryActive(c.id, v)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
