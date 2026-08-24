import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';

/// Shown when an admin has suspended or deactivated the account (§4, §21).
class AccountBlockedScreen extends ConsumerWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
                child: const Icon(Icons.block_rounded, color: AppColors.error, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                appUser?.status.label ?? 'Account Restricted',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                appUser?.statusReason?.isNotEmpty == true
                    ? appUser!.statusReason!
                    : 'Your account has been restricted by an administrator. Contact support for more information.',
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
