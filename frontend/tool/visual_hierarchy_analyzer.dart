/// Visual Hierarchy Analyzer for Flutter UI/UX Audit
///
/// This module analyzes visual hierarchy across Flutter screens by:
/// - Detecting text widgets and extracting font properties
/// - Mapping text widgets to StudioTypography scale
/// - Validating heading hierarchy progression
/// - Calculating color contrast ratios using WCAG 2.1 formula
/// - Flagging contrast violations
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'ast_parser.dart';

/// Represents a text widget with its visual hierarchy properties
class TextWidgetInfo {
  /// Widget class name (usually 'Text')
  final String className;

  /// File path where the widget is defined
  final String filePath;

  /// Line number
  final int line;

  /// Column number
  final int column;

  /// Font size (if available)
  final double? fontSize;

  /// Font weight (if available)
  final String? fontWeight;

  /// Font style (if available)
  final String? fontStyle;

  /// Line height (if available)
  final double? lineHeight;

  /// Text color (if available)
  final Color? textColor;

  /// Background color (if available)
  final Color? backgroundColor;

  /// Mapped typography level (e.g., 'pageTitle', 'body', 'hint')
  final String? typographyLevel;

  /// Whether this uses StudioTypography reference
  final bool usesStudioTypography;

  /// Widget hierarchy path
  final String? widgetPath;

  TextWidgetInfo({
    required this.className,
    required this.filePath,
    required this.line,
    required this.column,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.lineHeight,
    this.textColor,
    this.backgroundColor,
    this.typographyLevel,
    this.usesStudioTypography = false,
    this.widgetPath,
  });

  @override
  String toString() {
    return 'TextWidgetInfo($className at $filePath:$line:$column, '
        'fontSize: $fontSize, level: $typographyLevel)';
  }
}

/// Represents a visual hierarchy finding
class VisualHierarchyFinding {
  /// Finding ID (e.g., 'VH-001')
  final String id;

  /// Severity: 'critical', 'high', 'medium', 'low'
  final String severity;

  /// Finding title
  final String title;

  /// Detailed description
  final String description;

  /// File path
  final String filePath;

  /// Line number
  final int line;

  /// Column number
  final int column;

  /// Code snippet (if available)
  final String? codeSnippet;

  /// Recommendation
  final String recommendation;

  /// Design system reference
  final String? designSystemReference;

  /// Effort: 'small', 'medium', 'large'
  final String effort;

  VisualHierarchyFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.description,
    required this.filePath,
    required this.line,
    required this.column,
    this.codeSnippet,
    required this.recommendation,
    this.designSystemReference,
    this.effort = 'small',
  });

  @override
  String toString() {
    return 'Finding($id: $title at $filePath:$line)';
  }
}

/// Visual Hierarchy Analyzer
class VisualHierarchyAnalyzer {
  final SymbolTable symbolTable;
  final List<VisualHierarchyFinding> findings = [];
  int _findingCounter = 0;

  VisualHierarchyAnalyzer(this.symbolTable);

  /// Run the visual hierarchy analysis
  Future<List<VisualHierarchyFinding>> analyze() async {
    print('Starting visual hierarchy analysis...');

    // Extract text widgets from symbol table
    final textWidgets = _extractTextWidgets();
    print('Found ${textWidgets.length} text widgets');

    // Analyze font size deviations
    _analyzeFontSizeDeviations(textWidgets);

    // Validate heading hierarchy
    _validateHeadingHierarchy(textWidgets);

    // Analyze contrast ratios
    _analyzeContrastRatios(textWidgets);

    // Analyze font weights
    _analyzeFontWeights(textWidgets);

    print('Visual hierarchy analysis complete: ${findings.length} findings');
    return findings;
  }

  /// Extract text widgets from symbol table
  List<TextWidgetInfo> _extractTextWidgets() {
    final textWidgets = <TextWidgetInfo>[];

    for (final widget in symbolTable.widgets) {
      if (widget.className == 'Text') {
        // Extract font properties from widget properties
        double? fontSize;
        String? fontWeight;
        String? fontStyle;
        double? lineHeight;
        Color? textColor;
        bool usesStudioTypography = false;

        // Check if style property exists
        final style = widget.properties['style'];
        if (style != null) {
          // Check if it's a StudioTypography reference
          if (style.toString().contains('StudioTypography')) {
            usesStudioTypography = true;
          }
        }

        // Look for corresponding typography reference in symbol table
        final typoRefs = symbolTable.typography.where(
          (ref) =>
              ref.filePath == widget.filePath &&
              ref.line == widget.line &&
              ref.column == widget.column,
        );

        if (typoRefs.isNotEmpty) {
          final typoRef = typoRefs.first;
          fontSize = typoRef.fontSize;
          fontWeight = typoRef.fontWeight;
          lineHeight = typoRef.lineHeight;
          usesStudioTypography = typoRef.type == 'studio-typography';
        }

        // Look for color references
        final colorRefs = symbolTable.colors.where(
          (ref) =>
              ref.filePath == widget.filePath &&
              ref.line >= widget.line - 2 &&
              ref.line <= widget.line + 2,
        );

        if (colorRefs.isNotEmpty) {
          final colorRef = colorRefs.first;
          textColor = _parseColor(colorRef.value);
        }

        // Map to typography level
        String? typographyLevel;
        if (fontSize != null) {
          typographyLevel = _mapToTypographyLevel(fontSize);
        }

        textWidgets.add(TextWidgetInfo(
          className: widget.className,
          filePath: widget.filePath,
          line: widget.line,
          column: widget.column,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          lineHeight: lineHeight,
          textColor: textColor,
          typographyLevel: typographyLevel,
          usesStudioTypography: usesStudioTypography,
          widgetPath: widget.widgetPath,
        ));
      }
    }

    return textWidgets;
  }

  /// Map font size to StudioTypography level
  @visibleForTesting
  String mapToTypographyLevel(double fontSize) {
    // Based on StudioTypography scale (using regular profile as reference)
    if (fontSize >= 28) return 'display'; // 28-32
    if (fontSize >= 20) return 'pageTitle'; // 20-22
    if (fontSize >= 17) return 'dialogTitle'; // 16-18
    if (fontSize >= 16) return 'projectTitle'; // 16-18
    if (fontSize >= 15) return 'cardTitle'; // 15-17
    if (fontSize >= 14) return 'body'; // 13-15
    if (fontSize >= 13) return 'bodyLarge'; // 14-16
    if (fontSize >= 12) return 'hint'; // 12-14
    return 'meta'; // 12
  }

  /// Get heading level from typography level
  @visibleForTesting
  int getHeadingLevel(String? typographyLevel) {
    switch (typographyLevel) {
      case 'display':
        return 1;
      case 'pageTitle':
        return 2;
      case 'dialogTitle':
      case 'projectTitle':
        return 3;
      case 'cardTitle':
      case 'paneTitle':
        return 4;
      case 'body':
      case 'bodyLarge':
        return 5;
      default:
        return 6;
    }
  }

  /// Analyze font size deviations from StudioTypography
  void _analyzeFontSizeDeviations(List<TextWidgetInfo> textWidgets) {
    for (final widget in textWidgets) {
      // Skip if already using StudioTypography
      if (widget.usesStudioTypography) continue;

      // Skip if no font size
      if (widget.fontSize == null) continue;

      // Check if font size matches any StudioTypography value
      final fontSize = widget.fontSize!;
      final matchesTypography = _matchesTypographyScale(fontSize);

      if (!matchesTypography) {
        findings.add(VisualHierarchyFinding(
          id: 'VH-${_findingCounter++.toString().padLeft(3, '0')}',
          severity: 'high',
          title: 'Hardcoded font size deviates from StudioTypography',
          description:
              'Text widget uses hardcoded fontSize: $fontSize instead of StudioTypography reference',
          filePath: widget.filePath,
          line: widget.line,
          column: widget.column,
          recommendation:
              'Use StudioTypography.of(context).${widget.typographyLevel ?? 'body'}',
          designSystemReference: 'StudioTypography.${widget.typographyLevel ?? 'body'}',
          effort: 'small',
        ));
      }
    }
  }

  /// Check if font size matches StudioTypography scale
  @visibleForTesting
  bool matchesTypographyScale(double fontSize) {
    // StudioTypography values across all profiles
    const typographyValues = [
      // display
      28, 30, 32,
      // pageTitle
      20, 21, 22,
      // dialogTitle, projectTitle
      16, 17, 18,
      // cardTitle, paneTitle
      15, 16, 17,
      // bodyLarge
      14, 15, 16,
      // body
      13, 14, 15,
      // hint, label
      12, 13, 14,
      // meta
      12,
    ];

    return typographyValues.contains(fontSize.toInt());
  }

  /// Validate heading hierarchy progression
  void _validateHeadingHierarchy(List<TextWidgetInfo> textWidgets) {
    // Group by file
    final byFile = <String, List<TextWidgetInfo>>{};
    for (final widget in textWidgets) {
      byFile.putIfAbsent(widget.filePath, () => []).add(widget);
    }

    // Validate hierarchy in each file
    for (final entry in byFile.entries) {
      final filePath = entry.key;
      final widgets = entry.value;

      // Sort by line number
      widgets.sort((a, b) => a.line.compareTo(b.line));

      int? previousLevel;
      for (final widget in widgets) {
        final currentLevel = _getHeadingLevel(widget.typographyLevel);

        // Only check heading levels (1-4)
        if (currentLevel <= 4 && previousLevel != null) {
          if (currentLevel > previousLevel + 1) {
            findings.add(VisualHierarchyFinding(
              id: 'VH-${_findingCounter++.toString().padLeft(3, '0')}',
              severity: 'medium',
              title: 'Heading hierarchy skip detected',
              description:
                  'Heading level $currentLevel (${widget.typographyLevel}) follows level $previousLevel, skipping intermediate levels',
              filePath: filePath,
              line: widget.line,
              column: widget.column,
              recommendation:
                  'Use heading level ${previousLevel + 1} or restructure hierarchy',
              effort: 'medium',
            ));
          }
        }

        if (currentLevel <= 4) {
          previousLevel = currentLevel;
        }
      }
    }
  }

  /// Analyze contrast ratios
  void _analyzeContrastRatios(List<TextWidgetInfo> textWidgets) {
    for (final widget in textWidgets) {
      // Skip if no color information
      if (widget.textColor == null) continue;

      // Use default background if not specified
      final backgroundColor =
          widget.backgroundColor ?? const Color(0xFF070D15); // bgBase

      final contrastRatio =
          calculateContrastRatio(widget.textColor!, backgroundColor);

      // Determine if it's large text
      final isLargeText = _isLargeText(widget.fontSize, widget.fontWeight);

      // Check WCAG AA compliance
      final meetsWCAG = _meetsWCAG_AA(contrastRatio, isLargeText);

      if (!meetsWCAG) {
        final threshold = isLargeText ? 3.0 : 4.5;
        findings.add(VisualHierarchyFinding(
          id: 'VH-${_findingCounter++.toString().padLeft(3, '0')}',
          severity: 'high',
          title: 'Insufficient color contrast',
          description:
              'Text has contrast ratio of ${contrastRatio.toStringAsFixed(2)}:1, '
              'below WCAG AA threshold of $threshold:1 for ${isLargeText ? 'large' : 'body'} text',
          filePath: widget.filePath,
          line: widget.line,
          column: widget.column,
          recommendation:
              'Use StudioTokens colors with sufficient contrast (textPrimary, textSecondary, or textMuted)',
          designSystemReference: 'StudioTokens.textPrimary',
          effort: 'small',
        ));
      }
    }
  }

  /// Analyze font weights
  void _analyzeFontWeights(List<TextWidgetInfo> textWidgets) {
    for (final widget in textWidgets) {
      if (widget.fontWeight == null) continue;

      // Check if font weight is valid (w400, w500, w600, w700)
      final validWeights = ['w400', 'w500', 'w600', 'w700', 'FontWeight.w400',
        'FontWeight.w500', 'FontWeight.w600', 'FontWeight.w700',
        'FontWeight.normal', 'FontWeight.bold'];

      final fontWeight = widget.fontWeight!;
      final isValid = validWeights.any((w) => fontWeight.contains(w));

      if (!isValid) {
        findings.add(VisualHierarchyFinding(
          id: 'VH-${_findingCounter++.toString().padLeft(3, '0')}',
          severity: 'low',
          title: 'Non-standard font weight',
          description: 'Text uses font weight $fontWeight not in design system',
          filePath: widget.filePath,
          line: widget.line,
          column: widget.column,
          recommendation:
              'Use standard font weights: w400 (normal), w500 (medium), w600 (semibold), w700 (bold)',
          effort: 'small',
        ));
      }
    }
  }

  /// Calculate contrast ratio using WCAG 2.1 formula
  static double calculateContrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);

    final lighter = max(l1, l2);
    final darker = min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance
  static double _relativeLuminance(Color color) {
    double toLinear(int channel) {
      final c = channel / 255.0;
      return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = toLinear(color.red);
    final g = toLinear(color.green);
    final b = toLinear(color.blue);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Check if text is considered large (>= 18pt or >= 14pt bold)
  @visibleForTesting
  bool isLargeText(double? fontSize, String? fontWeight) {
    if (fontSize == null) return false;

    // Large text: >= 18pt (24px) or >= 14pt (18.66px) bold
    final isBold = fontWeight != null &&
        (fontWeight.contains('w600') ||
            fontWeight.contains('w700') ||
            fontWeight.contains('bold'));

    return fontSize >= 24 || (fontSize >= 18.66 && isBold);
  }

  /// Check if contrast ratio meets WCAG AA standards
  @visibleForTesting
  bool meetsWCAG_AA(double contrastRatio, bool isLargeText) {
    final threshold = isLargeText ? 3.0 : 4.5;
    return contrastRatio >= threshold;
  }

  /// Parse color from string representation
  Color? _parseColor(String colorStr) {
    try {
      // Handle Color(0xFF7C97FF) format
      if (colorStr.startsWith('Color(0x')) {
        final hexStr = colorStr.substring(8, colorStr.length - 1);
        final value = int.parse(hexStr, radix: 16);
        return Color(value);
      }

      // Handle Colors.blue format
      if (colorStr.startsWith('Colors.')) {
        // Return null for now, would need color mapping
        return null;
      }

      // Handle StudioTokens format
      if (colorStr.startsWith('StudioTokens.')) {
        // Map to actual color values from tokens.dart
        final tokenName = colorStr.split('.').last;
        return _getTokenColor(tokenName);
      }
    } catch (e) {
      // Ignore parsing errors
    }

    return null;
  }

  /// Get color from StudioTokens
  Color? _getTokenColor(String tokenName) {
    // Map token names to actual colors from StudioTokens.dark
    const tokenColors = {
      'bgBase': Color(0xFF070D15),
      'bgSurface': Color(0xFF101825),
      'bgElevated': Color(0xFF152033),
      'bgInset': Color(0xFF0A1018),
      'textPrimary': Color(0xFFE8F1FF),
      'textSecondary': Color(0xFFA2B4CD),
      'textMuted': Color(0xFF667892),
      'primary': Color(0xFF7C97FF),
      'accent': Color(0xFF34C8F0),
      'danger': Color(0xFFFF6D7A),
      'warning': Color(0xFFFFB347),
      'success': Color(0xFF35D49B),
    };

    return tokenColors[tokenName];
  }
}
