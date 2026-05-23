import 'dart:convert';
import 'dart:io';

import 'package:ui_audit/models/models.dart';

/// Persists audit run summaries for trend analysis.
class MetricsTracker {
  final String historyPath;

  MetricsTracker({this.historyPath = '.kiro/audit-metrics/history.jsonl'});

  /// Appends one record from [result] and returns the written line map.
  Future<Map<String, dynamic>> record(AuditResult result) async {
    final entry = <String, dynamic>{
      'auditDate': result.metadata.auditDate.toIso8601String(),
      'auditVersion': result.metadata.auditVersion,
      'projectPath': result.metadata.projectPath,
      'filesAnalyzed': result.metadata.filesAnalyzed,
      'widgetsInspected': result.metadata.widgetsInspected,
      'totalFindings': result.summary.totalFindings,
      'bySeverity': result.summary.bySeverity.map(
        (k, v) => MapEntry(k.name, v),
      ),
      'byCategory': result.summary.byCategory.map(
        (k, v) => MapEntry(k.name, v),
      ),
    };

    final file = File(historyPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(entry)}\n',
      mode: FileMode.append,
    );
    return entry;
  }

  /// Reads all history entries (oldest first).
  Future<List<Map<String, dynamic>>> readHistory() async {
    final file = File(historyPath);
    if (!file.existsSync()) {
      return [];
    }
    final lines = await file.readAsLines();
    final entries = <Map<String, dynamic>>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      entries.add(jsonDecode(trimmed) as Map<String, dynamic>);
    }
    return entries;
  }
}
