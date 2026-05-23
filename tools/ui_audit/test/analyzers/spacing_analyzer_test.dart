import 'dart:io';

import 'package:test/test.dart';
import 'package:ui_audit/analyzers/spacing_analyzer.dart';
import 'package:ui_audit/models/models.dart';

void main() {
  group('classifySpacing (Property 4)', () {
    test('aligned values match StudioSpacing constants', () {
      for (final value in [8.0, 16.0, 24.0, 32.0]) {
        expect(classifySpacing(value), SpacingClassification.aligned);
      }
    });

    test('legacy values match semantic layout spacing', () {
      for (final value in [10.0, 12.0, 14.0, 18.0]) {
        expect(classifySpacing(value), SpacingClassification.legacy);
      }
    });

    test('half-grid values are multiples of 4 within range', () {
      expect(classifySpacing(20), SpacingClassification.halfGrid);
      expect(classifySpacing(36), SpacingClassification.halfGrid);
    });

    test('non-standard values are flagged', () {
      expect(classifySpacing(7), SpacingClassification.nonStandard);
      expect(classifySpacing(15), SpacingClassification.nonStandard);
    });
  });

  group('spacingRequiresRangeJustification (Property 5)', () {
    test('flags values below 4px and above 48px', () {
      expect(spacingRequiresRangeJustification(3), isTrue);
      expect(spacingRequiresRangeJustification(49), isTrue);
      expect(spacingRequiresRangeJustification(16), isFalse);
    });
  });

  group('SpacingAnalyzer', () {
    late SpacingAnalyzer analyzer;
    late Directory tempDir;

    setUp(() {
      analyzer = SpacingAnalyzer();
      tempDir = Directory.systemTemp.createTempSync('ui_audit_spacing_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('detects hardcoded EdgeInsets.all spacing', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(15));
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.category, FindingCategory.spacing);
      expect(findings.first.description, contains('15'));
    });

    test('does not flag StudioSpacing references', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(StudioSpacing.sm));
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isEmpty);
    });

    test('flags spacing above 48px as high', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 64);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.severity, Severity.high);
      expect(findings.first.title, contains('outside acceptable range'));
    });

    test('flags micro spacing below 4px as medium', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 2);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.severity, Severity.medium);
    });

    test('detects legacy spacing with low severity', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(12));
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.severity, Severity.low);
      expect(findings.first.designSystemReference, contains('insetDense'));
    });

    test('ignores SizedBox layout dimensions when child is present', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(decoration: InputDecoration(labelText: 'Quota')),
    );
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isEmpty);
    });

    test('still flags spacer SizedBox without child', () async {
      final file = File('${tempDir.path}/widget.dart');
      file.writeAsStringSync('''
import 'package:flutter/material.dart';

class TestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 6);
  }
}
''');

      final findings = await analyzer.analyze(file.path);
      expect(findings, isNotEmpty);
      expect(findings.first.severity, Severity.medium);
    });
  });
}
