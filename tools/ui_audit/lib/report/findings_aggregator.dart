import '../models/models.dart';

/// Aggregates findings, builds summaries, and prioritizes action plans.
class FindingsAggregator {
  AuditSummary summarize(List<Finding> findings) {
    final bySeverity = <Severity, int>{
      for (final s in Severity.values) s: 0,
    };
    final byCategory = <FindingCategory, int>{
      for (final c in FindingCategory.values) c: 0,
    };

    for (final finding in findings) {
      bySeverity[finding.severity] = (bySeverity[finding.severity] ?? 0) + 1;
      byCategory[finding.category] =
          (byCategory[finding.category] ?? 0) + 1;
    }

    return AuditSummary(
      totalFindings: findings.length,
      bySeverity: bySeverity,
      byCategory: byCategory,
    );
  }

  List<ActionPlanItem> buildActionPlan(List<Finding> findings) {
    if (findings.isEmpty) {
      return [];
    }

    final grouped = <FindingCategory, List<Finding>>{};
    for (final finding in findings) {
      grouped.putIfAbsent(finding.category, () => []).add(finding);
    }

    int priorityFor(FindingCategory category, List<Finding> items) {
      if (category == FindingCategory.accessibility) {
        return 0;
      }
      if (items.any((f) => f.severity == Severity.critical)) {
        return 1;
      }
      if (items.any((f) => f.severity == Severity.high)) {
        return 2;
      }
      if (items.any((f) => f.severity == Severity.medium)) {
        return 3;
      }
      return 4;
    }

    final categories = grouped.keys.toList()
      ..sort(
        (a, b) => priorityFor(a, grouped[a]!).compareTo(
          priorityFor(b, grouped[b]!),
        ),
      );

    final plan = <ActionPlanItem>[];
    var priority = 1;

    for (final category in categories) {
      final items = grouped[category]!
        ..sort((a, b) => _severityRank(a.severity).compareTo(_severityRank(b.severity)));

      final effort = _estimateEffort(items);
      plan.add(
        ActionPlanItem(
          priority: priority++,
          category: category,
          findingIds: items.map((f) => f.id).toList(),
          rationale: _rationaleFor(category, items),
          estimatedEffort: effort,
        ),
      );
    }

    return plan;
  }

  int _severityRank(Severity severity) {
    return switch (severity) {
      Severity.critical => 0,
      Severity.high => 1,
      Severity.medium => 2,
      Severity.low => 3,
    };
  }

  String _estimateEffort(List<Finding> items) {
    final large = items.where((f) => f.effort == Effort.large).length;
    final medium = items.where((f) => f.effort == Effort.medium).length;
    if (large > 2) {
      return '> 2 days';
    }
    if (large > 0 || medium > 5) {
      return '1-2 days';
    }
    if (medium > 0) {
      return '4-8 hours';
    }
    return '< 4 hours';
  }

  String _rationaleFor(FindingCategory category, List<Finding> items) {
    final critical = items.where((f) => f.severity == Severity.critical).length;
    final high = items.where((f) => f.severity == Severity.high).length;

    if (category == FindingCategory.accessibility) {
      return 'Accessibility issues affect users with disabilities and may fail WCAG compliance';
    }
    if (critical > 0) {
      return '$critical critical issue(s) in ${category.name} require immediate attention';
    }
    if (high > 0) {
      return '$high high-severity ${category.name} finding(s) impact design system consistency';
    }
    return 'Address ${category.name} findings to improve UI cohesion';
  }
}
