import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/address_repository.dart';

class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(myAddressesProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: user == null ? null : () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _AddAddressSheet(userId: user.id)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Address'),
      ),
      body: SafeArea(
        child: addressesAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(myAddressesProvider)),
          data: (addresses) {
            if (addresses.isEmpty) {
              return const EmptyStateView(icon: Icons.location_on_outlined, title: 'No saved addresses', message: 'Add a delivery address to speed up checkout.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = addresses[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: a.isDefault ? AppColors.primary : AppColors.border, width: a.isDefault ? 1.5 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                          if (a.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Default', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${a.recipientName} · ${a.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(a.fullAddress, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (!a.isDefault)
                            TextButton(onPressed: () => ref.read(addressRepositoryProvider).setDefault(user!.id, a.id), child: const Text('Set as Default')),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final confirmed = await showConfirmDialog(context, title: 'Delete Address', message: 'Remove this saved address?', confirmLabel: 'Delete', destructive: true);
                              if (confirmed) await ref.read(addressRepositoryProvider).deleteAddress(a.id);
                            },
                            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AddAddressSheet extends ConsumerStatefulWidget {
  final String userId;
  const _AddAddressSheet({required this.userId});

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Home');
  final _recipientName = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(addressRepositoryProvider).addAddress(
            userId: widget.userId,
            label: _label.text.trim(),
            recipientName: _recipientName.text.trim(),
            phone: _phone.text.trim(),
            line1: _line1.text.trim(),
            city: _city.text.trim(),
            province: _province.text.trim(),
            postalCode: _postalCode.text.trim(),
            isDefault: _isDefault,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save address.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              AppTextField(controller: _label, label: 'Label', hint: 'Home, Work...', validator: (v) => Validators.required(v, field: 'Label')),
              const SizedBox(height: 14),
              AppTextField(controller: _recipientName, label: 'Recipient Name', validator: (v) => Validators.required(v, field: 'Recipient name')),
              const SizedBox(height: 14),
              AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
              const SizedBox(height: 14),
              AppTextField(controller: _line1, label: 'Address Line', validator: (v) => Validators.required(v, field: 'Address')),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: AppTextField(controller: _city, label: 'City', validator: (v) => Validators.required(v, field: 'City'))),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(controller: _province, label: 'Province', validator: (v) => Validators.required(v, field: 'Province'))),
              ]),
              const SizedBox(height: 14),
              AppTextField(controller: _postalCode, label: 'Postal Code', keyboardType: TextInputType.number, validator: (v) => Validators.required(v, field: 'Postal code')),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                title: const Text('Set as default address', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Save Address', onPressed: _save, loading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
