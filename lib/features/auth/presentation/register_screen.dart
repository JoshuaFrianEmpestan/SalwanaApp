import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../data/onboarding_repository.dart';

/// Registration flow: role selection -> account details -> (merchant /
/// supplier only) store or company details for verification, per §2 and §4.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _step = 0;
  UserRole _role = UserRole.consumer;
  bool _loading = false;

  final _accountFormKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  final _businessFormKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _businessCategory = TextEditingController();
  final _businessAddress = TextEditingController();
  final _businessCity = TextEditingController();
  final _businessDescription = TextEditingController();

  bool get _needsBusinessStep => _role == UserRole.merchant || _role == UserRole.supplier;

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _fullName,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _businessName,
      _businessCategory,
      _businessAddress,
      _businessCity,
      _businessDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _onContinueFromAccount() {
    if (!_accountFormKey.currentState!.validate()) return;
    if (_needsBusinessStep) {
      _goToStep(1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_needsBusinessStep && !_businessFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.register(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
      );

      final uid = authRepo.currentUser!.uid;
      final onboardingRepo = ref.read(onboardingRepositoryProvider);
      if (_role == UserRole.merchant) {
        await onboardingRepo.submitMerchantStore(
          merchantId: uid,
          storeName: _businessName.text.trim(),
          category: _businessCategory.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          addressLine: _businessAddress.text.trim(),
          city: _businessCity.text.trim(),
          description: _businessDescription.text.trim(),
        );
      } else if (_role == UserRole.supplier) {
        await onboardingRepo.submitSupplierProfile(
          supplierId: uid,
          companyName: _businessName.text.trim(),
          contactName: _fullName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _businessAddress.text.trim(),
        );
      }
      // Router redirect sends the user to /verify-email automatically.
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Registration failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 1) {
              _goToStep(0);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildAccountStep(), _buildBusinessStep()],
        ),
      ),
    );
  }

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('I am a...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RoleCard(
                  role: UserRole.consumer,
                  icon: Icons.shopping_bag_outlined,
                  selected: _role == UserRole.consumer,
                  onTap: () => setState(() => _role = UserRole.consumer),
                ),
                _RoleCard(
                  role: UserRole.merchant,
                  icon: Icons.storefront_outlined,
                  selected: _role == UserRole.merchant,
                  onTap: () => setState(() => _role = UserRole.merchant),
                ),
                _RoleCard(
                  role: UserRole.supplier,
                  icon: Icons.local_shipping_outlined,
                  selected: _role == UserRole.supplier,
                  onTap: () => setState(() => _role = UserRole.supplier),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _fullName,
              label: 'Full Name',
              validator: (v) => Validators.required(v, field: 'Full name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _phone,
              label: 'Phone Number',
              hint: '09XXXXXXXXX',
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: true,
              validator: Validators.password,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmPassword,
              label: 'Confirm Password',
              obscureText: true,
              validator: (v) => Validators.confirmPassword(v, _password.text),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _needsBusinessStep ? 'Continue' : 'Create Account',
              onPressed: _onContinueFromAccount,
              loading: _loading && !_needsBusinessStep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessStep() {
    final isSupplier = _role == UserRole.supplier;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _businessFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSupplier ? 'Supplier details' : 'Store details',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'This information is reviewed by an administrator before your account is verified.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _businessName,
              label: isSupplier ? 'Company Name' : 'Store Name',
              validator: (v) => Validators.required(v, field: 'This field'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            if (!isSupplier) ...[
              AppTextField(
                controller: _businessCategory,
                label: 'Store Category',
                hint: 'e.g. Grocery, Electronics, Apparel',
                validator: (v) => Validators.required(v, field: 'Category'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
            ],
            AppTextField(
              controller: _businessAddress,
              label: 'Address',
              validator: (v) => Validators.required(v, field: 'Address'),
              textInputAction: TextInputAction.next,
            ),
            if (!isSupplier) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _businessCity,
                label: 'City',
                validator: (v) => Validators.required(v, field: 'City'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _businessDescription,
                label: 'Store Description',
                maxLines: 3,
                validator: (v) => Validators.required(v, field: 'Description'),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(label: 'Submit for Verification', onPressed: _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({required this.role, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              role.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
