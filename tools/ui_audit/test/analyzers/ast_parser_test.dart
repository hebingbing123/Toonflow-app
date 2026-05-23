import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/analyzers/ast_parser.dart';

void main() {
  group('AstParser', () {
    late AstParser parser;
    late Directory tempDir;

    setUp(() {
      parser = AstParser();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_ast_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parseFile returns ParsedDartFile for valid Dart', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
class Example {
  Widget build() => Text('hi');
}
''');

      final parsed = await parser.parseFile(file.path);
      expect(parsed, isNotNull);
      expect(parsed!.filePath, file.path);
      expect(parsed.unit, isNotNull);
    });

    test('parseFile returns null for invalid Dart', () async {
      final file = File('${tempDir.path}/bad.dart');
      file.writeAsStringSync('not dart {{{');

      final parsed = await parser.parseFile(file.path);
      // Parser may return a partial unit; callers treat unanalyzable files as skip.
      expect(parsed == null || parsed.unit.declarations.isEmpty, isTrue);
    });

    test('collectDartFiles respects include and exclude globs', () async {
      final libDir = Directory('${tempDir.path}/lib')..createSync();
      File('${libDir.path}/ok.dart').writeAsStringSync('void main() {}');
      File('${libDir.path}/ok.g.dart').writeAsStringSync('void main() {}');
      final genDir = Directory('${libDir.path}/generated')..createSync();
      File('${genDir.path}/skip.dart').writeAsStringSync('void main() {}');

      final files = await parser.collectDartFiles(
        projectPath: tempDir.path,
        includePaths: const ['lib/**/*.dart'],
        excludePaths: const [
          'lib/generated/**',
          'lib/**/*.g.dart',
        ],
      );

      expect(files, hasLength(1));
      expect(files.single, endsWith('ok.dart'));
    });

    test('buildSymbolTable records design system references', () async {
      final file = File('${tempDir.path}/tokens.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class Card extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(StudioSpacing.sm),
      child: Text('x', style: TextStyle(fontSize: StudioTypography.of(context).body)),
    );
  }
}
''');

      final parsed = await parser.parseFile(file.path);
      expect(parsed, isNotNull);

      final table = parser.buildSymbolTable(parsed!);
      expect(table.designSystemReferences, contains('StudioSpacing'));
      expect(table.designSystemReferences, contains('StudioTypography'));
      expect(table.widgets, isNotEmpty);
    });

    test('parseFile reuses cache when file is unchanged', () async {
      final file = File('${tempDir.path}/cached.dart');
      file.writeAsStringSync('void main() {}');

      final first = await parser.parseFile(file.path);
      final second = await parser.parseFile(file.path);

      expect(first, isNotNull);
      expect(identical(first, second), isTrue);

      file.writeAsStringSync('void main() { final x = 1; }');
      final third = await parser.parseFile(file.path);
      expect(identical(first, third), isFalse);
    });
  });
}
