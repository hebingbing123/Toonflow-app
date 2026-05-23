import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Static heuristics for empty list/grid views without [StudioEmptyState].
class EmptyStateAnalyzerStatic extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  EmptyStateAnalyzerStatic({AstParser? parser}) : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.emptyStates;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _EmptyStateVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'ES-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _EmptyStateVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final EmptyStateAnalyzerStatic analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};

  _EmptyStateVisitor(this.parsed, this.analyzer);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'ListView' ||
        name == 'GridView' ||
        name == 'ListView.builder' ||
        name == 'GridView.builder') {
      _checkEmptyHandling(node, name!);
    }
    super.visitMethodInvocation(node);
  }

  void _checkEmptyHandling(AstNode node, String listType) {
    final source = parsed.content;
    if (source.contains('StudioEmptyState')) {
      return;
    }

    final snippet = node.toSource();
    if (snippet.contains('isEmpty') ||
        snippet.contains('length == 0') ||
        snippet.contains('isNotEmpty')) {
      return;
    }

    // Static scroll regions (home sections, setup sheets, product shell panes).
    if (!listType.contains('builder')) {
      if (snippet.contains('shrinkWrap: true')) {
        return;
      }
      final path = parsed.filePath;
      if (path.endsWith('home_page.dart') ||
          path.endsWith('build_product_shell.dart') ||
          path.endsWith('project_studio_script_step_setup.dart')) {
        return;
      }
    }

    final key = '${node.offset}:$listType';
    if (_reported.contains(key)) {
      return;
    }
    _reported.add(key);

    findings.add(
      Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.emptyStates,
        severity: Severity.medium,
        title: 'List/grid may lack empty state treatment',
        description:
            '$listType without nearby StudioEmptyState or empty-check pattern in file',
        location: parsed.atOffset(node.offset),
        codeSnippet: snippet.length > 100 ? '${snippet.substring(0, 100)}...' : snippet,
        recommendation:
            'Show StudioEmptyState when data is empty, with descriptive text and optional action',
        designSystemReference: 'StudioEmptyState',
        effort: Effort.medium,
      ),
    );
  }
}
