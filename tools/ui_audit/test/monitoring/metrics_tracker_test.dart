import 'dart:io';

import 'package:test/test.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/monitoring/metrics_tracker.dart';

void main() {
  test('appends audit summary to jsonl', () async {
    final dir = await Directory.systemTemp.createTemp('ui_audit_metrics_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/history.jsonl';
    final tracker = MetricsTracker(historyPath: path);

    final result = AuditResult(
      metadata: AuditMetadata(
        auditDate: DateTime.utc(2026, 5, 23),
        auditVersion: '1.0.0',
        projectPath: 'frontend/',
        filesAnalyzed: 100,
        widgetsInspected: 0,
      ),
      summary: AuditSummary(
        totalFindings: 42,
        bySeverity: {for (final s in Severity.values) s: 0},
        byCategory: {for (final c in FindingCategory.values) c: 0},
      ),
      findings: const [],
      errors: const [],
      actionPlan: const [],
    );

    await tracker.record(result);
    final history = await tracker.readHistory();
    expect(history, hasLength(1));
    expect(history.first['totalFindings'], 42);
  });
}
