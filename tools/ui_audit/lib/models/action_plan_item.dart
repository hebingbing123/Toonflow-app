import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'action_plan_item.g.dart';

/// Represents a prioritized action item in the audit report
@JsonSerializable()
class ActionPlanItem {
  /// Priority order (1 = highest priority)
  final int priority;
  
  /// Category of findings this action addresses
  final FindingCategory category;
  
  /// IDs of findings included in this action
  final List<String> findingIds;
  
  /// Rationale for this priority level
  final String rationale;
  
  /// Estimated effort to complete this action
  final String estimatedEffort;

  const ActionPlanItem({
    required this.priority,
    required this.category,
    required this.findingIds,
    required this.rationale,
    required this.estimatedEffort,
  });

  factory ActionPlanItem.fromJson(Map<String, dynamic> json) =>
      _$ActionPlanItemFromJson(json);

  Map<String, dynamic> toJson() => _$ActionPlanItemToJson(this);
}
