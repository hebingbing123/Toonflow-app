import 'dart:io';
import 'package:test/test.dart';
import 'package:ui_audit/analyzers/visual_hierarchy_analyzer.dart';
import 'package:ui_audit/models/models.dart';

void main() {
  group('VisualHierarchyAnalyzer', () {
    late VisualHierarchyAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = VisualHierarchyAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('detects hardcoded font size', () async {
      final testFile = File('${tempDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Hello',
      style: TextStyle(fontSize: 19),
    );
  }
}
''');

      final findings = await analyzer.analyze(testFile.path);

      expect(findings, isNotEmpty);
      expect(findings.first.category, equals(FindingCategory.visualHierarchy));
      expect(findings.first.severity, equals(Severity.high));
      expect(findings.first.title, contains('Hardcoded font size'));
      expect(findings.first.description, contains('fontSize: 19'));
    });

    test('does not flag StudioTypography references', () async {
      final testFile = File('${tempDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Hello',
      style: TextStyle(fontSize: StudioTypography.of(context).body),
    );
  }
}
''');

      final findings = await analyzer.analyze(testFile.path);

      expect(findings, isEmpty);
    });

    test('maps font size to typography scale', () async {
      final testFile = File('${tempDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Title',
      style: TextStyle(fontSize: 16),
    );
  }
}
''');

      final findings = await analyzer.analyze(testFile.path);

      expect(findings, isNotEmpty);
      expect(findings.first.recommendation, contains('dialogTitle'));
      expect(findings.first.designSystemReference, contains('StudioTypography.dialogTitle'));
    });

    test('detects heading hierarchy skip', () async {
      final testFile = File('${tempDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Main Title', style: TextStyle(fontSize: 28)),
        Text('Small Text', style: TextStyle(fontSize: 13)),
      ],
    );
  }
}
''');

      final findings = await analyzer.analyze(testFile.path);

      // Should have 2 findings: 2 hardcoded font sizes + 1 hierarchy skip
      expect(findings.length, greaterThanOrEqualTo(2));
      
      final hierarchyFindings = findings.where(
        (f) => f.title.contains('hierarchy'),
      ).toList();
      
      expect(hierarchyFindings, isNotEmpty);
      expect(hierarchyFindings.first.severity, equals(Severity.medium));
    });

    test('calculateContrastRatio returns correct values', () {
      final analyzer = VisualHierarchyAnalyzer();
      
      // White on black should have high contrast (21:1)
      final whiteOnBlack = analyzer.calculateContrastRatio(
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
      );
      expect(whiteOnBlack, closeTo(21.0, 0.1));

      // Same color should have 1:1 contrast
      final sameColor = analyzer.calculateContrastRatio(
        const Color(0xFF7C97FF),
        const Color(0xFF7C97FF),
      );
      expect(sameColor, closeTo(1.0, 0.01));
    });

    test('meetsWCAG_AA correctly validates contrast ratios', () {
      final analyzer = VisualHierarchyAnalyzer();

      // Body text needs 4.5:1
      expect(analyzer.meetsWCAG_AA(4.5, 14, false), isTrue);
      expect(analyzer.meetsWCAG_AA(4.4, 14, false), isFalse);

      // Large text needs 3:1
      expect(analyzer.meetsWCAG_AA(3.0, 24, false), isTrue);
      expect(analyzer.meetsWCAG_AA(2.9, 24, false), isFalse);

      // Bold text >= 18.66px is considered large
      expect(analyzer.meetsWCAG_AA(3.0, 19, true), isTrue);
      expect(analyzer.meetsWCAG_AA(2.9, 19, true), isFalse);
    });

    test('handles files with parse errors gracefully', () async {
      final testFile = File('${tempDir.path}/invalid.dart');
      testFile.writeAsStringSync('this is not valid dart code {{{');

      final findings = await analyzer.analyze(testFile.path);

      // Should return empty list, not throw
      expect(findings, isEmpty);
    });

    test('handles non-existent files gracefully', () async {
      final findings = await analyzer.analyze('${tempDir.path}/nonexistent.dart');

      // Should return empty list, not throw
      expect(findings, isEmpty);
    });

    test('provides before/after examples for fixes', () async {
      final testFile = File('${tempDir.path}/test_widget.dart');
      testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Title',
      style: TextStyle(fontSize: 16),
    );
  }
}
''');

      final findings = await analyzer.analyze(testFile.path);

      expect(findings, isNotEmpty);
      expect(findings.first.beforeAfter, isNotNull);
      expect(findings.first.beforeAfter!.before, contains('fontSize: 16'));
      expect(findings.first.beforeAfter!.after, contains('StudioTypography.of(context)'));
    });
  });
}
