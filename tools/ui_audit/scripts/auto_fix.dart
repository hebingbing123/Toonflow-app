#!/usr/bin/env dart
/// Legacy entrypoint — prefer `dart run ui_audit:ui_audit fix --report=...`

import 'dart:io';

import 'package:ui_audit/remediation/auto_fix_applicator.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run scripts/auto_fix.dart <audit-report.json>\n'
      'Prefer: dart run ui_audit:ui_audit fix --report=<path>',
    );
    exit(1);
  }

  final result = await AutoFixApplicator().applyFromReportPath(args.first);
  stdout.writeln('Fixed: ${result.fixedCount}, skipped: ${result.skippedCount}');
  exit(result.validationFailures.isEmpty ? 0 : 1);
}
