import 'dart:typed_data';

Future<String> saveNotificationExportToDevice(
  Uint8List bytes,
  String fileName, {
  String? contentType,
  String? unsupportedMessage,
}) async {
  throw UnsupportedError(
    unsupportedMessage ??
        'Downloads are not supported on this platform: $fileName (${bytes.lengthInBytes} bytes).',
  );
}
