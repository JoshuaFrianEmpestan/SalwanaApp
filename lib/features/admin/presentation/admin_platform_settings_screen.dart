import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/application_settings.dart';
import '../data/admin_repository.dart';

const _allPaymentMethods = ['gcash', 'maya', 'cashOnDelivery', 'simulated'];

/// Platform fee / delivery fee / enabled payment methods / reservation
/// expiration default — one settings doc, edited from either the "Payment
/// Options & Fees" or "Reservation Rules" admin menu entries (§4, §14).
class AdminPlatformSettingsScreen extends ConsumerStatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  ConsumerState<AdminPlatformSettingsScreen> createState() => _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState extends ConsumerState<AdminPlatformSettingsScreen> {
  final _platformFee = TextEditingController();
  final _deliveryFee = TextEditingController();
  final _reservationMinutes = TextEditingController();
  late Set<String> _methods;
  bool _seeded = false;
  bool _saving = false;

  void _seed(ApplicationSettings s) {
    if (_seeded) return;
    _seeded = true;
    _platformFee.text = s.platformFeePercent.toString();
    _deliveryFee.text = s.defaultDeliveryFee.toString();
    _reservationMinutes.text = s.defaultReservationExpirationMinutes.toString();
    _methods = s.enabledPaymentMethods.toSet();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateSettings({
        'platformFeePercent': double.tryParse(_platformFee.text.trim()) ?? 0,
        'defaultDeliveryFee': double.tryParse(_deliveryFee.text.trim()) ?? 0,
        'defaultReservationExpirationMinutes': int.tryParse(_reservationMinutes.text.trim()) ?? 120,
        'enabledPaymentMethods': _methods.toList(),
      });
      if (mounted) showAppSnackBar(context, 'Platform settings updated.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save settings.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(applicationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Platform Settings')),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(applicationSettingsProvider)),
          data: (settings) {
            _seed(settings);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Fees', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                TextField(controller: _platformFee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Platform Fee (%)')),
                const SizedBox(height: 14),
                TextField(controller: _deliveryFee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Default Delivery Fee')),
                const SizedBox(height: 20),
                const Text('Reservation Rules', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                TextField(controller: _reservationMinutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Reservation Expiration (minutes)')),
                const SizedBox(height: 20),
                const Text('Enabled Payment Methods', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _allPaymentMethods)
                      FilterChip(
                        label: Text(PaymentMethodX.fromName(m).label),
                        selected: _methods.contains(m),
                        onSelected: (v) => setState(() => v ? _methods.add(m) : _methods.remove(m)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save Settings', onPressed: _save, loading: _saving),
              ],
            );
          },
        ),
      ),
    );
  }
}
