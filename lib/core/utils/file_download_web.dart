// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes(List<int> bytes, String fileName, String mimeType) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
