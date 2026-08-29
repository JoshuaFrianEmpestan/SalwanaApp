import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../data/profile_repository.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).changePassword(currentPassword: _currentPassword.text, newPassword: _newPassword.text);
      if (mounted) {
        showAppSnackBar(context, 'Password updated.');
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
      }
    } on ProfileException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not change password.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(firebaseAuthProvider).currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Signed in as $email', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Change Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(controller: _currentPassword, label: 'Current Password', obscureText: true, validator: (v) => Validators.required(v, field: 'Current password')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _newPassword, label: 'New Password', obscureText: true, validator: Validators.password),
                    const SizedBox(height: 14),
                    AppTextField(controller: _confirmPassword, label: 'Confirm New Password', obscureText: true, validator: (v) => Validators.confirmPassword(v, _newPassword.text)),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Update Password', onPressed: _changePassword, loading: _saving),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
