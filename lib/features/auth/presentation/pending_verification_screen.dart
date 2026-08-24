import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

/// Shown to merchants/suppliers whose account is `pendingVerification` or
/// `rejected` — they cannot reach their dashboard until an admin approves
/// them (§4 Administrator, §21 core business rule).
class PendingVerificationScreen extends ConsumerWidget {
  const PendingVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isRejected = appUser?.status == AccountStatus.rejected;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Status')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isRejected ? AppColors.errorBg : AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  color: isRejected ? AppColors.error : AppColors.warning,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Verification Rejected' : 'Verification Pending',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                isRejected
                    ? (appUser?.statusReason?.isNotEmpty == true
                        ? appUser!.statusReason!
                        : 'Your account was not approved. Please contact support for details.')
                    : "Thanks for registering, ${appUser?.fullName ?? ''}. Our team is reviewing your "
                        "${appUser?.role == UserRole.supplier ? 'supplier' : 'merchant'} details. "
                        "You'll be notified once verification is complete — this usually takes 1-2 business days.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
