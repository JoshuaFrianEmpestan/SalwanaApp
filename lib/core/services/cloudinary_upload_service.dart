import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class CloudinaryUploadService {
  static const _cloudName = 'zn4rsp51';
  static const _uploadPreset = 'salwana_unsigned';
  static const _maxBytes = 5 * 1024 * 1024;

  static const _allowedMime = {'image/jpeg', 'image/png', 'image/webp'};

  Future<String> uploadBytes({required Uint8List bytes, required String filename, String? mimeType}) async {
    if (bytes.isEmpty) throw Exception('File not found');
    final size = bytes.length;
    if (size > _maxBytes) throw Exception('Image exceeds 5MB');
    final ext = p.extension(filename).toLowerCase().replaceAll('.', '');
    final mime = (mimeType != null && _allowedMime.contains(mimeType))
        ? mimeType
        : ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
    if (!_allowedMime.contains(mime)) throw Exception('Unsupported image type');

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload?upload_preset=$_uploadPreset');
    final request = http.MultipartRequest('POST', uri);
    request.fields.addAll({'upload_preset': _uploadPreset});
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename.isEmpty ? 'image.$ext' : filename, contentType: MediaType.parse(mime)));
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
