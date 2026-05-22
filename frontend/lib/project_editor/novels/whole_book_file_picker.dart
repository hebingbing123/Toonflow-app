import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';
import 'whole_book_epub.dart';
import 'whole_book_import_resume.dart';

/// Max whole-book file size (desktop + web).
const int kWholeBookFileMaxBytes = 32 * 1024 * 1024;

/// Paste field is for spot checks; full books should use file pick.
const int kWholeBookPasteFieldMaxChars = 120000;

List<String> get wholeBookFilePickerExtensions =>
    <String>['txt', 'md', 'text', 'epub'];

class WholeBookFilePayload {
  const WholeBookFilePayload({
    required this.text,
    required this.sourceKey,
    required this.contentHash,
    required this.displayName,
    required this.byteLength,
  });

  final String text;
  final String sourceKey;
  final String contentHash;
  final String displayName;
  final int byteLength;
}

/// Decode plain-text novel file bytes (UTF-8 with optional BOM).
String decodeWholeBookTextBytes(List<int> bytes, AppLocalizations l10n) {
  if (bytes.isEmpty) {
    throw FormatException(l10n.projectEditorNovelsWholeBookPickFileEmpty);
  }
  if (bytes.length > kWholeBookFileMaxBytes) {
    throw FormatException(
      l10n.projectEditorNovelsWholeBookPickFileTooLarge(
        kWholeBookFileMaxBytes ~/ (1024 * 1024),
      ),
    );
  }
  var payload = bytes;
  if (payload.length >= 3 &&
      payload[0] == 0xEF &&
      payload[1] == 0xBB &&
      payload[2] == 0xBF) {
    payload = payload.sublist(3);
  }
  return utf8.decode(payload, allowMalformed: true);
}

String decodeWholeBookFileBytes(
  List<int> bytes,
  AppLocalizations l10n, {
  required String? filename,
}) {
  final name = filename?.trim().toLowerCase() ?? '';
  if (name.endsWith('.epub')) {
    return extractWholeBookTextFromEpubBytes(bytes, l10n);
  }
  if (name.endsWith('.txt') ||
      name.endsWith('.md') ||
      name.endsWith('.text') ||
      name.isEmpty) {
    return decodeWholeBookTextBytes(bytes, l10n);
  }
  throw FormatException(l10n.projectEditorNovelsWholeBookPickFileUnsupported);
}

/// Opens a system file picker (desktop + web) and returns decoded novel text + fingerprint.
Future<WholeBookFilePayload?> pickWholeBookFile(AppLocalizations l10n) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: wholeBookFilePickerExtensions,
    allowMultiple: false,
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.single;
  final displayName = file.name.trim().isEmpty ? 'novel' : file.name.trim();

  List<int> raw;
  if (file.bytes != null) {
    raw = file.bytes!;
  } else if (!kIsWeb && file.path != null && file.path!.trim().isNotEmpty) {
    final ioFile = File(file.path!.trim());
    final length = await ioFile.length();
    if (length > kWholeBookFileMaxBytes) {
      throw FormatException(
        l10n.projectEditorNovelsWholeBookPickFileTooLarge(
          kWholeBookFileMaxBytes ~/ (1024 * 1024),
        ),
      );
    }
    raw = await ioFile.readAsBytes();
  } else {
    throw FormatException(l10n.projectEditorNovelsWholeBookPickFileUnreadable);
  }

  final text = decodeWholeBookFileBytes(raw, l10n, filename: displayName);
  if (text.trim().isEmpty) {
    throw FormatException(l10n.projectEditorNovelsWholeBookPickFileEmpty);
  }
  final contentHash = wholeBookContentHash(text);
  final sourceKey = wholeBookSourceKeyFromContentHash(contentHash);
  return WholeBookFilePayload(
    text: text,
    sourceKey: sourceKey,
    contentHash: contentHash,
    displayName: displayName,
    byteLength: raw.length,
  );
}

/// Back-compat helper returning text only.
Future<String?> pickWholeBookFileText(AppLocalizations l10n) async {
  final payload = await pickWholeBookFile(l10n);
  return payload?.text;
}

/// Whether to mirror full text into the paste [TextField] (large books skip it).
bool shouldMirrorWholeBookIntoPasteField(String text) =>
    text.length <= kWholeBookPasteFieldMaxChars;
