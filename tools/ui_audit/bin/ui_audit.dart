#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:ui_audit/audit_orchestrator.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/monitoring/metrics_tracker.dart';
import 'package:ui_audit/monitoring/trend_analyzer.dart';
import 'package:ui_audit/config/config_parser.dart';
import 'package:ui_audit/remediation/auto_fix_applicator.dart';
import 'package:ui_audit/util/git_changed_files.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isNotEmpty && arguments.first == 'fix') {
      exit(await _runFix(arguments.sublist(1)));
    }
    if (arguments.isNotEmpty && arguments.first == 'report') {
      exit(await _runReport(arguments.sublist(1)));
    }
    final auditArgs =
        arguments.isNotEmpty && arguments.first == 'audit'
            ? arguments.sublist(1)
            : arguments;
    exit(await _runAudit(auditArgs));
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(_auditUsage);
    exit(64);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

ArgParser _auditParser() => ArgParser()
  ..addOption('config', abbr: 'c', help: 'Path to audit-config.yaml')
  ..addMultiOption('categories', help: 'Finding categories to run')
  ..addFlag('static-only', help: 'Skip runtime inspection', defaultsTo: false)
  ..addOption('format', help: 'Output format: json, markdown, html')
  ..addOption('output', help: 'Output directory for reports')
  ..addFlag('ci', help: 'CI mode: exit 1 on threshold failures', defaultsTo: false)
  ..addOption('fail-on', help: 'critical or high', defaultsTo: 'critical')
  ..addFlag('incremental', help: 'Git-changed files only', defaultsTo: false)
  ..addOption('incremental-base', help: 'Git diff range');

ArgParser _fixParser() => ArgParser()
  ..addOption('report', abbr: 'r', help: 'Audit JSON report path', mandatory: true)
  ..addFlag('dry-run', help: 'Preview only', defaultsTo: false)
  ..addFlag('no-validate', help: 'Skip flutter analyze', defaultsTo: false)
  ..addOption('project', help: 'Flutter project dir', defaultsTo: 'frontend');

ArgParser _reportParser() => ArgParser()
  ..addFlag('trend', help: 'Show trend vs previous run', defaultsTo: true)
  ..addOption('history', defaultsTo: '.kiro/audit-metrics/history.jsonl')
  ..addOption('runs', defaultsTo: '5');

const _auditUsage = '''
Usage: ui_audit [audit] [options]
       ui_audit fix --report=<audit.json> [--dry-run]
       ui_audit report [--trend] [--history=path]

Run `ui_audit` with no subcommand to audit (same as `ui_audit audit`).
''';

Future<int> _runAudit(List<String> args) async {
  final parsed = _auditParser().parse(args);
  var config = await AuditOrchestrator.loadConfig(parsed['config'] as String?);

  if (parsed['static-only'] == true) {
    config = _withoutRuntime(config);
  }
  if (parsed['format'] != null) {
    config = _withOutputFormats(config, parsed['format'] as String);
  }
  if (parsed['output'] != null) {
    config = _withOutputDirectory(config, parsed['output'] as String);
  }
  if (parsed['categories'] != null && (parsed['categories'] as List).isNotEmpty) {
    config = _withCategories(config, parsed['categories'] as List<String>);
  }

  final failOn = parsed['fail-on'] as String;
  config = AuditConfiguration(
    projectPath: config.projectPath,
    includePaths: config.includePaths,
    excludePaths: config.excludePaths,
    enabledCategories: config.enabledCategories,
    minimumSeverity: config.minimumSeverity,
    testBreakpoints: config.testBreakpoints,
    captureScreenshots: config.captureScreenshots,
    runRuntimeInspection: config.runRuntimeInspection,
    outputFormats: config.outputFormats,
    outputDirectory: config.outputDirectory,
    includeBeforeAfter: config.includeBeforeAfter,
    failOnCritical: failOn == 'critical' || parsed['ci'] == true,
    failOnHigh: failOn == 'high',
    maxFindings: config.maxFindings,
  );

  List<String>? files;
  if (parsed['incremental'] == true) {
    final diffBase = parsed['incremental-base'] as String? ??
        Platform.environment['UI_AUDIT_DIFF_BASE'] ??
        'HEAD';
    files = await GitChangedFiles.dartFilesUnderProject(
      projectPath: config.projectPath,
      diffRef: diffBase,
    );
    if (files.isEmpty) {
      stdout.writeln(
        'Incremental mode ($diffBase): no changed Dart files under project.',
      );
    } else {
      stdout.writeln(
        'Incremental mode ($diffBase): ${files.length} changed Dart file(s).',
      );
    }
  }

  final run = await AuditOrchestrator().run(config, files: files);

  stdout.writeln('UI/UX audit complete.');
  stdout.writeln('  Findings: ${run.result.summary.totalFindings}');
  stdout.writeln('  Files analyzed: ${run.result.metadata.filesAnalyzed}');
  for (final path in run.reportPaths) {
    stdout.writeln('  Report: $path');
  }

  if (parsed['ci'] == true && run.shouldFail) {
    stderr.writeln('Audit failed: severity threshold exceeded.');
    return 1;
  }
  return 0;
}

Future<int> _runFix(List<String> args) async {
  final parsed = _fixParser().parse(args);
  final projectDir = ConfigParser.resolveProjectDirectory(
    parsed['project'] as String,
  );
  final applicator = AutoFixApplicator(
    dryRun: parsed['dry-run'] as bool,
    validateAfterApply: !(parsed['no-validate'] as bool),
    frontendProjectPath: projectDir,
  );

  final reportPath = parsed['report'] as String;
  stdout.writeln('Applying fixes from $reportPath');
  if (applicator.dryRun) {
    stdout.writeln('  (dry-run)');
  }

  final result = await applicator.applyFromReportPath(reportPath);
  stdout.writeln('  Fixed: ${result.fixedCount}');
  stdout.writeln('  Skipped: ${result.skippedCount}');
  stdout.writeln('  Files modified: ${result.filesModified}');

  if (result.validationFailures.isNotEmpty) {
    stderr.writeln('Validation failures (rolled back):');
    for (final f in result.validationFailures) {
      stderr.writeln('  - $f');
    }
    return 1;
  }
  return 0;
}

Future<int> _runReport(List<String> args) async {
  final parsed = _reportParser().parse(args);
  final tracker = MetricsTracker(historyPath: parsed['history'] as String);
  final history = await tracker.readHistory();

  if (history.isEmpty) {
    stdout.writeln('No metrics at ${parsed['history']}. Run an audit first.');
    return 0;
  }

  final runs = int.tryParse(parsed['runs'] as String) ?? 5;
  final recent = history.length > runs
      ? history.sublist(history.length - runs)
      : history;

  stdout.writeln('# Recent audit runs (${recent.length})');
  for (final entry in recent) {
    stdout.writeln(
      '- ${entry['auditDate']}: ${entry['totalFindings']} findings',
    );
  }
  stdout.writeln();

  if (parsed['trend'] == true) {
    final analyzer = TrendAnalyzer();
    stdout.write(analyzer.formatReport(analyzer.analyze(history)));
  }
  return 0;
}

AuditConfiguration _withoutRuntime(AuditConfiguration config) {
  return AuditConfiguration(
    projectPath: config.projectPath,
    includePaths: config.includePaths,
    excludePaths: config.excludePaths,
    enabledCategories: config.enabledCategories,
    minimumSeverity: config.minimumSeverity,
    testBreakpoints: config.testBreakpoints,
    captureScreenshots: config.captureScreenshots,
    runRuntimeInspection: false,
    outputFormats: config.outputFormats,
    outputDirectory: config.outputDirectory,
    includeBeforeAfter: config.includeBeforeAfter,
    failOnCritical: config.failOnCritical,
    failOnHigh: config.failOnHigh,
    maxFindings: config.maxFindings,
  );
}

AuditConfiguration _withOutputFormats(AuditConfiguration config, String format) {
  return AuditConfiguration(
    projectPath: config.projectPath,
    includePaths: config.includePaths,
    excludePaths: config.excludePaths,
    enabledCategories: config.enabledCategories,
    minimumSeverity: config.minimumSeverity,
    testBreakpoints: config.testBreakpoints,
    captureScreenshots: config.captureScreenshots,
    runRuntimeInspection: config.runRuntimeInspection,
    outputFormats: format.split(',').map((e) => e.trim()).toList(),
    outputDirectory: config.outputDirectory,
    includeBeforeAfter: config.includeBeforeAfter,
    failOnCritical: config.failOnCritical,
    failOnHigh: config.failOnHigh,
    maxFindings: config.maxFindings,
  );
}

AuditConfiguration _withOutputDirectory(AuditConfiguration config, String dir) {
  return AuditConfiguration(
    projectPath: config.projectPath,
    includePaths: config.includePaths,
    excludePaths: config.excludePaths,
    enabledCategories: config.enabledCategories,
    minimumSeverity: config.minimumSeverity,
    testBreakpoints: config.testBreakpoints,
    captureScreenshots: config.captureScreenshots,
    runRuntimeInspection: config.runRuntimeInspection,
    outputFormats: config.outputFormats,
    outputDirectory: dir,
    includeBeforeAfter: config.includeBeforeAfter,
    failOnCritical: config.failOnCritical,
    failOnHigh: config.failOnHigh,
    maxFindings: config.maxFindings,
  );
}

AuditConfiguration _withCategories(
  AuditConfiguration config,
  List<String> names,
) {
  final categories = names
      .expand((n) => n.split(','))
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .map(
        (n) => FindingCategory.values.firstWhere(
          (c) => c.name == n,
          orElse: () => throw FormatException('Unknown category: $n'),
        ),
      )
      .toList();

  return AuditConfiguration(
    projectPath: config.projectPath,
    includePaths: config.includePaths,
    excludePaths: config.excludePaths,
    enabledCategories: categories,
    minimumSeverity: config.minimumSeverity,
    testBreakpoints: config.testBreakpoints,
    captureScreenshots: config.captureScreenshots,
    runRuntimeInspection: config.runRuntimeInspection,
    outputFormats: config.outputFormats,
    outputDirectory: config.outputDirectory,
    includeBeforeAfter: config.includeBeforeAfter,
    failOnCritical: config.failOnCritical,
    failOnHigh: config.failOnHigh,
    maxFindings: config.maxFindings,
  );
}
