import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'audit_configuration.g.dart';

/// Configuration for the audit process
@JsonSerializable()
class AuditConfiguration {
  /// Path to the Flutter project to audit
  final String projectPath;
  
  /// Paths to include in the audit (glob patterns)
  final List<String> includePaths;
  
  /// Paths to exclude from the audit (glob patterns)
  final List<String> excludePaths;
  
  /// Categories to analyze
  final List<FindingCategory> enabledCategories;
  
  /// Minimum severity level to report
  final Severity minimumSeverity;
  
  /// Viewport widths to test for responsive behavior
  final List<int> testBreakpoints;
  
  /// Whether to capture screenshots
  final bool captureScreenshots;
  
  /// Whether to run runtime inspection (requires running the app)
  final bool runRuntimeInspection;
  
  /// Output formats (json, markdown, html)
  final List<String> outputFormats;
  
  /// Output directory for reports
  final String outputDirectory;
  
  /// Whether to include before/after examples
  final bool includeBeforeAfter;
  
  /// Whether to fail on critical findings (for CI)
  final bool failOnCritical;
  
  /// Whether to fail on high severity findings (for CI)
  final bool failOnHigh;
  
  /// Maximum number of findings before stopping
  final int? maxFindings;

  const AuditConfiguration({
    required this.projectPath,
    this.includePaths = const ['lib/**/*.dart'],
    this.excludePaths = const [
      'lib/generated/**',
      'lib/**/*.g.dart',
      'lib/**/*.freezed.dart',
    ],
    this.enabledCategories = const [
      FindingCategory.visualHierarchy,
      FindingCategory.spacing,
      FindingCategory.typography,
      FindingCategory.colorSystem,
      FindingCategory.interactiveElements,
      FindingCategory.emptyStates,
      FindingCategory.responsiveness,
      FindingCategory.componentConsistency,
      FindingCategory.accessibility,
    ],
    this.minimumSeverity = Severity.low,
    this.testBreakpoints = const [520, 720, 760, 1100, 1280, 1720],
    this.captureScreenshots = true,
    this.runRuntimeInspection = true,
    this.outputFormats = const ['json', 'markdown'],
    this.outputDirectory = '.kiro/audit-reports/',
    this.includeBeforeAfter = true,
    this.failOnCritical = true,
    this.failOnHigh = false,
    this.maxFindings,
  });

  factory AuditConfiguration.fromJson(Map<String, dynamic> json) =>
      _$AuditConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$AuditConfigurationToJson(this);

  /// Creates a configuration from a YAML map
  factory AuditConfiguration.fromYaml(Map<String, dynamic> yaml) {
    final auditConfig = yaml['audit'] as Map<String, dynamic>? ?? {};
    final runtimeConfig = auditConfig['runtime'] as Map<String, dynamic>? ?? {};
    final outputConfig = auditConfig['output'] as Map<String, dynamic>? ?? {};
    final thresholdsConfig = auditConfig['thresholds'] as Map<String, dynamic>? ?? {};

    return AuditConfiguration(
      projectPath: auditConfig['projectPath'] as String? ?? 'frontend/',
      includePaths: (auditConfig['include'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['lib/**/*.dart'],
      excludePaths: (auditConfig['exclude'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'lib/generated/**',
            'lib/**/*.g.dart',
            'lib/**/*.freezed.dart',
          ],
      enabledCategories: (auditConfig['categories'] as List<dynamic>?)
              ?.map((e) => _parseFindingCategory(e.toString()))
              .toList() ??
          const [
            FindingCategory.visualHierarchy,
            FindingCategory.spacing,
            FindingCategory.typography,
            FindingCategory.colorSystem,
            FindingCategory.interactiveElements,
            FindingCategory.emptyStates,
            FindingCategory.responsiveness,
            FindingCategory.componentConsistency,
            FindingCategory.accessibility,
          ],
      minimumSeverity: _parseSeverity(
          auditConfig['minimumSeverity'] as String? ?? 'low'),
      testBreakpoints: (runtimeConfig['breakpoints'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [520, 720, 760, 1100, 1280, 1720],
      captureScreenshots: runtimeConfig['captureScreenshots'] as bool? ?? true,
      runRuntimeInspection: runtimeConfig['enabled'] as bool? ?? true,
      outputFormats: (outputConfig['formats'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['json', 'markdown'],
      outputDirectory:
          outputConfig['directory'] as String? ?? '.kiro/audit-reports/',
      includeBeforeAfter: outputConfig['includeBeforeAfter'] as bool? ?? true,
      failOnCritical: thresholdsConfig['failOnCritical'] as bool? ?? true,
      failOnHigh: thresholdsConfig['failOnHigh'] as bool? ?? false,
      maxFindings: thresholdsConfig['maxFindings'] as int?,
    );
  }

  static FindingCategory _parseFindingCategory(String value) {
    return FindingCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Invalid category: $value'),
    );
  }

  static Severity _parseSeverity(String value) {
    return Severity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Invalid severity: $value'),
    );
  }
}
