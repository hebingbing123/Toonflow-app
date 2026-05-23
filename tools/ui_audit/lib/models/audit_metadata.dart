import 'package:json_annotation/json_annotation.dart';

part 'audit_metadata.g.dart';

/// Metadata about the audit execution
@JsonSerializable()
class AuditMetadata {
  /// Timestamp when the audit was performed
  final DateTime auditDate;
  
  /// Version of the audit tool
  final String auditVersion;
  
  /// Path to the project that was audited
  final String projectPath;
  
  /// Number of files analyzed
  final int filesAnalyzed;
  
  /// Number of widgets inspected (runtime only)
  final int? widgetsInspected;

  const AuditMetadata({
    required this.auditDate,
    required this.auditVersion,
    required this.projectPath,
    required this.filesAnalyzed,
    this.widgetsInspected,
  });

  factory AuditMetadata.fromJson(Map<String, dynamic> json) =>
      _$AuditMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$AuditMetadataToJson(this);
}
