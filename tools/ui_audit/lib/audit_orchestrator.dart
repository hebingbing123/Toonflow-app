import 'dart:io';

import 'analyzers/static_analysis_runner.dart';
import 'config/config_parser.dart';
import 'models/models.dart';
import 'monitoring/metrics_tracker.dart';
import 'report/findings_aggregator.dart';
import 'report/report_generator.dart';
import 'runtime/default_runtime_inspector.dart';
import 'runtime/runtime_inspector.dart';

/// Coordinates static analysis, optional runtime inspection, and reporting.
class AuditOrchestrator {
  static const auditVersion = '1.0.0';

  final StaticAnalysisRunner staticRunner;
  final RuntimeInspector runtimeInspector;
  final FindingsAggregator aggregator;
  final ReportGenerator reportGenerator;
  final MetricsTracker metricsTracker;

  AuditOrchestrator({
    StaticAnalysisRunner? staticRunner,
    RuntimeInspector? runtimeInspector,
    FindingsAggregator? aggregator,
    ReportGenerator? reportGenerator,
    MetricsTracker? metricsTracker,
  })  : staticRunner = staticRunner ?? StaticAnalysisRunner(),
        runtimeInspector = runtimeInspector ?? defaultRuntimeInspector(),
        aggregator = aggregator ?? FindingsAggregator(),
        reportGenerator = reportGenerator ?? ReportGenerator(),
        metricsTracker = metricsTracker ?? MetricsTracker();

  Future<AuditRunResult> run(
    AuditConfiguration config, {
    List<String>? files,
    bool writeReports = true,
  }) async {
    final staticResult = await staticRunner.run(config, files: files);

    RuntimeInspectionResult runtimeResult = const RuntimeInspectionResult();
    if (config.runRuntimeInspection) {
      runtimeResult = await runtimeInspector.inspect(
        RuntimeInspectionContext(
          projectPath: config.projectPath,
          breakpoints: config.testBreakpoints,
          captureScreenshots: config.captureScreenshots,
        ),
      );
    }

    final allFindings = [
      ...staticResult.findings,
      ...runtimeResult.findings,
    ];
    final allErrors = [
      ...staticResult.errors,
      ...runtimeResult.errors,
    ];

    final auditResult = AuditResult(
      metadata: AuditMetadata(
        auditDate: DateTime.now().toUtc(),
        auditVersion: auditVersion,
        projectPath: config.projectPath,
        filesAnalyzed: staticResult.filesAnalyzed,
        widgetsInspected: runtimeResult.widgetsInspected,
      ),
      summary: aggregator.summarize(allFindings),
      findings: allFindings,
      errors: allErrors,
      actionPlan: aggregator.buildActionPlan(allFindings),
    );

    List<String> reportPaths = [];
    if (writeReports) {
      reportPaths = await reportGenerator.writeReports(auditResult, config);
    }

    if (writeReports) {
      await metricsTracker.record(auditResult);
    }

    return AuditRunResult(
      result: auditResult,
      reportPaths: reportPaths,
      shouldFail: auditResult.shouldFail(
        failOnCritical: config.failOnCritical,
        failOnHigh: config.failOnHigh,
      ),
    );
  }

  static Future<AuditConfiguration> loadConfig(String? configPath) async {
    if (configPath != null) {
      return ConfigParser.loadFromFile(configPath);
    }

    final defaultPath = '.kiro/audit-config.yaml';
    if (await File(defaultPath).exists()) {
      return ConfigParser.loadFromFile(defaultPath);
    }

    return const AuditConfiguration(projectPath: 'frontend/');
  }
}

class AuditRunResult {
  final AuditResult result;
  final List<String> reportPaths;
  final bool shouldFail;

  const AuditRunResult({
    required this.result,
    required this.reportPaths,
    required this.shouldFail,
  });
}
