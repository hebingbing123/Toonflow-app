#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:ui_audit/audit_orchestrator.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/util/git_changed_files.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', abbr: 'c', help: 'Path to audit-config.yaml')
    ..addMultiOption(
      'categories',
      help: 'Comma-separated finding categories to run',
    )
    ..addFlag('static-only', help: 'Skip runtime inspection', defaultsTo: false)
    ..addOption('format', help: 'Output format: json, markdown, html')
    ..addOption('output', help: 'Output directory for reports')
    ..addFlag('ci', help: 'CI mode: non-zero exit on threshold failures', defaultsTo: false)
    ..addOption(
      'fail-on',
      help: 'Fail threshold: critical, high',
      defaultsTo: 'critical',
    )
    ..addFlag(
      'incremental',
      help: 'Only analyze Dart files changed in git',
      defaultsTo: false,
    )
    ..addOption(
      'incremental-base',
      help:
          'Git diff range (default: HEAD locally; CI: origin/main...HEAD). '
          'Also reads UI_AUDIT_DIFF_BASE.',
    );

  try {
    final args = parser.parse(arguments);
    var config = await AuditOrchestrator.loadConfig(args['config'] as String?);

    if (args['static-only'] == true) {
      config = AuditConfiguration(
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

    if (args['format'] != null) {
      config = _withOutputFormats(config, args['format'] as String);
    }
    if (args['output'] != null) {
      config = _withOutputDirectory(config, args['output'] as String);
    }
    if (args['categories'] != null && (args['categories'] as List).isNotEmpty) {
      config = _withCategories(config, args['categories'] as List<String>);
    }

    final failOn = args['fail-on'] as String;
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
      failOnCritical: failOn == 'critical' || args['ci'] == true,
      failOnHigh: failOn == 'high',
      maxFindings: config.maxFindings,
    );

    List<String>? files;
    if (args['incremental'] == true) {
      final diffBase = args['incremental-base'] as String? ??
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

    if (args['ci'] == true && run.shouldFail) {
      stderr.writeln('Audit failed: severity threshold exceeded.');
      exit(1);
    }
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exit(64);
  } catch (e) {
    stderr.writeln('Audit failed: $e');
    exit(1);
  }
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

