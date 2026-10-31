import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
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
  final _companyDescription = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  final _categoryInput = TextEditingController();

  final List<String> _categories = [];
  String? _logoUrl;
  bool _seeded = false;
  bool _saving = false;
  bool _dirty = false;


  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _seed(SupplierProfile p) {
    if (_seeded) return;
    _seeded = true;
    _companyName.text = p.companyName;
    _companyDescription.text = p.companyDescription ?? '';
    _logoUrl = p.logoUrl;
    _contactName.text = p.contactName;
    _phone.text = p.phone;
    _email.text = p.email;
    _address.text = p.address;
    _city.text = p.city ?? '';
    _province.text = p.province ?? '';
    _postalCode.text = p.postalCode ?? '';
    _categories
      ..clear()
      ..addAll(p.suppliedCategories);
  }

  void _addCategory() {
    final value = _categoryInput.text.trim();
    if (value.isEmpty) return;
    if (_categories.any((c) => c.toLowerCase() == value.toLowerCase())) {
      showAppSnackBar(context, 'Category already added.', isError: true);
      return;
    }
    setState(() {
      _categories.add(value);
      _categoryInput.clear();
      _dirty = true;
    });
  }

  void _removeCategory(String c) {
    setState(() {
      _categories.remove(c);
      _dirty = true;
    });
  }

  Future<void> _save(String supplierId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_categories.isEmpty) {
      showAppSnackBar(context, 'Add at least one supplied category.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(supplierProfileRepositoryProvider).updateProfile(supplierId, {
        'companyName': _companyName.text.trim(),
        'companyDescription': _companyDescription.text.trim().isEmpty ? null : _companyDescription.text.trim(),
        'logoUrl': _logoUrl,
        'contactName': _contactName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'province': _province.text.trim().isEmpty ? null : _province.text.trim(),
        'postalCode': _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
        'suppliedCategories': List<String>.from(_categories),
      });
      if (mounted) {
        showAppSnackBar(context, 'Profile saved successfully.');
        setState(() => _dirty = false);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save changes: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final res = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. Leave without saving?',
      confirmLabel: 'Discard',
      destructive: true,
    );
    return res;
  }

  @override
  void dispose() {
    _companyName.dispose();
    _companyDescription.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    _postalCode.dispose();
    _categoryInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final profileAsync = ref.watch(mySupplierProfileProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _confirmDiscard();
        if (ok && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Company Profile')),
        body: SafeArea(
          child: ResponsiveFormBody(
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
                        _buildHeader(profile),
                        const SizedBox(height: 20),
                        _section('Company Information'),
                        const SizedBox(height: 8),
                        ImagePickerField(
                          initialUrl: _logoUrl,
                          storagePathBuilder: () => 'supplier_logos/${user.id}',
                          onUploaded: (url) {
                            setState(() {
                              _logoUrl = url;
                              _dirty = true;
                            });
                          },
                          label: 'Upload Company Logo',
                          height: 140,
                          placeholderIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _companyName,
                          label: 'Company Name',
                          validator: (v) => Validators.required(v, field: 'Company name'),
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _companyDescription,
                          label: 'Company Description (optional)',
                          maxLines: 3,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 14),
                        _buildCategoriesEditor(),
                        const SizedBox(height: 20),
                        _section('Contact Information'),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _contactName,
                          label: 'Contact Person',
                          validator: (v) => Validators.required(v, field: 'Contact person'),
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _phone,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          validator: Validators.phone,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _email,
                          label: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 20),
                        _section('Business Address'),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _address,
                          label: 'Street / Address',
                          validator: (v) => Validators.required(v, field: 'Address'),
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _city,
                                label: 'City',
                                onChanged: (_) => _markDirty(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: _province,
                                label: 'Province',
                                onChanged: (_) => _markDirty(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _postalCode,
                          label: 'Postal Code',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Save Changes',
                          onPressed: (!_dirty || _saving) ? null : () => _save(user.id),
                          loading: _saving,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SupplierProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primarySurface,
            backgroundImage: (_logoUrl != null && _logoUrl!.isNotEmpty) ? NetworkImage(_logoUrl!) : null,
            child: (_logoUrl == null || _logoUrl!.isEmpty) ? const Icon(Icons.business_rounded, color: AppColors.primary, size: 30) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_companyName.text.isEmpty ? profile.companyName : _companyName.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(profile.verificationStatus.label, style: TextStyle(fontSize: 12, color: profile.verificationStatus == AccountStatus.active ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w600)),
                if ((profile.companyDescription ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(profile.companyDescription!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
  }

  Widget _buildCategoriesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Supplied Categories', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        if (_categories.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _categories)
                Chip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => _removeCategory(c),
                  backgroundColor: AppColors.primarySurface,
                  side: const BorderSide(color: AppColors.primary),
                ),
            ],
          ),
        if (_categories.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryInput,
                decoration: const InputDecoration(
                  labelText: 'Add category',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addCategory(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addCategory,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}
