/// Tests for Visual Hierarchy Analyzer
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/visual_hierarchy_analyzer.dart';
import '../../tool/ast_parser.dart';

@Skip('Legacy frontend/tool analyzer prototype; canonical analyzer is tools/ui_audit/')
void main() {
  group('VisualHierarchyAnalyzer', () {
    test('calculateContrastRatio returns correct value for black on white', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(black, white);

      // Black on white should be 21:1
      expect(ratio, closeTo(21.0, 0.1));
    });

    test('calculateContrastRatio returns correct value for white on black', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(white, black);

      // White on black should be 21:1 (same as black on white)
      expect(ratio, closeTo(21.0, 0.1));
    });

    test('calculateContrastRatio returns 1:1 for same colors', () {
      const color = Color(0xFF7C97FF);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(color, color);

      expect(ratio, closeTo(1.0, 0.01));
    });

    test('calculateContrastRatio for textPrimary on bgBase meets WCAG AA', () {
      const textPrimary = Color(0xFFE8F1FF);
      const bgBase = Color(0xFF070D15);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(
        textPrimary,
        bgBase,
      );

      // Should meet WCAG AA for body text (>= 4.5:1)
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('calculateContrastRatio for textSecondary on bgBase meets WCAG AA', () {
      const textSecondary = Color(0xFFA2B4CD);
      const bgBase = Color(0xFF070D15);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(
        textSecondary,
        bgBase,
      );

      // Should meet WCAG AA for body text (>= 4.5:1)
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('calculateContrastRatio for textMuted on bgBase', () {
      const textMuted = Color(0xFF667892);
      const bgBase = Color(0xFF070D15);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(
        textMuted,
        bgBase,
      );

      // Check if it meets WCAG AA
      print('textMuted on bgBase contrast ratio: ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThan(1.0));
    });

    test('calculateContrastRatio for primary on bgBase', () {
      const primary = Color(0xFF7C97FF);
      const bgBase = Color(0xFF070D15);

      final ratio = VisualHierarchyAnalyzer.calculateContrastRatio(
        primary,
        bgBase,
      );

      // Check contrast for interactive elements
      print('primary on bgBase contrast ratio: ${ratio.toStringAsFixed(2)}:1');
      expect(ratio, greaterThan(1.0));
    });

    test('analyze detects hardcoded font sizes', () async {
      // Create a mock symbol table with hardcoded font size
      final symbolTable = SymbolTable();

      // Add a text widget with hardcoded font size
      symbolTable.addWidget(WidgetInfo(
        className: 'Text',
        filePath: 'test.dart',
        line: 10,
        column: 5,
        properties: {'style': 'TextStyle(fontSize: 19)'},
      ));

      // Add corresponding typography reference
      symbolTable.addTypography(TypographyReference(
        type: 'hardcoded',
        fontSize: 19,
        filePath: 'test.dart',
        line: 10,
        column: 5,
      ));

      final analyzer = VisualHierarchyAnalyzer(symbolTable);
      final findings = await analyzer.analyze();

      // Should detect hardcoded font size deviation
      expect(
        findings.any((f) => f.title.contains('Hardcoded font size')),
        isTrue,
      );
    });

    test('analyze does not flag StudioTypography references', () async {
      final symbolTable = SymbolTable();

      // Add a text widget using StudioTypography
      symbolTable.addWidget(WidgetInfo(
        className: 'Text',
        filePath: 'test.dart',
        line: 10,
        column: 5,
        properties: {'style': 'StudioTypography.of(context).body'},
      ));

      // Add corresponding typography reference
      symbolTable.addTypography(TypographyReference(
        type: 'studio-typography',
        filePath: 'test.dart',
        line: 10,
        column: 5,
        context: 'StudioTypography.body',
      ));

      final analyzer = VisualHierarchyAnalyzer(symbolTable);
      final findings = await analyzer.analyze();

      // Should not flag StudioTypography references
      expect(
        findings.any((f) => f.title.contains('Hardcoded font size')),
        isFalse,
      );
    });

    test('analyze detects heading hierarchy skips', () async {
      final symbolTable = SymbolTable();

      // Add h1 (display)
      symbolTable.addWidget(WidgetInfo(
        className: 'Text',
        filePath: 'test.dart',
        line: 10,
        column: 5,
        properties: {},
      ));
      symbolTable.addTypography(TypographyReference(
        type: 'hardcoded',
        fontSize: 30, // display level
        filePath: 'test.dart',
        line: 10,
        column: 5,
      ));

      // Add h3 (dialogTitle) - skipping h2
      symbolTable.addWidget(WidgetInfo(
        className: 'Text',
        filePath: 'test.dart',
        line: 20,
        column: 5,
        properties: {},
      ));
      symbolTable.addTypography(TypographyReference(
        type: 'hardcoded',
        fontSize: 17, // dialogTitle level
        filePath: 'test.dart',
        line: 20,
        column: 5,
      ));

      final analyzer = VisualHierarchyAnalyzer(symbolTable);
      final findings = await analyzer.analyze();

      // Should detect hierarchy skip
      expect(
        findings.any((f) => f.title.contains('Heading hierarchy skip')),
        isTrue,
      );
    });

    test('analyze detects insufficient contrast', () async {
      final symbolTable = SymbolTable();

      // Add text widget with low contrast color
      symbolTable.addWidget(WidgetInfo(
        className: 'Text',
        filePath: 'test.dart',
        line: 10,
        column: 5,
        properties: {},
      ));

      // Add typography with font size
      symbolTable.addTypography(TypographyReference(
        type: 'hardcoded',
        fontSize: 14,
        filePath: 'test.dart',
        line: 10,
        column: 5,
      ));

      // Add low contrast color (gray on dark background)
      symbolTable.addColor(ColorReference(
        type: 'hardcoded',
        value: 'Color(0xFF333333)', // Very dark gray
        filePath: 'test.dart',
        line: 10,
        column: 5,
      ));

      final analyzer = VisualHierarchyAnalyzer(symbolTable);
      final findings = await analyzer.analyze();

      // Should detect insufficient contrast
      expect(
        findings.any((f) => f.title.contains('Insufficient color contrast')),
        isTrue,
      );
    });

    test('mapToTypographyLevel correctly maps font sizes', () {
      final symbolTable = SymbolTable();
      final analyzer = VisualHierarchyAnalyzer(symbolTable);

      // Test display level
      expect(analyzer.mapToTypographyLevel(30), equals('display'));

      // Test pageTitle level
      expect(analyzer.mapToTypographyLevel(21), equals('pageTitle'));

      // Test dialogTitle level
      expect(analyzer.mapToTypographyLevel(17), equals('dialogTitle'));

      // Test cardTitle level
      expect(analyzer.mapToTypographyLevel(16), equals('cardTitle'));

      // Test body level
      expect(analyzer.mapToTypographyLevel(14), equals('body'));

      // Test hint level
      expect(analyzer.mapToTypographyLevel(13), equals('hint'));

      // Test meta level
      expect(analyzer.mapToTypographyLevel(12), equals('meta'));
    });

    test('getHeadingLevel correctly maps typography levels', () {
      final symbolTable = SymbolTable();
      final analyzer = VisualHierarchyAnalyzer(symbolTable);

      expect(analyzer.getHeadingLevel('display'), equals(1));
      expect(analyzer.getHeadingLevel('pageTitle'), equals(2));
      expect(analyzer.getHeadingLevel('dialogTitle'), equals(3));
      expect(analyzer.getHeadingLevel('projectTitle'), equals(3));
      expect(analyzer.getHeadingLevel('cardTitle'), equals(4));
      expect(analyzer.getHeadingLevel('paneTitle'), equals(4));
      expect(analyzer.getHeadingLevel('body'), equals(5));
      expect(analyzer.getHeadingLevel('hint'), equals(6));
    });

    test('matchesTypographyScale correctly identifies valid sizes', () {
      final symbolTable = SymbolTable();
      final analyzer = VisualHierarchyAnalyzer(symbolTable);

      // Valid sizes from StudioTypography
      expect(analyzer.matchesTypographyScale(28), isTrue); // display compact
      expect(analyzer.matchesTypographyScale(30), isTrue); // display regular
      expect(analyzer.matchesTypographyScale(32), isTrue); // display large
      expect(analyzer.matchesTypographyScale(20), isTrue); // pageTitle compact
      expect(analyzer.matchesTypographyScale(21), isTrue); // pageTitle regular
      expect(analyzer.matchesTypographyScale(14), isTrue); // body regular
      expect(analyzer.matchesTypographyScale(12), isTrue); // meta

      // Invalid sizes
      expect(analyzer.matchesTypographyScale(19), isFalse);
      expect(analyzer.matchesTypographyScale(23), isFalse);
      expect(analyzer.matchesTypographyScale(11), isFalse);
    });

    test('isLargeText correctly identifies large text', () {
      final symbolTable = SymbolTable();
      final analyzer = VisualHierarchyAnalyzer(symbolTable);

      // Large text: >= 24px
      expect(analyzer.isLargeText(24, null), isTrue);
      expect(analyzer.isLargeText(30, null), isTrue);

      // Large text: >= 18.66px bold
      expect(analyzer.isLargeText(19, 'FontWeight.w600'), isTrue);
      expect(analyzer.isLargeText(19, 'FontWeight.w700'), isTrue);
      expect(analyzer.isLargeText(19, 'w600'), isTrue);
      expect(analyzer.isLargeText(19, 'bold'), isTrue);

      // Not large text
      expect(analyzer.isLargeText(14, null), isFalse);
      expect(analyzer.isLargeText(14, 'FontWeight.w400'), isFalse);
      expect(analyzer.isLargeText(18, 'FontWeight.w400'), isFalse);
    });

    test('meetsWCAG_AA correctly validates contrast ratios', () {
      final symbolTable = SymbolTable();
      final analyzer = VisualHierarchyAnalyzer(symbolTable);

      // Body text needs 4.5:1
      expect(analyzer.meetsWCAG_AA(4.5, false), isTrue);
      expect(analyzer.meetsWCAG_AA(4.4, false), isFalse);

      // Large text needs 3:1
      expect(analyzer.meetsWCAG_AA(3.0, true), isTrue);
      expect(analyzer.meetsWCAG_AA(2.9, true), isFalse);

      // High contrast passes both
      expect(analyzer.meetsWCAG_AA(7.0, false), isTrue);
      expect(analyzer.meetsWCAG_AA(7.0, true), isTrue);
    });
  }, skip: 'Legacy frontend/tool analyzer prototype; canonical analyzer is tools/ui_audit/');
}
