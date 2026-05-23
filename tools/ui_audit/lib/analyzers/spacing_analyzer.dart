import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Classifies spacing values against the Studio 8px grid and legacy tokens.
SpacingClassification classifySpacing(double value) {
  const studioSpacing = <double>[8, 16, 24, 32];
  const legacySpacing = <double>[10, 12, 14, 18];

  if (studioSpacing.contains(value)) {
    return SpacingClassification.aligned;
  }
  if (legacySpacing.contains(value)) {
    return SpacingClassification.legacy;
  }
  if (value % 4 == 0 && value >= 4 && value <= 48) {
    return SpacingClassification.halfGrid;
  }
  return SpacingClassification.nonStandard;
}

/// Whether a spacing value is outside the acceptable 4–48px audit range.
bool spacingRequiresRangeJustification(double value) {
  return value < 4 || value > 48;
}

/// Analyzes padding, margin, gap, and SizedBox spacing in Dart source.
class SpacingAnalyzer extends StaticAnalyzer {
  int _findingCounter = 0;

  final AstParser _parser;

  SpacingAnalyzer({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.spacing;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _SpacingVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'SP-${_findingCounter.toString().padLeft(3, '0')}';
  }

  String _recommendationFor(double value, SpacingClassification classification) {
    switch (classification) {
      case SpacingClassification.aligned:
        return 'Already aligned with StudioSpacing';
      case SpacingClassification.legacy:
        return 'Replace legacy value $value with StudioSpacing or StudioLayoutSpacing semantic constant';
      case SpacingClassification.halfGrid:
        return 'Prefer StudioSpacing constant nearest to $value (xs=8, sm=16, md=24, lg=32)';
      case SpacingClassification.nonStandard:
        return 'Use StudioSpacing (xs=8, sm=16, md=24, lg=32) or StudioLayoutSpacing semantic value';
    }
  }

  String? _designSystemReferenceFor(double value) {
    return switch (value) {
      8 => 'StudioSpacing.xs',
      16 => 'StudioSpacing.sm',
      24 => 'StudioSpacing.md',
      32 => 'StudioSpacing.lg',
      10 => 'StudioLayoutSpacing.inlineGap',
      12 => 'StudioLayoutSpacing.insetDense',
      14 => 'StudioLayoutSpacing.stackMedium',
      18 => 'StudioLayoutSpacing.insetComfortable',
      _ => null,
    };
  }
}

class _SpacingVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final SpacingAnalyzer analyzer;
  final List<Finding> findings = [];
  final Set<String> _reportedAtOffset = {};

  _SpacingVisitor(this.parsed, this.analyzer);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();

    switch (typeName) {
      case 'EdgeInsets':
        _analyzeEdgeInsets(node, node.constructorName.name?.name);
      case 'SizedBox':
        _analyzeSizedBox(node);
      default:
        break;
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'SizedBox') {
      _analyzeSizedBox(node);
    } else if (name != null && name.startsWith('EdgeInsets.')) {
      final ctor = name.substring('EdgeInsets.'.length);
      _analyzeEdgeInsets(node, ctor);
    }
    super.visitMethodInvocation(node);
  }

  void _analyzeEdgeInsets(AstNode node, String? constructor) {
    if (constructor == null) {
      return;
    }

    if (node is! InstanceCreationExpression && node is! MethodInvocation) {
      return;
    }

    final arguments = node is InstanceCreationExpression
        ? node.argumentList.arguments
        : (node as MethodInvocation).argumentList.arguments;

    switch (constructor) {
      case 'all':
        if (arguments.isNotEmpty) {
          _checkSpacingArgument(
            node,
            arguments.first,
            context: 'EdgeInsets.all',
          );
        }
      case 'symmetric':
        for (final arg in arguments) {
          if (arg is NamedExpression &&
              (arg.name.label.name == 'horizontal' ||
                  arg.name.label.name == 'vertical')) {
            _checkSpacingArgument(node, arg.expression, context: 'EdgeInsets.symmetric');
          }
        }
      case 'only':
        for (final arg in arguments) {
          if (arg is NamedExpression) {
            _checkSpacingArgument(node, arg.expression, context: 'EdgeInsets.only');
          }
        }
      default:
        for (final arg in arguments) {
          _checkSpacingArgument(node, arg, context: 'EdgeInsets');
        }
    }
  }

  void _analyzeSizedBox(AstNode node) {
    if (node is! InstanceCreationExpression && node is! MethodInvocation) {
      return;
    }

    if (_sizedBoxHasChild(node)) {
      return;
    }

    final arguments = node is InstanceCreationExpression
        ? node.argumentList.arguments
        : (node as MethodInvocation).argumentList.arguments;

    for (final arg in arguments) {
      if (arg is NamedExpression &&
          (arg.name.label.name == 'width' || arg.name.label.name == 'height')) {
        _checkSpacingArgument(
          node,
          arg.expression,
          context: 'SizedBox.${arg.name.label.name}',
        );
      }
    }
  }

  bool _sizedBoxHasChild(AstNode node) {
    final arguments = node is InstanceCreationExpression
        ? node.argumentList.arguments
        : (node as MethodInvocation).argumentList.arguments;

    for (final arg in arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        final expr = arg.expression;
        if (expr is NullLiteral) {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  void _checkSpacingArgument(
    AstNode contextNode,
    Expression? expression, {
    required String context,
  }) {
    if (expression == null || referencesDesignSystemSpacing(expression)) {
      return;
    }

    final value = extractNumericLiteral(expression);
    if (value == null) {
      return;
    }

    _reportSpacing(contextNode, value, context);
  }

  void _reportSpacing(AstNode node, double value, String context) {
    final key = '${node.offset}:$value:$context';
    if (_reportedAtOffset.contains(key)) {
      return;
    }
    _reportedAtOffset.add(key);

    if (spacingRequiresRangeJustification(value)) {
      final belowGrid = value < 4;
      findings.add(
        _buildFinding(
          node: node,
          value: value,
          context: context,
          title: 'Spacing value outside acceptable range',
          description:
              '$context uses hardcoded spacing $value (below 4px or above 48px without semantic justification)',
          severity: belowGrid ? Severity.medium : Severity.high,
        ),
      );
      return;
    }

    final classification = classifySpacing(value);
    if (classification == SpacingClassification.aligned) {
      return;
    }

    final severity = classification == SpacingClassification.nonStandard
        ? Severity.medium
        : Severity.low;

    findings.add(
      _buildFinding(
        node: node,
        value: value,
        context: context,
        title: 'Non-standard spacing value',
        description:
            '$context uses hardcoded spacing $value (${classification.name}) instead of StudioSpacing',
        severity: severity,
        classification: classification,
      ),
    );
  }

  Finding _buildFinding({
    required AstNode node,
    required double value,
    required String context,
    required String title,
    required String description,
    required Severity severity,
    SpacingClassification? classification,
  }) {
    final classificationValue = classification ?? classifySpacing(value);
    final tokenRef = analyzer._designSystemReferenceFor(value);
    final recommendation = analyzer._recommendationFor(value, classificationValue);

    return Finding(
      id: analyzer._generateFindingId(),
      category: FindingCategory.spacing,
      severity: severity,
      title: title,
      description: description,
      location: parsed.atOffset(node.offset),
      codeSnippet: node.toSource().length > 120
          ? '${node.toSource().substring(0, 120)}...'
          : node.toSource(),
      recommendation: recommendation,
      designSystemReference: tokenRef ?? 'StudioSpacing / StudioLayoutSpacing',
      effort: Effort.small,
      beforeAfter: tokenRef == null
          ? null
          : BeforeAfter(
              before: '$context($value)',
              after: '$context($tokenRef)',
            ),
    );
  }
}
