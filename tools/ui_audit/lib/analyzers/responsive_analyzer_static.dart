import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Flags fixed-width constraints that hinder responsive layouts.
class ResponsiveAnalyzerStatic extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  ResponsiveAnalyzerStatic({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.responsiveness;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _ResponsiveVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'RS-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _ResponsiveVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final ResponsiveAnalyzerStatic analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};

  _ResponsiveVisitor(this.parsed, this.analyzer);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'SizedBox' || name == 'Container') {
      _checkFixedWidth(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.toSource();
    if (type == 'SizedBox' || type == 'Container') {
      _checkFixedWidth(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _checkFixedWidth(AstNode node) {
    for (final arg in _args(node)) {
      if (arg is! NamedExpression || arg.name.label.name != 'width') {
        continue;
      }

      final width = extractNumericLiteral(arg.expression);
      if (width == null || width < 400) {
        continue;
      }

      final source = arg.expression.toSource();
      if (source.contains('MediaQuery') ||
          source.contains('LayoutBuilder') ||
          source.contains('double.infinity') ||
          source.contains('studioConstrainedDialogWidth') ||
          source.contains('kStudio')) {
        continue;
      }

      final key = '${node.offset}:$width';
      if (_reported.contains(key)) {
        continue;
      }
      _reported.add(key);

      findings.add(
        Finding(
          id: analyzer._generateFindingId(),
          category: FindingCategory.responsiveness,
          severity: Severity.medium,
          title: 'Fixed-width element may block responsive layout',
          description: 'Hardcoded width $width prevents adaptation below narrow breakpoints',
          location: parsed.atOffset(node.offset),
          codeSnippet: node.toSource().length > 100
              ? '${node.toSource().substring(0, 100)}...'
              : node.toSource(),
          recommendation:
              'Use LayoutBuilder, MediaQuery, or flex layouts; see layout_breakpoints.dart',
          designSystemReference: 'layout_breakpoints.dart',
          effort: Effort.medium,
        ),
      );
    }
  }

  Iterable<Expression> _args(AstNode node) {
    if (node is MethodInvocation) {
      return node.argumentList.arguments;
    }
    if (node is InstanceCreationExpression) {
      return node.argumentList.arguments;
    }
    return const [];
  }
}
