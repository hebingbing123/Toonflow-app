/// Categorizes findings by the type of design system violation
enum FindingCategory {
  visualHierarchy,
  spacing,
  typography,
  colorSystem,
  interactiveElements,
  emptyStates,
  responsiveness,
  componentConsistency,
  accessibility,
}

/// Severity levels for audit findings
enum Severity {
  critical,
  high,
  medium,
  low,
}

/// Estimated effort to fix a finding
enum Effort {
  small,
  medium,
  large,
}

/// Classification of spacing values relative to the design system
enum SpacingClassification {
  /// Matches StudioSpacing constant (8, 16, 24, 32)
  aligned,
  
  /// Matches legacy semantic value (10, 12, 14, 18)
  legacy,
  
  /// Multiple of 4, within reasonable range (4-48)
  halfGrid,
  
  /// Does not match any pattern
  nonStandard,
}
