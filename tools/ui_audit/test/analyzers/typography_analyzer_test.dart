import 'dart:io';

import 'package:test/test.dart';
import 'package:ui_audit/analyzers/typography_analyzer.dart';
import 'package:ui_audit/models/models.dart';

void main() {
  group('TypographyAnalyzer (Property 6)', () {
    late TypographyAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = TypographyAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_typography_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('flags line-height outside 1.2-1.5', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final s = TextStyle(height: 2.0, fontSize: 14);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('Line-height')),
        isTrue,
      );
    });

    test('does not flag StudioTypography usage', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final s = TextStyle(fontSize: StudioTypography.of(context).body);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('without StudioTypography')), isEmpty);
    });

    test('does not flag local typography scale variable', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m(dynamic typography) {
    final s = TextStyle(
      fontSize: typography.meta,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.where((f) => f.title.contains('without StudioTypography')),
        isEmpty,
      );
      expect(
        findings.where((f) => f.severity == Severity.high),
        isEmpty,
      );
    });

    test('flags hardcoded text colors', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final s = TextStyle(color: Color(0xFFE8F1FF));
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('Text color not using StudioTokens')),
        isTrue,
      );
    });
  });
}
