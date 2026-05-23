import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';
import 'finding.dart';

part 'audit_summary.g.dart';

/// Summary statistics for the audit
@JsonSerializable(explicitToJson: true)
class AuditSummary {
  /// Total number of findings
  final int totalFindings;
  
  /// Findings grouped by severity
  final Map<Severity, int> bySeverity;
  
  /// Findings grouped by category
  final Map<FindingCategory, int> byCategory;

  const AuditSummary({
    required this.totalFindings,
    required this.bySeverity,
    required this.byCategory,
  });

  factory AuditSummary.fromJson(Map<String, dynamic> json) =>
      _$AuditSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$AuditSummaryToJson(this);

  /// Creates a summary from a list of findings
  factory AuditSummary.fromFindings(List<Finding> findings) {
    final bySeverity = <Severity, int>{
      for (final s in Severity.values) s: 0,
    };
    final byCategory = <FindingCategory, int>{
      for (final c in FindingCategory.values) c: 0,
    };

    for (final finding in findings) {
      bySeverity[finding.severity] = (bySeverity[finding.severity] ?? 0) + 1;
      byCategory[finding.category] = (byCategory[finding.category] ?? 0) + 1;
    }

    return AuditSummary(
      totalFindings: findings.length,
      bySeverity: bySeverity,
      byCategory: byCategory,
    );
  }
}
