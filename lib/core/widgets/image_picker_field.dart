import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_upload_service.dart';
import '../theme/app_colors.dart';
import 'confirm_dialog.dart';

/// Pick-and-upload image field. Handles the picker, the Storage upload, and
/// the loading/local-preview/error states itself; the parent just gets the
/// resulting download URL via [onUploaded].
class ImagePickerField extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String Function() storagePathBuilder;
  final void Function(String url) onUploaded;
  final String label;
  final double height;
  final IconData placeholderIcon;

  const ImagePickerField({
    super.key,
    required this.initialUrl,
    required this.storagePathBuilder,
    required this.onUploaded,
    this.label = 'Add Photo',
    this.height = 160,
    this.placeholderIcon = Icons.add_photo_alternate_outlined,
  });

  @override
  ConsumerState<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends ConsumerState<ImagePickerField> {
  Uint8List? _localBytes;
  bool _uploading = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _localBytes = bytes;
      _uploading = true;
    });

    try {
      final url = await ref.read(cloudinaryUploadServiceProvider).uploadBytes(
            bytes: bytes,
            filename: picked.name,
            mimeType: picked.mimeType,
          );
      widget.onUploaded(url);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Image upload failed: $e', isError: true);
      setState(() => _localBytes = null);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _localBytes != null || (widget.initialUrl?.isNotEmpty ?? false);

    return InkWell(
      onTap: _uploading ? null : _pick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.neutralBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_localBytes != null)
              Image.memory(_localBytes!, fit: BoxFit.cover)
            else if (widget.initialUrl?.isNotEmpty ?? false)
              CachedNetworkImage(imageUrl: widget.initialUrl!, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.placeholderIcon, size: 32, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(widget.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            if (_uploading)
              Container(
                color: AppColors.overlay,
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  ),
                ),
              ),
            if (hasImage && !_uploading)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
