import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';

BadgeTone _statusTone(AccountStatus status) => switch (status) {
      AccountStatus.active => BadgeTone.success,
      AccountStatus.pendingVerification => BadgeTone.warning,
      AccountStatus.suspended => BadgeTone.error,
      AccountStatus.rejected => BadgeTone.error,
      AccountStatus.deactivated => BadgeTone.neutral,
    };

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _activeFilter = 'all';
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: SafeArea(
        child: usersAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(allUsersProvider)),
          data: (users) {
            final pendingCount = users.where((u) => u.status == AccountStatus.pendingVerification).length;
            var filtered = users.where((u) {
              if (_activeFilter == 'pending' && u.status != AccountStatus.pendingVerification) return false;
              if (_activeFilter != 'all' && _activeFilter != 'pending' && u.role.name != _activeFilter) return false;
              if (_search.text.isNotEmpty && !u.fullName.toLowerCase().contains(_search.text.toLowerCase()) && !u.email.toLowerCase().contains(_search.text.toLowerCase())) return false;
              return true;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Search name or email', prefixIcon: Icon(Icons.search_rounded, size: 20), isDense: true),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _Chip(label: 'All', selected: _activeFilter == 'all', onTap: () => setState(() => _activeFilter = 'all')),
                      _Chip(label: 'Pending ($pendingCount)', selected: _activeFilter == 'pending', onTap: () => setState(() => _activeFilter = 'pending')),
                      for (final r in UserRole.values)
                        _Chip(label: r.label, selected: _activeFilter == r.name, onTap: () => setState(() => _activeFilter = r.name)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyStateView(icon: Icons.people_outline_rounded, title: 'No matching users', message: '')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final u = filtered[i];
                            return InkWell(
                              onTap: () => context.push('/admin/users/${u.id}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                          Text(u.email, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text(u.role.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(label: u.status.label, tone: _statusTone(u.status)),
                                  ],
                                ),
                              ),
                            );
                          },
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primarySurface,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondary),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }
}
