// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

String _blobMimeTypeForExportFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.json')) {
    return 'application/json; charset=utf-8';
  }
  if (lower.endsWith('.csv')) {
    return 'text/csv; charset=utf-8';
  }
  return 'application/octet-stream';
}

Future<String> saveNotificationExportToDevice(
  Uint8List bytes,
  String fileName, {
  String? contentType,
  String? unsupportedMessage,
}) async {
  final mime = (contentType != null && contentType.trim().isNotEmpty)
      ? contentType.trim()
      : _blobMimeTypeForExportFileName(fileName);
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
