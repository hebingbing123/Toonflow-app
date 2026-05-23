import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Static accessibility checks (labels, form hints, reduced motion).
class AccessibilityAnalyzerStatic extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  AccessibilityAnalyzerStatic({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.accessibility;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _AccessibilityVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'ACC-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _AccessibilityVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final AccessibilityAnalyzerStatic analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};

  _AccessibilityVisitor(this.parsed, this.analyzer);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    switch (name) {
      case 'Icon':
        _checkIconSemantics(node);
      case 'Image':
      case 'Image.network':
      case 'Image.asset':
        _checkImageSemantics(node);
      case 'TextField':
      case 'TextFormField':
        _checkFormFieldLabels(node);
      default:
        break;
    }

    if (_isAnimatedCall(name, node)) {
      _checkReducedMotion(node);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.toSource();
    if (type == 'Icon') {
      _checkIconSemantics(node);
    } else if (type.startsWith('Image')) {
      _checkImageSemantics(node);
    } else if (type == 'TextField' || type == 'TextFormField') {
      _checkFormFieldLabels(node);
    }

    if (type.startsWith('Animated')) {
      _checkReducedMotion(node);
    }

    super.visitInstanceCreationExpression(node);
  }

  bool _isAnimatedCall(String? name, MethodInvocation node) {
    if (name != null && name.startsWith('Animated')) {
      return true;
    }
    return node.methodName.name.startsWith('Animated');
  }

  void _checkIconSemantics(AstNode node) {
    if (_hasSemanticLabel(node)) {
      return;
    }
    _report(
      node,
      title: 'Icon missing semantic label',
      description: 'Icon widget lacks semanticLabel for screen readers',
      severity: Severity.high,
      recommendation:
          'Add semanticLabel describing the icon action, or exclude decorative icons with ExcludeSemantics',
      designRef: 'Semantics / Icon.semanticLabel',
    );
  }

  void _checkImageSemantics(AstNode node) {
    if (_hasSemanticLabel(node)) {
      return;
    }
    _report(
      node,
      title: 'Image missing semantic label',
      description: 'Image widget lacks semanticLabel or alt text equivalent',
      severity: Severity.high,
      recommendation: 'Provide semanticLabel for informative images',
      designRef: 'Semantics / Image.semanticLabel',
    );
  }

  void _checkFormFieldLabels(AstNode node) {
    final args = _argumentList(node);
    var hasLabelOrHint = false;

    for (final arg in args) {
      if (arg is! NamedExpression) {
        continue;
      }
      final name = arg.name.label.name;
      if (name == 'decoration') {
        final deco = arg.expression.toSource();
        if (deco.contains('labelText') ||
            deco.contains('hintText') ||
            deco.contains('label:')) {
          hasLabelOrHint = true;
        }
      }
      if (name == 'labelText' || name == 'hintText') {
        hasLabelOrHint = true;
      }
    }

    if (hasLabelOrHint) {
      return;
    }

    _report(
      node,
      title: 'Form input missing label or hint',
      description: 'TextField/TextFormField has no associated label or hint',
      severity: Severity.high,
      recommendation:
          'Use InputDecoration with labelText/hintText or an external Semantics label',
      designRef: 'InputDecorationTheme',
    );
  }

  void _checkReducedMotion(AstNode node) {
    final source = node.toSource();
    if (source.contains('MediaQuery.disableAnimationsOf') ||
        source.contains('disableAnimations') ||
        source.contains('prefers-reduced-motion') ||
        source.contains('accessibleNavigation')) {
      return;
    }

    _report(
      node,
      title: 'Animation without reduced-motion handling',
      description:
          'Animated widget does not check MediaQuery.disableAnimations or reduced motion',
      severity: Severity.medium,
      recommendation:
          'Wrap duration/curve with MediaQuery.disableAnimationsOf(context) check',
      designRef: 'MediaQuery.disableAnimationsOf',
    );
  }

  Iterable<Expression> _argumentList(AstNode node) {
    if (node is MethodInvocation) {
      return node.argumentList.arguments;
    }
    if (node is InstanceCreationExpression) {
      return node.argumentList.arguments;
    }
    return const [];
  }

  bool _hasSemanticLabel(AstNode node) {
    for (final arg in _argumentList(node)) {
      if (arg is NamedExpression && arg.name.label.name == 'semanticLabel') {
        return true;
      }
    }
    return node.toSource().contains('semanticLabel:');
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
        category: FindingCategory.accessibility,
        severity: severity,
        title: title,
        description: description,
        location: parsed.atOffset(node.offset),
        codeSnippet: node.toSource().length > 100
            ? '${node.toSource().substring(0, 100)}...'
            : node.toSource(),
        recommendation: recommendation,
        designSystemReference: designRef,
        effort: Effort.small,
      ),
    );
  }
}
