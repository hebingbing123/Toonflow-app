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

    if (_isAnimatedCall(name, node) && name != 'AnimatedBuilder') {
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

    if (type.startsWith('Animated') && type != 'AnimatedBuilder') {
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
    if (_hasSemanticLabel(node) || _iconHasAccessibleContext(node)) {
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

    if (hasLabelOrHint ||
        _formFieldHasExternalLabel(node) ||
        _hasSemanticsLabelAncestor(node)) {
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
    if (_widgetTypeName(node) == 'AnimatedBuilder') {
      return;
    }

    final source = node.toSource();
    if (source.contains('MediaQuery.disableAnimationsOf') ||
        source.contains('studioAnimationDuration') ||
        source.contains('studioAnimationCurve') ||
        source.contains('studioDisableAnimations') ||
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

  bool _iconHasAccessibleContext(AstNode node) {
    if (_isDecorativeInputIcon(node) ||
        _iconHasAdjacentTextLabel(node) ||
        _isLabeledTextButtonIcon(node) ||
        _isInputDecoratorAffordance(node)) {
      return true;
    }

    AstNode? current = node.parent;
    while (current != null) {
      if (_isIconButtonWithTooltip(current) ||
          _isListTileWithTitle(current) ||
          _isLabeledMenuItem(current) ||
          _isSemanticsWithLabel(current) ||
          _isExcludeSemantics(current) ||
          _widgetTypeName(current) == 'Tooltip') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isDecorativeInputIcon(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_widgetTypeName(current) == 'InputDecoration') {
        return _hasNamedArgument(current, 'prefixIcon') ||
            _hasNamedArgument(current, 'suffixIcon');
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInputDecoratorAffordance(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_widgetTypeName(current) == 'InputDecorator') {
        final source = current.toSource();
        return source.contains('suffixIcon:') ||
            source.contains('prefixIcon:');
      }
      current = current.parent;
    }
    return false;
  }

  bool _formFieldHasExternalLabel(AstNode node) {
    final column = _findAncestorWidget(node, 'Column');
    if (column != null &&
        RegExp(r'Text\s*\(').hasMatch(column.toSource())) {
      return true;
    }
    return false;
  }

  bool _hasSemanticsLabelAncestor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_widgetTypeName(current) == 'Semantics') {
        final source = current.toSource();
        if (source.contains('label:') || source.contains('textField:')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Icons beside visible [Text] in the same [Row]/[Column] are treated as decorative.
  bool _iconHasAdjacentTextLabel(AstNode node) {
    for (final container in const ['Row', 'Column', 'Wrap', 'ListTile']) {
      final ancestor = _findAncestorWidget(node, container);
      if (ancestor == null) {
        continue;
      }
      final source = ancestor.toSource();
      if (RegExp(r'\bText\s*\(').hasMatch(source) ||
          RegExp(r'\bRichText\s*\(').hasMatch(source)) {
        return true;
      }
    }
    return false;
  }

  AstNode? _findAncestorWidget(AstNode node, String typeName) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_widgetTypeName(current) == typeName) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  bool _isLabeledTextButtonIcon(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final name = current.methodName.name;
        if (name == 'icon' || name.endsWith('Icon')) {
          final source = current.toSource();
          if (source.contains('label:') &&
              (source.contains('Button') || source.contains('FilledButton'))) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isIconButtonWithTooltip(AstNode node) {
    final type = _widgetTypeName(node);
    if (type != 'IconButton' && type != 'CloseButton' && type != 'BackButton') {
      return false;
    }
    return _hasNamedArgument(node, 'tooltip') ||
        node.toSource().contains('tooltip:');
  }

  bool _isListTileWithTitle(AstNode node) {
    return _widgetTypeName(node) == 'ListTile' &&
        (_hasNamedArgument(node, 'title') || node.toSource().contains('title:'));
  }

  bool _isLabeledMenuItem(AstNode node) {
    return switch (_widgetTypeName(node)) {
      'DropdownMenuItem' ||
      'PopupMenuItem' ||
      'MenuItemButton' ||
      'CheckboxListTile' ||
      'RadioListTile' ||
      'SwitchListTile' ||
      'ButtonSegment' =>
        true,
      _ => false,
    };
  }

  bool _isSemanticsWithLabel(AstNode node) {
    if (_widgetTypeName(node) != 'Semantics') {
      return false;
    }
    return _hasNamedArgument(node, 'label') ||
        _hasNamedArgument(node, 'button') ||
        node.toSource().contains('label:');
  }

  bool _isExcludeSemantics(AstNode node) {
    return _widgetTypeName(node) == 'ExcludeSemantics' ||
        _widgetTypeName(node) == 'MergeSemantics';
  }

  String? _widgetTypeName(AstNode node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.toSource();
    }
    if (node is MethodInvocation) {
      if (node.target == null) {
        return node.methodName.name;
      }
      return constructionNameFromMethodInvocation(node);
    }
    return null;
  }

  bool _hasNamedArgument(AstNode node, String name) {
    for (final arg in _argumentList(node)) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return true;
      }
    }
    return false;
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
