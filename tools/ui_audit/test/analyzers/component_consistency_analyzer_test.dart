import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/analyzers/component_consistency_analyzer.dart';

void main() {
  group('ComponentConsistencyAnalyzer', () {
    late ComponentConsistencyAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = ComponentConsistencyAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_cc_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('flags non-standard border radius', () async {
      final file = File('${tempDir.path}/w.dart')
        ..writeAsStringSync('''
class C {
  void m() {
    final r = BorderRadius.circular(11);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(
        findings.any((f) => f.title.contains('border radius')),
        isTrue,
      );
    });
  });
}
