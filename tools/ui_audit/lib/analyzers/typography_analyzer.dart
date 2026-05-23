import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

const _allowedFontWeights = {
  'w400',
  'w500',
  'w600',
  'w700',
  'FontWeight.w400',
  'FontWeight.w500',
  'FontWeight.w600',
  'FontWeight.w700',
  'FontWeight.normal',
  'FontWeight.bold',
};

const _allowedTextColors = {
  'textPrimary',
  'textSecondary',
  'textMuted',
  'danger',
  'success',
  'warning',
  'primary',
  'accent',
  'primarySoft',
  'onPrimary',
};

const _allowedSemanticColorIdentifiers = {
  'muted',
  'hintColor',
  'textColor',
  'resolvedForeground',
  'accentColor',
  'foregroundColor',
  'errorColor',
  'statusColor',
  'iconColor',
};

const _allowedColorSchemeRoles = {
  'colorScheme.error',
  'colorScheme.onError',
  'colorScheme.errorContainer',
  'colorScheme.onErrorContainer',
  'colorScheme.onPrimary',
  'colorScheme.onPrimaryContainer',
  'colorScheme.primary',
};

/// True when [source] references the Studio typography scale (direct or local var).
bool referencesTypographyScale(String source) {
  return source.contains('StudioTypography') ||
      RegExp(r'\btypography(\?)?\.').hasMatch(source);
}

/// True when [source] references semantic text color tokens.
bool referencesTextColorTokens(String source) {
  return source.contains('StudioTokens') ||
      source.contains('tokens.') ||
      _allowedTextColors.any(source.contains) ||
      RegExp(r'\btextColor\b').hasMatch(source);
}

/// Validates typography usage against [StudioTypography] and text color tokens.
class TypographyAnalyzer extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  TypographyAnalyzer({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.typography;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }
    if (parsed.filePath.endsWith('design_system/components/studio_text_styles.dart')) {
      return [];
    }

    final visitor = _TypographyVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'TY-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _TypographyVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final TypographyAnalyzer analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};

  _TypographyVisitor(this.parsed, this.analyzer);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toSource() == 'TextStyle') {
      _analyzeTextStyle(node, node.argumentList.arguments);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (constructionNameFromMethodInvocation(node) == 'TextStyle') {
      _analyzeTextStyle(node, node.argumentList.arguments);
    }
    super.visitMethodInvocation(node);
  }

  void _analyzeTextStyle(AstNode node, NodeList<Expression> args) {
    final source = node.toSource();
    if (referencesTypographyScale(source) &&
        !RegExp(r'fontSize:\s*\d').hasMatch(source) &&
        !RegExp(r'letterSpacing:\s*\d').hasMatch(source)) {
      // Entire style uses scale vars; only check line-height / weight edge cases below.
    } else if (source.contains('StudioTypography') &&
        !RegExp(r'fontSize:\s*\d').hasMatch(source)) {
      return;
    }

    var hasHardcodedTypography = false;

    for (final arg in args) {
      if (arg is! NamedExpression) {
        continue;
      }

      final name = arg.name.label.name;
      final exprSource = arg.expression.toSource();

      switch (name) {
        case 'fontSize':
        case 'letterSpacing':
          if (!referencesTypographyScale(exprSource) &&
              extractNumericLiteral(arg.expression) != null) {
            hasHardcodedTypography = true;
          }
        case 'height':
          final height = extractNumericLiteral(arg.expression);
          if (height != null && (height < 1.0 || height > 1.5)) {
            _report(
              node,
              title: 'Line-height outside recommended range',
              description:
                  'TextStyle height $height should be between 1.2 and 1.5 for readability',
              severity: Severity.medium,
              recommendation:
                  'Use line height between 1.2 and 1.5 per StudioTypography guidance',
              designRef: 'StudioTypography',
            );
          }
        case 'fontFamily':
          if (!_isAllowedFontFamily(exprSource)) {
            _report(
              node,
              title: 'Non-standard font family',
              description: 'TextStyle uses fontFamily: $exprSource',
              severity: Severity.medium,
              recommendation:
                  'Use Inter for body text and Space Grotesk for display (see StudioTypography)',
              designRef: 'Google Fonts: Inter / Space Grotesk',
            );
          }
        case 'fontWeight':
          if (!_isAllowedFontWeight(exprSource)) {
            _report(
              node,
              title: 'Non-standard font weight',
              description: 'TextStyle uses fontWeight: $exprSource',
              severity: Severity.low,
              recommendation: 'Use FontWeight.w400, w500, w600, or w700',
              designRef: 'StudioTypography font weights',
            );
          }
        case 'color':
          if (_isHardcodedColor(exprSource)) {
            final severity = referencesTypographyScale(source)
                ? Severity.low
                : Severity.high;
            _report(
              node,
              title: 'Text color not using StudioTokens',
              description: 'TextStyle color uses hardcoded value: $exprSource',
              severity: severity,
              recommendation:
                  'Use StudioTokens.of(context).textPrimary, textSecondary, or textMuted',
              designRef: 'StudioTokens.textPrimary',
            );
          } else if (!_usesAllowedTextColor(exprSource) &&
              !referencesTextColorTokens(exprSource)) {
            _report(
              node,
              title: 'Unexpected text color token',
              description: 'TextStyle color: $exprSource',
              severity: Severity.medium,
              recommendation:
                  'Prefer textPrimary, textSecondary, or textMuted semantic tokens',
              designRef: 'StudioTokens text colors',
            );
          }
      }
    }

    if (hasHardcodedTypography) {
      _report(
        node,
        title: 'TextStyle without StudioTypography reference',
        description:
            'TextStyle uses hardcoded typography values instead of StudioTypography scale',
        severity: Severity.high,
        recommendation: 'Use StudioTypography.of(context) for font sizes and spacing',
        designRef: 'StudioTypography',
      );
    }
  }

  bool _isAllowedFontFamily(String source) {
    return source.contains('Inter') ||
        source.contains('Space Grotesk') ||
        source.contains('SpaceGrotesk') ||
        source.contains('StudioTypography') ||
        source.contains("'monospace'") ||
        source.contains('"monospace"');
  }

  bool _isAllowedFontWeight(String source) {
    return _allowedFontWeights.any(source.contains) ||
        RegExp(r'FontWeight\.w[4-7]00').hasMatch(source);
  }

  bool _isHardcodedColor(String source) {
    return source.contains('Color(') ||
        source.contains('Colors.') ||
        RegExp(r'0x[0-9A-Fa-f]{6,8}').hasMatch(source) ||
        RegExp(r'#[0-9A-Fa-f]{6,8}').hasMatch(source);
  }

  bool _usesAllowedTextColor(String source) {
    if (source.contains('studioMutedTextColor') ||
        source.contains('qualityReviewsMutedColor') ||
        source.contains('studioHintStyle') ||
        source.contains('studioSectionIntroStyle') ||
        source.contains('studioAccentBanner')) {
      return true;
    }
    if (_allowedSemanticColorIdentifiers.any(
      (id) => RegExp('\\b$id\\b').hasMatch(source),
    )) {
      return true;
    }
    if (_allowedColorSchemeRoles.any(source.contains)) {
      return true;
    }
    if (!source.contains('StudioTokens') && !source.contains('tokens.')) {
      return false;
    }
    return _allowedTextColors.any(source.contains);
  }

  void _report(
    AstNode node, {
    required String title,
    required String description,
    required Severity severity,
    required String recommendation,
    required String designRef,
  }) {
    final key = '${node.offset}:$title';
    if (_reported.contains(key)) {
      return;
    }
    _reported.add(key);

    findings.add(
      Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.typography,
        severity: severity,
        title: title,
        description: description,
        location: parsed.atOffset(node.offset),
        codeSnippet: node.toSource().length > 120
            ? '${node.toSource().substring(0, 120)}...'
            : node.toSource(),
        recommendation: recommendation,
        designSystemReference: designRef,
        effort: Effort.small,
      ),
    );
  }
}
