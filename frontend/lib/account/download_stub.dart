import 'dart:typed_data';

Future<String> saveAccountExportToDevice(Uint8List bytes, String fileName) {
  throw UnsupportedError(
    'Saving account exports is not supported on this platform.',
  );
}
