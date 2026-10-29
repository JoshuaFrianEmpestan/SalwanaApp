import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class CloudinaryUploadService {
  static const _cloudName = 'zn4rsp51';
  static const _uploadPreset = 'salwana_unsigned';
  static const _maxBytes = 5 * 1024 * 1024;

  static const _allowedMime = {'image/jpeg', 'image/png', 'image/webp'};

  Future<String> uploadFile({required File file}) async {
    if (!await file.exists()) throw Exception('File not found');
    final size = await file.length();
    if (size > _maxBytes) throw Exception('Image exceeds 5MB');
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    if (!_allowedMime.contains(mime)) throw Exception('Unsupported image type');

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload?upload_preset=$_uploadPreset');
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', uri);
    request.fields.addAll({'upload_preset': _uploadPreset});
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: p.basename(file.path), contentType: MediaType.parse(mime)));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} $body');
    }
    final url = RegExp(r'"secure_url":"([^"]+)"').firstMatch(body)?.group(1);
    if (url == null) throw Exception('No URL returned');
    return url;
  }
}

final cloudinaryUploadServiceProvider = Provider<CloudinaryUploadService>((ref) {
  return CloudinaryUploadService();
});
