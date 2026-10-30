import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/store.dart';
import '../../../core/constants/enums.dart';
import '../data/store_repository.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _addressLine = TextEditingController();
  final _city = TextEditingController();
  final _reservationMinutes = TextEditingController();

  bool _seeded = false;
  bool _saving = false;
  bool _isOpen = true;
  bool _barcodeEnabled = false;
  String? _logoUrl;
  String? _bannerUrl;

  void _seed(Store store) {
    if (_seeded) return;
    _seeded = true;
    _name.text = store.name;
    _description.text = store.description;
    _category.text = store.category;
    _phone.text = store.phone;
    _email.text = store.email;
    _addressLine.text = store.addressLine;
    _city.text = store.city;
    _reservationMinutes.text = store.reservationExpirationMinutes.toString();
    _isOpen = store.isOpen;
    _barcodeEnabled = store.barcodeEnabled;
    _logoUrl = store.logoUrl;
    _bannerUrl = store.bannerUrl;
  }

  Future<void> _save(String merchantId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(storeRepositoryProvider).updateStore(merchantId, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'addressLine': _addressLine.text.trim(),
        'city': _city.text.trim(),
        'reservationExpirationMinutes': int.tryParse(_reservationMinutes.text.trim()) ?? 120,
        'isOpen': _isOpen,
        'barcodeEnabled': _barcodeEnabled,
        if (_logoUrl != null) 'logoUrl': _logoUrl,
        if (_bannerUrl != null) 'bannerUrl': _bannerUrl,
      });
      if (mounted) showAppSnackBar(context, 'Store profile updated.');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save changes. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final storeAsync = ref.watch(myStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store Profile')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: storeAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(myStoreProvider)),
          data: (store) {
            if (user == null) return const SizedBox.shrink();
            if (store == null) {
              return FutureBuilder<Store?>(
                future: ref.read(storeRepositoryProvider).syncStore().then((_) => ref.read(storeRepositoryProvider).getStore(user.id)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingListView();
                  }
                  if (snapshot.data == null) {
                    return const EmptyStateView(
                      icon: Icons.storefront_outlined,
                      title: 'Store not found',
                      message: 'Could not create a store for this account.',
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(myStoreProvider));
                  return const LoadingListView();
                },
              );
            }
            _seed(store);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          label: store.verificationStatus.label,
                          tone: store.isVerified
                              ? BadgeTone.success
                              : store.verificationStatus == AccountStatus.rejected
                                  ? BadgeTone.error
                                  : BadgeTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ImagePickerField(
                      initialUrl: _bannerUrl,
                      label: 'Add Store Banner',
                      height: 140,
                      storagePathBuilder: () => 'stores/${user.id}/banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
                      onUploaded: (url) => setState(() => _bannerUrl = url),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: ImagePickerField(
                            initialUrl: _logoUrl,
                            label: 'Logo',
                            height: 90,
                            placeholderIcon: Icons.storefront_outlined,
                            storagePathBuilder: () => 'stores/${user.id}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            onUploaded: (url) => setState(() => _logoUrl = url),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your store logo appears on your storefront and product listings.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppTextField(controller: _name, label: 'Store Name', validator: (v) => Validators.required(v, field: 'Store name')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _description, label: 'Description', maxLines: 3, validator: (v) => Validators.required(v, field: 'Description')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _category, label: 'Category', validator: (v) => Validators.required(v, field: 'Category')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
                    const SizedBox(height: 14),
                    AppTextField(controller: _email, label: 'Store Email', keyboardType: TextInputType.emailAddress, validator: Validators.email),
                    const SizedBox(height: 14),
                    AppTextField(controller: _addressLine, label: 'Address', validator: (v) => Validators.required(v, field: 'Address')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _city, label: 'City', validator: (v) => Validators.required(v, field: 'City')),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _reservationMinutes,
                      label: 'Reservation Expiration (minutes)',
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.positiveNumber(v, field: 'Reservation expiration'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isOpen,
                      onChanged: (v) => setState(() => _isOpen = v),
                      title: const Text('Store Open', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Consumers can only order or reserve while your store is open.', style: TextStyle(fontSize: 12)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _barcodeEnabled,
                      onChanged: (v) => setState(() => _barcodeEnabled = v),
                      title: const Text('Enable Barcode / QR Features', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Optional — scanning during stock-in and checkout.', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Save Changes', onPressed: () => _save(user.id), loading: _saving),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
