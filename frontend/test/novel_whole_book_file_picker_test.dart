import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_editor/novels/whole_book_file_picker.dart';

void main() {
  final l10n = AppLocalizationsZh();

  test('decodeWholeBookTextBytes strips UTF-8 BOM', () {
    final text = decodeWholeBookTextBytes(
      <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('第一章\n正文')],
      l10n,
    );
    expect(text.startsWith('第一章'), isTrue);
  });

  test('decodeWholeBookTextBytes rejects empty file', () {
    expect(
      () => decodeWholeBookTextBytes(<int>[], l10n),
      throwsFormatException,
    );
  });

  test('shouldMirrorWholeBookIntoPasteField caps paste field size', () {
    expect(shouldMirrorWholeBookIntoPasteField('a' * 1000), isTrue);
    expect(
      shouldMirrorWholeBookIntoPasteField('a' * (kWholeBookPasteFieldMaxChars + 1)),
      isFalse,
    );
  });
}
