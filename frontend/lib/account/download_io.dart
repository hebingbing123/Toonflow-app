import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveAccountExportToDevice(
  Uint8List bytes,
  String fileName,
) async {
  final baseDir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${baseDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
