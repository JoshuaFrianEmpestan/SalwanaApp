import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_views.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  String? _photoUrl;
  bool _seeded = false;
  bool _saving = false;

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(uid, fullName: _fullName.text.trim(), phone: _phone.text.trim(), photoUrl: _photoUrl);
      if (mounted) {
        showAppSnackBar(context, 'Profile updated.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save changes.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const LoadingListView(),
          error: (e, _) => ErrorStateView(onRetry: () => ref.invalidate(appUserProvider)),
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            if (!_seeded) {
              _seeded = true;
              _fullName.text = user.fullName;
              _phone.text = user.phone ?? '';
              _photoUrl = user.photoUrl;
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(48),
                          child: ImagePickerField(
                            initialUrl: _photoUrl,
                            label: 'Photo',
                            height: 96,
                            placeholderIcon: Icons.person_outline_rounded,
                            storagePathBuilder: () => 'users/${user.id}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
                            onUploaded: (url) => setState(() => _photoUrl = url),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(controller: _fullName, label: 'Full Name', validator: (v) => Validators.required(v, field: 'Full name')),
                    const SizedBox(height: 14),
                    AppTextField(controller: _phone, label: 'Phone Number', keyboardType: TextInputType.phone, validator: Validators.phone),
                    const SizedBox(height: 14),
                    AppTextField(controller: TextEditingController(text: user.email), label: 'Email', enabled: false),
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
