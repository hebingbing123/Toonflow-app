import '../models/models.dart';
import 'accessibility_analyzer_static.dart';
import 'color_system_analyzer.dart';
import 'component_consistency_analyzer.dart';
import 'empty_state_analyzer_static.dart';
import 'responsive_analyzer_static.dart';
import 'spacing_analyzer.dart';
import 'static_analyzer.dart';
import 'typography_analyzer.dart';
import 'visual_hierarchy_analyzer.dart';
import 'ast_parser.dart';

/// Runs all enabled static analyzers over a project tree.
class StaticAnalysisRunner {
  final AstParser parser;

  StaticAnalysisRunner({AstParser? parser}) : parser = parser ?? AstParser();

  List<StaticAnalyzer> analyzersFor(AuditConfiguration config) {
    final all = <FindingCategory, StaticAnalyzer>{
      FindingCategory.visualHierarchy: VisualHierarchyAnalyzer(parser: parser),
      FindingCategory.spacing: SpacingAnalyzer(parser: parser),
      FindingCategory.typography: TypographyAnalyzer(parser: parser),
      FindingCategory.colorSystem: ColorSystemAnalyzer(parser: parser),
      FindingCategory.componentConsistency:
          ComponentConsistencyAnalyzer(parser: parser),
      FindingCategory.accessibility: AccessibilityAnalyzerStatic(parser: parser),
      FindingCategory.emptyStates: EmptyStateAnalyzerStatic(parser: parser),
      FindingCategory.responsiveness: ResponsiveAnalyzerStatic(parser: parser),
    };

    return config.enabledCategories
        .where(all.containsKey)
        .map((c) => all[c]!)
        .toList();
  }

  Future<StaticAnalysisResult> run(
    AuditConfiguration config, {
    List<String>? files,
  }) async {
    final analyzers = analyzersFor(config);
    final dartFiles = files == null
        ? await parser.collectDartFiles(
            projectPath: config.projectPath,
            includePaths: config.includePaths,
            excludePaths: config.excludePaths,
          )
        : AstParser.filterDartFiles(
            absolutePaths: files,
            projectPath: config.projectPath,
            includePaths: config.includePaths,
            excludePaths: config.excludePaths,
          );

    final findings = <Finding>[];
    final errors = <AuditError>[];

    const batchSize = 16;
    for (var i = 0; i < dartFiles.length; i += batchSize) {
      final batch = dartFiles.sublist(
        i,
        i + batchSize > dartFiles.length ? dartFiles.length : i + batchSize,
      );
      final batchResults = await Future.wait(
        batch.map((file) => _analyzeFile(file, analyzers, config)),
      );
      for (final result in batchResults) {
        findings.addAll(result.findings);
        errors.addAll(result.errors);
      }
    }

    if (config.maxFindings != null && findings.length > config.maxFindings!) {
      findings.removeRange(config.maxFindings!, findings.length);
    }

    return StaticAnalysisResult(
      findings: findings,
      errors: errors,
      filesAnalyzed: dartFiles.length,
    );
  }

  bool _meetsMinimumSeverity(Severity finding, Severity minimum) {
    const order = [Severity.low, Severity.medium, Severity.high, Severity.critical];
    return order.indexOf(finding) >= order.indexOf(minimum);
  }

  Future<_FileAnalysisResult> _analyzeFile(
    String file,
    List<StaticAnalyzer> analyzers,
    AuditConfiguration config,
  ) async {
    final findings = <Finding>[];
    final errors = <AuditError>[];

    for (final analyzer in analyzers) {
      try {
        final fileFindings = await analyzer.analyze(file);
        findings.addAll(
          fileFindings.where(
            (f) => _meetsMinimumSeverity(f.severity, config.minimumSeverity),
          ),
        );
      } catch (e, stack) {
        errors.add(
          AuditError(
            phase: 'static_analysis',
            file: file,
            message: '${analyzer.category.name}: $e',
            stackTrace: stack.toString(),
          ),
        );
      }
    }

    return _FileAnalysisResult(findings: findings, errors: errors);
  }
}

class _FileAnalysisResult {
  final List<Finding> findings;
  final List<AuditError> errors;

  const _FileAnalysisResult({
    required this.findings,
    required this.errors,
  });
}

/// Output from [StaticAnalysisRunner.run].
class StaticAnalysisResult {
  final List<Finding> findings;
  final List<AuditError> errors;
  final int filesAnalyzed;

  const StaticAnalysisResult({
    required this.findings,
    required this.errors,
    required this.filesAnalyzed,
  });
}
