import 'package:json_annotation/json_annotation.dart';
import 'finding.dart';
import 'audit_error.dart';
import 'audit_metadata.dart';
import 'audit_summary.dart';
import 'action_plan_item.dart';
import 'enums.dart';

part 'audit_result.g.dart';

/// Complete result of an audit execution
@JsonSerializable(explicitToJson: true)
class AuditResult {
  /// Metadata about the audit
  final AuditMetadata metadata;
  
  /// Summary statistics
  final AuditSummary summary;
  
  /// List of all findings
  final List<Finding> findings;
  
  /// List of errors encountered during the audit
  final List<AuditError> errors;
  
  /// Prioritized action plan
  final List<ActionPlanItem> actionPlan;

  const AuditResult({
    required this.metadata,
    required this.summary,
    required this.findings,
    required this.errors,
    required this.actionPlan,
  });

  factory AuditResult.fromJson(Map<String, dynamic> json) =>
      _$AuditResultFromJson(json);

  Map<String, dynamic> toJson() => _$AuditResultToJson(this);

  /// Returns true if the audit should fail based on severity thresholds
  bool shouldFail({
    required bool failOnCritical,
    required bool failOnHigh,
  }) {
    if (failOnCritical && summary.bySeverity[Severity.critical]! > 0) {
      return true;
    }
    if (failOnHigh && summary.bySeverity[Severity.high]! > 0) {
      return true;
    }
    return false;
  }
}
