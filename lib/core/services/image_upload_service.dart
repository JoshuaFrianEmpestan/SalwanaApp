import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_providers.dart';

/// Thin wrapper around Cloud Storage uploads, shared by every "pick an
/// image" flow (store logo/banner, product photos, profile photo).
class ImageUploadService {
  final FirebaseStorage _storage;
  ImageUploadService(this._storage);

  Future<String> uploadFile({
    required File file,
    required String path,
  }) async {
    final ref = _storage.ref(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(ref.watch(firebaseStorageProvider));
});
