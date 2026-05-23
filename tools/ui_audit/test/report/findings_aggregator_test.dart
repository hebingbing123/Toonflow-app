import 'package:test/test.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/report/findings_aggregator.dart';

void main() {
  group('FindingsAggregator', () {
    final aggregator = FindingsAggregator();

    test('Property 23: summary statistics accuracy', () {
      final findings = [
        Finding(
          id: 'A-1',
          category: FindingCategory.accessibility,
          severity: Severity.critical,
          title: 't',
          description: 'd',
          location: const Location(file: 'a.dart', line: 1, column: 1),
          recommendation: 'r',
          effort: Effort.small,
        ),
        Finding(
          id: 'S-1',
          category: FindingCategory.spacing,
          severity: Severity.low,
          title: 't',
          description: 'd',
          location: const Location(file: 'b.dart', line: 2, column: 1),
          recommendation: 'r',
          effort: Effort.small,
        ),
      ];

      final summary = aggregator.summarize(findings);
      expect(summary.totalFindings, 2);
      expect(summary.bySeverity[Severity.critical], 1);
      expect(summary.bySeverity[Severity.low], 1);
      expect(summary.byCategory[FindingCategory.accessibility], 1);
    });

    test('Property 22/25: action plan prioritizes accessibility first', () {
      final findings = [
        Finding(
          id: 'S-1',
          category: FindingCategory.spacing,
          severity: Severity.high,
          title: 't',
          description: 'd',
          location: const Location(file: 'a.dart', line: 1, column: 1),
          recommendation: 'r',
          effort: Effort.small,
        ),
        Finding(
          id: 'A-1',
          category: FindingCategory.accessibility,
          severity: Severity.medium,
          title: 't',
          description: 'd',
          location: const Location(file: 'b.dart', line: 2, column: 1),
          recommendation: 'r',
          effort: Effort.small,
        ),
      ];

      final plan = aggregator.buildActionPlan(findings);
      expect(plan.first.category, FindingCategory.accessibility);
    });
  });
}
