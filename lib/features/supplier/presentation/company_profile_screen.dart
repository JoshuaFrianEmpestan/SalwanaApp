import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/supplier.dart';
import '../data/supplier_profile_repository.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyName = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _categories = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  void _seed(SupplierProfile p) {
    if (_seeded) return;
    _seeded = true;
    _companyName.text = p.companyName;
    _contactName.text = p.contactName;
    _phone.text = p.phone;
    _email.text = p.email;
    _address.text = p.address;
    _categories.text = p.suppliedCategories.join(', ');
  }

  Future<void> _save(String supplierId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(supplierProfileRepositoryProvider).updateProfile(supplierId, {
        'companyName': _companyName.text.trim(),
        'contactName': _contactName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'suppliedCategories': _categories.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      });
      if (mounted) showAppSnackBar(context, 'Profile updated.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save changes.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final profileAsync = ref.watch(mySupplierProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(mySupplierProfileProvider)),
          data: (profile) {
            if (profile == null || user == null) {
              return const EmptyStateView(icon: Icons.business_outlined, title: 'Profile not found', message: '');
            }
            _seed(profile);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge(
                      label: profile.verificationStatus.label,
                      tone: profile.verificationStatus == AccountStatus.active
                          ? BadgeTone.success
                          : profile.verificationStatus == AccountStatus.rejected
                              ? BadgeTone.error
                              : BadgeTone.warning,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(controller: _companyName, label: 'Company Name', validator: (v) => Validators.required(v, field: 'Company name')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _contactName, label: 'Contact Person', validator: (v) => Validators.required(v, field: 'Contact person')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
                    const SizedBox(height: 14),
                    AppTextField(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress, validator: Validators.email),
                    const SizedBox(height: 14),
                    AppTextField(controller: _address, label: 'Address', validator: (v) => Validators.required(v, field: 'Address')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _categories, label: 'Supplied Categories', hint: 'Comma-separated, e.g. Grocery, Beverages'),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Save Changes', onPressed: () => _save(user.id), loading: _saving),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
