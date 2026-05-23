import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/models.dart';
import 'ast_parser.dart';
import 'static_analyzer.dart';

/// Validates component styling against design-system themes and radii.
class ComponentConsistencyAnalyzer extends StaticAnalyzer {
  int _findingCounter = 0;
  final AstParser _parser;

  ComponentConsistencyAnalyzer({AstParser? parser})
      : _parser = parser ?? AstParser();

  @override
  FindingCategory get category => FindingCategory.componentConsistency;

  @override
  Future<List<Finding>> analyze(String filePath) async {
    final parsed = await _parser.parseFile(filePath);
    if (parsed == null) {
      return [];
    }

    final visitor = _ComponentVisitor(parsed, this);
    parsed.unit.accept(visitor);
    return visitor.findings;
  }

  String _generateFindingId() {
    _findingCounter++;
    return 'CC-${_findingCounter.toString().padLeft(3, '0')}';
  }
}

class _ComponentVisitor extends RecursiveAstVisitor<void> {
  final ParsedDartFile parsed;
  final ComponentConsistencyAnalyzer analyzer;
  final List<Finding> findings = [];
  final Set<String> _reported = {};
  final Map<String, int> _customWidgetCounts = {};

  _ComponentVisitor(this.parsed, this.analyzer);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;
    if (name.startsWith('_')) {
      super.visitClassDeclaration(node);
      return;
    }

    final extendsClause = node.extendsClause?.superclass.toSource() ?? '';
    if (extendsClause.contains('StatelessWidget') ||
        extendsClause.contains('StatefulWidget')) {
      if (!name.startsWith('Studio') &&
          !name.endsWith('Test') &&
          name != 'TestWidget') {
        _customWidgetCounts[name] = (_customWidgetCounts[name] ?? 0) + 1;
      }
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkBorderRadius(node, node.toSource());
    _checkThemeOverride(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = constructionNameFromMethodInvocation(node);
    if (name == 'BorderRadius.circular' ||
        name == 'RoundedRectangleBorder' ||
        name?.startsWith('BorderRadius.') == true) {
      _checkBorderRadius(node, node.toSource());
    }
    if (name == 'Card' || name == 'Chip' || name == 'Dialog') {
      _checkRawMaterialWidget(node, name!);
    }
    super.visitMethodInvocation(node);
  }

  void _checkBorderRadius(AstNode node, String source) {
    if (source.contains('StudioSpacing.radius') ||
        source.contains('StudioSpacing.sm') ||
        source.contains('StudioSpacing.md')) {
      return;
    }

    final match = RegExp(r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)').firstMatch(source);
    if (match == null) {
      return;
    }

    final value = double.tryParse(match.group(1)!);
    if (value == null) {
      return;
    }

    String? expected;
    Severity severity = Severity.medium;
    String recommendation;

    if (value == 14 ||
        value == 10 ||
        value == 8 ||
        value == 12 ||
        value == 16 ||
        value == 24 ||
        value == 28 ||
        value == 32 ||
        value >= 999) {
      return;
    }

    if (value >= 8 && value <= 16) {
      expected = value < 12 ? 'StudioSpacing.radiusButton (10)' : 'StudioSpacing.radiusCard (14)';
      recommendation =
          'Use StudioSpacing.radiusCard (14px) for cards or radiusButton (10px) for inputs';
    } else if (value > 16 && value < 999) {
      expected = 'StudioSpacing.radiusCard or ChipTheme (999)';
      recommendation = 'Cards use 14px, chips use 999px pill radius per theme';
      severity = Severity.low;
    } else {
      return;
    }

    _report(
      node,
      title: 'Non-standard border radius',
      description: 'Hardcoded BorderRadius.circular($value) deviates from theme',
      severity: severity,
      recommendation: recommendation,
      designRef: expected ?? 'StudioSpacing.radiusCard',
    );
  }

  void _checkThemeOverride(InstanceCreationExpression node) {
    final type = node.constructorName.type.toSource();
    const themeTypes = {
      'CardTheme',
      'DialogTheme',
      'InputDecorationTheme',
      'MenuTheme',
      'ChipTheme',
      'SnackBarTheme',
    };
    if (!themeTypes.contains(type)) {
      return;
    }

    final source = node.toSource();
    if (source.contains('Theme.of(context)') || source.contains('studio')) {
      return;
    }

    _report(
      node,
      title: 'Local theme override outside design system',
      description: '$type defined inline instead of central theme.dart',
      severity: Severity.medium,
      recommendation: 'Move $type styling to frontend/lib/design_system/theme.dart',
      designRef: 'theme.dart',
    );
  }

  void _checkRawMaterialWidget(AstNode node, String widgetName) {
    final source = node.toSource();
    if (source.contains('Studio') ||
        parsed.filePath.contains('design_system/components/studio_')) {
      return;
    }

    final designComponent = switch (widgetName) {
      'Card' => 'StudioCard',
      'Chip' => 'ChipTheme / design system chips',
      'Dialog' => 'StudioDialogShell',
      _ => null,
    };
    if (designComponent == null) {
      return;
    }

    _report(
      node,
      title: 'Raw $widgetName instead of design-system component',
      description: 'Uses Material $widgetName without $designComponent wrapper',
      severity: Severity.low,
      recommendation: 'Prefer $designComponent from frontend/lib/design_system/components/',
      designRef: designComponent,
    );
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
        category: FindingCategory.componentConsistency,
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

  @override
  void visitCompilationUnit(CompilationUnit node) {
    super.visitCompilationUnit(node);
    _reportDuplicatePatterns();
  }

  static const Set<String> _allowedDomainCards = {
    'AgentWorkspaceProductionCard',
    'AgentWorkspaceScriptCard',
    'JobQueueStatsCard',
    'SearchResultCard',
  };

  void _reportDuplicatePatterns() {
    for (final entry in _customWidgetCounts.entries) {
      if (entry.key.endsWith('Card') &&
          entry.key != 'StudioCard' &&
          !_allowedDomainCards.contains(entry.key)) {
        _reportPattern(
          'Custom card widget duplicates StudioCard',
          'Class ${entry.key} may duplicate StudioCard; consolidate into design_system/components/',
        );
      }
    }
  }

  void _reportPattern(String title, String description) {
    final key = 'pattern:$title';
    if (_reported.contains(key)) {
      return;
    }
    _reported.add(key);

    findings.add(
      Finding(
        id: analyzer._generateFindingId(),
        category: FindingCategory.componentConsistency,
        severity: Severity.low,
        title: title,
        description: description,
        location: Location(file: parsed.filePath, line: 1, column: 1),
        recommendation: 'Use or extend StudioCard / component library widgets',
        designSystemReference: 'StudioCard',
        effort: Effort.medium,
      ),
    );
  }
}
