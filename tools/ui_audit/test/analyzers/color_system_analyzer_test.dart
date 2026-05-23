import 'dart:io';

import 'package:test/test.dart';
import 'package:ui_audit/analyzers/color_system_analyzer.dart';
import 'package:ui_audit/models/models.dart';

void main() {
  group('ColorSystemAnalyzer', () {
    late ColorSystemAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = ColorSystemAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_color_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Property 7: detects hardcoded Color()', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final c = Color(0xFF7C97FF);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.category, FindingCategory.colorSystem);
      expect(findings.first.title, contains('Hardcoded color'));
    });

    test('Property 7: detects Colors.white', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final c = Colors.white;
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
    });

    test('Property 8: flags glass token on card surface', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class C {
  void m(BuildContext context) {
    final card = Container(color: StudioTokens.of(context).glass);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('Glass token')),
        isTrue,
      );
    });

    test('does not flag StudioTokens on overlay toast', () async {
      final file = File('${tempDir.path}/widget.dart')
        ..writeAsStringSync('''
class ToastOverlay {
  void m(BuildContext context) {
    final panel = Container(color: StudioTokens.of(context).glass);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings.where((f) => f.title.contains('Glass token')), isEmpty);
    });
  });
}
