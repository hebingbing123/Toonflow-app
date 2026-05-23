import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';
import 'location.dart';
import 'before_after.dart';

part 'finding.g.dart';

/// Represents a single audit finding
@JsonSerializable(explicitToJson: true)
class Finding {
  /// Unique identifier for this finding (e.g., "VH-001")
  final String id;
  
  /// Category of the finding
  final FindingCategory category;
  
  /// Severity level
  final Severity severity;
  
  /// Short title describing the issue
  final String title;
  
  /// Detailed description of the issue
  final String description;
  
  /// Location in the codebase
  final Location location;
  
  /// Optional code snippet showing the issue
  final String? codeSnippet;
  
  /// Recommendation for fixing the issue
  final String recommendation;
  
  /// Reference to the design system component or token
  final String? designSystemReference;
  
  /// Estimated effort to fix
  final Effort effort;
  
  /// Optional before/after code examples
  final BeforeAfter? beforeAfter;
  
  /// Optional screenshot path
  final String? screenshot;

  const Finding({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
    this.codeSnippet,
    required this.recommendation,
    this.designSystemReference,
    required this.effort,
    this.beforeAfter,
    this.screenshot,
  });

  factory Finding.fromJson(Map<String, dynamic> json) =>
      _$FindingFromJson(json);

  Map<String, dynamic> toJson() => _$FindingToJson(this);

  @override
  String toString() {
    return '[$severity] $id: $title at ${location.file}:${location.line}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Finding &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
