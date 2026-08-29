import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/responsive_form_body.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: ResponsiveFormBody(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSentState() : _buildForm(),
        ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the email associated with your account and we will send a link to reset your password.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Send Reset Link', onPressed: _submit, loading: _loading),
        ],
      ),
    );
  }

  Widget _buildSentState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Check your email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          "We've sent a password reset link to ${_email.text.trim()}.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
