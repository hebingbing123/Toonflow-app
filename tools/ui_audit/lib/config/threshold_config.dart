import 'package:json_annotation/json_annotation.dart';

part 'threshold_config.g.dart';

/// Configuration for audit thresholds and limits
@JsonSerializable()
class ThresholdConfig {
  /// Minimum touch target size in logical pixels
  final double minTouchTargetSize;
  
  /// Minimum color contrast ratio (WCAG AA standard is 4.5:1 for normal text)
  final double minColorContrastRatio;
  
  /// Minimum font size difference for clear visual hierarchy (in pixels)
  final double minHierarchyFontSizeDiff;
  
  /// Maximum spacing deviation from design system before flagging (in pixels)
  final double maxSpacingDeviation;
  
  /// Maximum number of critical issues before failing CI
  final int? maxCriticalIssues;
  
  /// Maximum number of high severity issues before failing CI
  final int? maxHighSeverityIssues;
  
  /// Maximum total issues before failing CI
  final int? maxTotalIssues;
  
  /// Minimum fix confidence level to auto-apply (0.0 to 1.0)
  final double minAutoFixConfidence;
  
  /// Visual regression tolerance (percentage difference, 0.0 to 1.0)
  final double visualRegressionTolerance;

  const ThresholdConfig({
    this.minTouchTargetSize = 44.0,
    this.minColorContrastRatio = 4.5,
    this.minHierarchyFontSizeDiff = 2.0,
    this.maxSpacingDeviation = 2.0,
    this.maxCriticalIssues,
    this.maxHighSeverityIssues,
    this.maxTotalIssues,
    this.minAutoFixConfidence = 0.9,
    this.visualRegressionTolerance = 0.05,
  });

  factory ThresholdConfig.fromJson(Map<String, dynamic> json) =>
      _$ThresholdConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ThresholdConfigToJson(this);

  /// Creates threshold config from YAML map
  factory ThresholdConfig.fromYaml(Map<String, dynamic> yaml) {
    return ThresholdConfig(
      minTouchTargetSize: (yaml['minTouchTargetSize'] as num?)?.toDouble() ?? 44.0,
      minColorContrastRatio: (yaml['minColorContrastRatio'] as num?)?.toDouble() ?? 4.5,
      minHierarchyFontSizeDiff: (yaml['minHierarchyFontSizeDiff'] as num?)?.toDouble() ?? 2.0,
      maxSpacingDeviation: (yaml['maxSpacingDeviation'] as num?)?.toDouble() ?? 2.0,
      maxCriticalIssues: yaml['maxCriticalIssues'] as int?,
      maxHighSeverityIssues: yaml['maxHighSeverityIssues'] as int?,
      maxTotalIssues: yaml['maxTotalIssues'] as int?,
      minAutoFixConfidence: (yaml['minAutoFixConfidence'] as num?)?.toDouble() ?? 0.9,
      visualRegressionTolerance: (yaml['visualRegressionTolerance'] as num?)?.toDouble() ?? 0.05,
    );
  }

  /// Default thresholds for strict mode (CI)
  static const ThresholdConfig strict = ThresholdConfig(
    minTouchTargetSize: 44.0,
    minColorContrastRatio: 4.5,
    minHierarchyFontSizeDiff: 3.0,
    maxSpacingDeviation: 1.0,
    maxCriticalIssues: 0,
    maxHighSeverityIssues: 5,
    minAutoFixConfidence: 0.95,
    visualRegressionTolerance: 0.02,
  );

  /// Default thresholds for relaxed mode (development)
  static const ThresholdConfig relaxed = ThresholdConfig(
    minTouchTargetSize: 40.0,
    minColorContrastRatio: 3.0,
    minHierarchyFontSizeDiff: 1.5,
    maxSpacingDeviation: 4.0,
    minAutoFixConfidence: 0.8,
    visualRegressionTolerance: 0.1,
  );

  @override
  String toString() {
    return 'ThresholdConfig('
        'minTouchTarget: $minTouchTargetSize, '
        'minContrast: $minColorContrastRatio, '
        'maxCritical: $maxCriticalIssues)';
  }
}
