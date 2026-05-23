/// Trend comparison between audit history entries.
class TrendReport {
  final Map<String, dynamic>? previous;
  final Map<String, dynamic> current;
  final int totalDelta;
  final Map<String, int> severityDelta;
  final Map<String, int> categoryDelta;
  final List<String> regressions;

  const TrendReport({
    required this.previous,
    required this.current,
    required this.totalDelta,
    required this.severityDelta,
    required this.categoryDelta,
    required this.regressions,
  });
}

/// Compares recent audit metrics for burn-down and regressions.
class TrendAnalyzer {
  /// Builds a trend report from [history] (last entry is current).
  TrendReport analyze(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      throw ArgumentError('History is empty');
    }
    final current = history.last;
    final previous = history.length > 1 ? history[history.length - 2] : null;

    final currentTotal = current['totalFindings'] as int? ?? 0;
    final previousTotal = previous?['totalFindings'] as int? ?? currentTotal;
    final totalDelta = currentTotal - previousTotal;

    final severityDelta = <String, int>{};
    final categoryDelta = <String, int>{};
    final regressions = <String>[];

    Map<String, dynamic> _asStringMap(Object? value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return {};
    }

    void diffMap(
      String key,
      Map<String, int> out,
    ) {
      final cur = _asStringMap(current[key]);
      final prev = _asStringMap(previous?[key]);
      final allKeys = {...cur.keys, ...prev.keys};
      for (final k in allKeys) {
        final c = (cur[k] as int?) ?? 0;
        final p = (prev[k] as int?) ?? 0;
        final d = c - p;
        if (d != 0) {
          out[k] = d;
          if (d > 0) {
            regressions.add('$key.$k increased by $d');
          }
        }
      }
    }

    diffMap('bySeverity', severityDelta);
    diffMap('byCategory', categoryDelta);

    if (totalDelta > 0) {
      regressions.insert(
        0,
        'Total findings increased by $totalDelta (${previousTotal} → $currentTotal)',
      );
    }

    return TrendReport(
      previous: previous,
      current: current,
      totalDelta: totalDelta,
      severityDelta: severityDelta,
      categoryDelta: categoryDelta,
      regressions: regressions,
    );
  }

  String formatReport(TrendReport report, {int recentRuns = 5}) {
    final buf = StringBuffer()
      ..writeln('# UI/UX Audit Trend')
      ..writeln()
      ..writeln('Current run: ${report.current['auditDate']}')
      ..writeln('Total findings: ${report.current['totalFindings']}')
      ..writeln('Delta vs previous: ${report.totalDelta}')
      ..writeln();

    if (report.severityDelta.isNotEmpty) {
      buf.writeln('## Severity delta');
      for (final e in report.severityDelta.entries) {
        final sign = e.value > 0 ? '+' : '';
        buf.writeln('- ${e.key}: $sign${e.value}');
      }
      buf.writeln();
    }

    if (report.categoryDelta.isNotEmpty) {
      buf.writeln('## Category delta');
      for (final e in report.categoryDelta.entries) {
        final sign = e.value > 0 ? '+' : '';
        buf.writeln('- ${e.key}: $sign${e.value}');
      }
      buf.writeln();
    }

    if (report.regressions.isEmpty) {
      buf.writeln('No regressions detected vs previous run.');
    } else {
      buf.writeln('## Regressions');
      for (final r in report.regressions) {
        buf.writeln('- $r');
      }
    }

    return buf.toString();
  }
}
