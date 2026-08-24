import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  Timer? _pollTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Poll periodically so the user is auto-advanced once they click the
    // verification link in their inbox, without needing to tap "I've verified".
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final verified = await ref.read(authRepositoryProvider).refreshEmailVerified();
      if (!verified && !silent && mounted) {
        showAppSnackBar(context, "Not verified yet — check your inbox.", isError: true);
      }
      // Router redirect automatically moves forward once verified.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendVerificationEmail();
      if (mounted) showAppSnackBar(context, 'Verification email sent.');
      setState(() => _resendCooldown = 30);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_resendCooldown <= 1) {
          t.cancel();
          setState(() => _resendCooldown = 0);
        } else {
          setState(() => _resendCooldown--);
        }
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? 'your email';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_rounded, color: AppColors.primary, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Check your inbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                "We've sent a verification link to $email. Verify your address to continue.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: "I've Verified", onPressed: () => _check(), loading: _checking),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resendCooldown > 0 || _resending ? null : _resend,
                child: Text(_resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend Email'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Use a different account', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
