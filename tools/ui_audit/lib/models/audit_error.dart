import 'package:json_annotation/json_annotation.dart';

part 'audit_error.g.dart';

/// Represents an error that occurred during the audit process
@JsonSerializable()
class AuditError {
  /// Phase where the error occurred
  /// (e.g., 'static_analysis', 'runtime_inspection', 'report_generation')
  final String phase;
  
  /// File being processed when the error occurred
  final String file;
  
  /// Error message
  final String message;
  
  /// Optional stack trace
  final String? stackTrace;

  const AuditError({
    required this.phase,
    required this.file,
    required this.message,
    this.stackTrace,
  });

  factory AuditError.fromJson(Map<String, dynamic> json) =>
      _$AuditErrorFromJson(json);

  Map<String, dynamic> toJson() => _$AuditErrorToJson(this);

  @override
  String toString() {
    return '[$phase] Error in $file: $message';
  }
}
