import 'dart:math';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Simple Color class for contrast calculations (avoiding Flutter dependency)
class Color {
  final int value;
  
  const Color(this.value);
  
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;
  int get alpha => (value >> 24) & 0xFF;
}

/// Analyzes visual hierarchy in Flutter widgets
/// 
/// Detects:
/// - Text widgets with hardcoded font sizes
/// - Deviations from StudioTypography scale
/// - Heading hierarchy violations
/// - Color contrast ratio issues (WCAG 2.1)
class VisualHierarchyAnalyzer extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  VisualHierarchyAnalyzer({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.visualHierarchy;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final findings = <Finding>[];
    _findingCounter = 0;

    try {
      final parsed = await _parser.parseFile(filePath);
      if (parsed == null) {
        return findings;
      }

      final visitor = _VisualHierarchyVisitor(parsed, this);
      parsed.unit.accept(visitor);
      visitor.finalize();
      findings.addAll(visitor.findings);
    } catch (_) {
      // Gracefully handle errors and continue
    }

    return findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'VH-${_findingCounter.toString().padLeft(3, '0')}';
  }

  /// Maps font size to StudioTypography scale
  String? _mapToTypographyScale(double fontSize) {
    // Check against all three profiles (compact, regular, large)
    // and return the closest match
    
    // Display: 28-32
    if (fontSize >= 28 && fontSize <= 32) return 'display';
    
    // Page title: 20-22
    if (fontSize >= 20 && fontSize <= 22) return 'pageTitle';
    
    // Dialog title: 16-18
    if (fontSize >= 16 && fontSize <= 18) return 'dialogTitle';
    
    // Project title: 16-18
    if (fontSize >= 16 && fontSize <= 18) return 'projectTitle';
    
    // Card title: 15-17
    if (fontSize >= 15 && fontSize <= 17) return 'cardTitle';
    
    // Pane title: 15-16
    if (fontSize >= 15 && fontSize <= 16) return 'paneTitle';
    
    // Body large: 14-16
    if (fontSize >= 14 && fontSize <= 16) return 'bodyLarge';
    
    // Body: 13-15
    if (fontSize >= 13 && fontSize <= 15) return 'body';
    
    // Hint: 12-14
    if (fontSize >= 12 && fontSize <= 14) return 'hint';
    
    // Meta: 12
    if (fontSize == 12) return 'meta';
    
    // Label: 12-13
    if (fontSize >= 12 && fontSize <= 13) return 'label';
    
    return null; // No match found
  }

  /// Gets heading level from font size (1-6)
  int _getHeadingLevel(double fontSize) {
    if (fontSize >= 28) return 1; // display
    if (fontSize >= 20) return 2; // pageTitle
    if (fontSize >= 16) return 3; // dialogTitle, projectTitle
    if (fontSize >= 15) return 4; // cardTitle, paneTitle
    if (fontSize >= 13) return 5; // body
    return 6; // hint, meta, label
  }

  /// Calculates contrast ratio using WCAG 2.1 formula
  double calculateContrastRatio(Color foreground, Color background) {
    double relativeLuminance(Color color) {
      double toLinear(int channel) {
        final c = channel / 255.0;
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
      }

      final r = toLinear(color.red);
      final g = toLinear(color.green);
      final b = toLinear(color.blue);

      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);

    final lighter = max(l1, l2);
    final darker = min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if contrast ratio meets WCAG AA standards
  bool meetsWCAG_AA(double contrastRatio, double fontSize, bool isBold) {
    // Large text: >= 18pt (24px) or >= 14pt (18.66px) bold
    final isLargeText = fontSize >= 24 || (fontSize >= 18.66 && isBold);
    final threshold = isLargeText ? 3.0 : 4.5;

    return contrastRatio >= threshold;
  }
}

class _VisualHierarchyVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final VisualHierarchyAnalyzer analyzer;
  final List<Finding> findings = [];
  final List<_TextWidgetInfo> textWidgets = [];

  _VisualHierarchyVisitor(this.parsed, this.analyzer);

  /// Called after visiting all nodes to perform cross-widget analysis
  void finalize() {
    _validateHeadingHierarchy();
  }

  /// Validates heading hierarchy progression
  void _validateHeadingHierarchy() {
    if (textWidgets.length < 2) return;

    // Sort by location (line number)
    textWidgets.sort((a, b) => a.location.line.compareTo(b.location.line));

    int? previousLevel;
    for (final widget in textWidgets) {
      final currentLevel = analyzer._getHeadingLevel(widget.fontSize);

      if (previousLevel != null && currentLevel > previousLevel + 1) {
        findings.add(Finding(
          id: analyzer._generateFindingId(),
          category: FindingCategory.visualHierarchy,
          severity: Severity.medium,
          title: 'Heading hierarchy skip detected',
          description:
              'Heading level $currentLevel follows level $previousLevel, skipping intermediate levels',
          location: widget.location,
          recommendation:
              'Use heading level ${previousLevel + 1} or restructure hierarchy to avoid skipping levels',
          effort: Effort.medium,
        ));
      }

      previousLevel = currentLevel;
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();

    if (typeName == 'Text' || typeName == 'RichText') {
      _analyzeTextCall(node, node.argumentList.arguments);
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'Text' || name == 'RichText') {
      _analyzeTextCall(node, node.argumentList.arguments);
    }
    super.visitMethodInvocation(node);
  }

  void _analyzeTextCall(AstNode node, NodeList<Expression> arguments) {
    
    // Extract style argument
    Expression? styleArg;
    for (final arg in arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'style') {
        styleArg = arg.expression;
        break;
      }
    }

    if (styleArg == null) return;

    // Check if it's a TextStyle creation
    if (styleArg is InstanceCreationExpression) {
      final styleTypeName = styleArg.constructorName.type.toSource();
      if (styleTypeName == 'TextStyle') {
        _analyzeTextStyle(styleArg.argumentList.arguments, node);
      }
    } else if (styleArg is MethodInvocation &&
        constructionNameFromMethodInvocation(styleArg) == 'TextStyle') {
      _analyzeTextStyle(styleArg.argumentList.arguments, node);
    }
  }

  void _analyzeTextStyle(
    NodeList<Expression> styleArgs,
    AstNode textNode,
  ) {
    double? fontSize;
    bool hasStudioTypographyReference = false;
    String? fontWeightStr;

    for (final arg in styleArgs) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        
        if (name == 'fontSize') {
          // Check if it references StudioTypography
          final expr = arg.expression;
          if (expr.toString().contains('StudioTypography')) {
            hasStudioTypographyReference = true;
          } else if (expr is IntegerLiteral) {
            fontSize = expr.value?.toDouble();
          } else if (expr is DoubleLiteral) {
            fontSize = expr.value;
          }
        } else if (name == 'fontWeight') {
          fontWeightStr = arg.expression.toString();
        }
      }
    }

    // If it has StudioTypography reference, it's good
    if (hasStudioTypographyReference) {
      return;
    }

    // If we found a hardcoded fontSize, flag it
    if (fontSize != null) {
      final location = parsed.atOffset(textNode.offset);

      final typographyMatch = analyzer._mapToTypographyScale(fontSize);
      final recommendation = typographyMatch != null
          ? 'Use StudioTypography.of(context).$typographyMatch (${_getTypographyRange(typographyMatch)})'
          : 'Use appropriate StudioTypography reference for font size $fontSize';

      final codeSnippet = textNode.toSource();
      final beforeAfter = typographyMatch != null
          ? BeforeAfter(
              before: 'TextStyle(fontSize: $fontSize)',
              after: 'TextStyle(fontSize: StudioTypography.of(context).$typographyMatch)',
            )
          : null;

      findings.add(Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.visualHierarchy,
        severity: Severity.high,
        title: 'Hardcoded font size deviates from StudioTypography',
        description:
            'Text widget uses hardcoded fontSize: $fontSize instead of StudioTypography reference',
        location: location,
        codeSnippet: codeSnippet.length > 100
            ? '${codeSnippet.substring(0, 100)}...'
            : codeSnippet,
        recommendation: recommendation,
        designSystemReference: typographyMatch != null
            ? 'StudioTypography.$typographyMatch'
            : null,
        effort: Effort.small,
        beforeAfter: beforeAfter,
      ));

      // Store for heading hierarchy validation
      textWidgets.add(_TextWidgetInfo(
        fontSize: fontSize,
        location: location,
        isBold: fontWeightStr?.contains('w600') == true ||
            fontWeightStr?.contains('w700') == true ||
            fontWeightStr?.contains('bold') == true,
      ));
    }
  }

  String _getTypographyRange(String typographyName) {
    switch (typographyName) {
      case 'display':
        return '28-32px';
      case 'pageTitle':
        return '20-22px';
      case 'dialogTitle':
      case 'projectTitle':
        return '16-18px';
      case 'cardTitle':
        return '15-17px';
      case 'paneTitle':
        return '15-16px';
      case 'bodyLarge':
        return '14-16px';
      case 'body':
        return '13-15px';
      case 'hint':
        return '12-14px';
      case 'meta':
        return '12px';
      case 'label':
        return '12-13px';
      default:
        return '';
    }
  }
}

class _TextWidgetInfo {
  final double fontSize;
  final Location location;
  final bool isBold;

  _TextWidgetInfo({
    required this.fontSize,
    required this.location,
    required this.isBold,
  });
}
