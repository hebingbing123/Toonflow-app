# Design Document: Frontend UI/UX Audit

## Overview

This document specifies the design for a comprehensive UI/UX audit system for the Toonflow Flutter desktop application. The audit system systematically evaluates the codebase against the LumenX-inspired design system, identifying inconsistencies, accessibility issues, and design violations across visual hierarchy, spacing, typography, color usage, interactive elements, empty states, responsiveness, component consistency, and accessibility compliance.

The audit system consists of three main components:

1. **Static Code Analyzer**: Parses Dart/Flutter source files to detect design system violations
2. **Runtime Inspector**: Executes the application at various breakpoints to validate responsive behavior and interactive states
3. **Report Generator**: Produces structured, actionable audit reports with severity ratings, recommendations, and prioritized action plans

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Audit Orchestrator                       │
│  - Coordinates analysis phases                               │
│  - Manages configuration and scope                           │
│  - Aggregates findings from all analyzers                    │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┬──────────────────┐
        │                     │                   │
┌───────▼────────┐  ┌────────▼────────┐  ┌──────▼──────────┐
│ Static Code    │  │ Runtime         │  │ Report          │
│ Analyzer       │  │ Inspector       │  │ Generator       │
│                │  │                 │  │                 │
│ - AST parsing  │  │ - Widget tree   │  │ - Severity      │
│ - Pattern      │  │   inspection    │  │   assignment    │
│   matching     │  │ - Breakpoint    │  │ - Grouping      │
│ - Token        │  │   testing       │  │ - Prioritization│
│   validation   │  │ - Interaction   │  │ - Formatting    │
│                │  │   testing       │  │                 │
└────────────────┘  └─────────────────┘  └─────────────────┘
```

### Data Flow

```
Input: Flutter Source Files + Design System Definitions
  │
  ├─> Static Code Analyzer
  │     │
  │     ├─> Visual Hierarchy Analyzer
  │     ├─> Spacing Analyzer
  │     ├─> Typography Analyzer
  │     ├─> Color System Analyzer
  │     ├─> Component Consistency Analyzer
  │     └─> Accessibility Analyzer (static)
  │
  ├─> Runtime Inspector
  │     │
  │     ├─> Interactive Element Inspector
  │     ├─> Empty State Inspector
  │     ├─> Responsive Behavior Inspector
  │     └─> Accessibility Inspector (runtime)
  │
  └─> Findings Aggregator
        │
        └─> Report Generator
              │
              └─> Output: Structured Audit Report (JSON + Markdown)
```

## Component Design

### 1. Static Code Analyzer

The Static Code Analyzer uses Dart's `analyzer` package to parse Flutter source files into Abstract Syntax Trees (ASTs) and perform pattern matching against design system rules.

#### Core Modules

**1.1 AST Parser**
- Parses `.dart` files in `frontend/lib/` directory
- Builds symbol table of widgets, styles, and theme references
- Extracts widget properties (colors, sizes, spacing, typography)
- Identifies hardcoded values vs design system references

**1.2 Visual Hierarchy Analyzer**
- Detects text widgets and extracts font size, weight, and style
- Maps text widgets to StudioTypography scale (pageTitle, dialogTitle, cardTitle, paneTitle, body, label, hint, meta, display)
- Identifies deviations from typography scale
- Validates heading hierarchy progression (no skipped levels)
- Calculates color contrast ratios using WCAG 2.1 formula
- Flags contrast ratios below 4.5:1 (body text) or 3:1 (large text)

**1.3 Spacing Analyzer**
- Extracts padding, margin, gap, and SizedBox values
- Compares against StudioSpacing constants (xs=8, sm=16, md=24, lg=32)
- Compares against StudioLayoutSpacing semantic values
- Categorizes hardcoded values as:
  - **Aligned**: Matches design system constant
  - **Legacy**: Matches legacy values (10, 12, 14, 18)
  - **Non-standard**: Does not match any known value
- Flags values below 4px or above 48px without semantic justification

**1.4 Typography Analyzer**
- Validates text widgets use StudioTypography references
- Checks line-height values (should be 1.2-1.5)
- Verifies font family references (Inter for body, Space Grotesk for display)
- Validates font weight usage (w400, w500, w600, w700)
- Checks color token usage (textPrimary, textSecondary, textMuted)

**1.5 Color System Analyzer**
- Identifies all Color instantiations
- Classifies as:
  - **StudioTokens reference**: `StudioTokens.of(context).primary`
  - **Hardcoded**: `Color(0xFF7C97FF)`, `Colors.blue`, `#7C97FF`
- Validates semantic usage:
  - Backgrounds: bgBase, bgSurface, bgElevated, bgInset
  - Borders: borderSubtle, borderDefault
  - Interactive: primary, accent, signal
  - Status: danger, warning, success
  - Overlays: glass, glassBorder, overlay
- Flags misuse of glass tokens (should only be on overlay surfaces)

**1.6 Component Consistency Analyzer**
- Detects duplicate widget implementations
- Validates theme usage:
  - Cards: CardTheme with radiusCard (14px) and surfaceHighlight border
  - Dialogs: Consistent padding and title styling
  - Inputs: InputDecorationTheme with radiusButton (10px)
  - Menus: MenuTheme with bgElevated background
  - Chips: ChipTheme with 999px borderRadius
  - Snackbars: SnackBarTheme with floating behavior
- Identifies custom-styled components deviating from design system

**1.7 Accessibility Analyzer (Static)**
- Checks for semantic labels on Image and Icon widgets
- Validates form inputs have labels or hints
- Identifies color-only information patterns
- Checks for prefers-reduced-motion handling in animations

#### Implementation Language

Dart (using `analyzer` package for AST parsing)

#### Key Dependencies

```yaml
dependencies:
  analyzer: ^6.0.0
  path: ^1.8.0
  yaml: ^3.1.0
```

### 2. Runtime Inspector

The Runtime Inspector executes the Flutter application in headless mode at various configurations to validate runtime behavior.

#### Core Modules

**2.1 Widget Tree Inspector**
- Uses Flutter's `WidgetTester` from `flutter_test` package
- Traverses widget tree to extract runtime properties
- Measures actual rendered dimensions and positions
- Validates touch target sizes (minimum 36px for icons, 44px for navigation)

**2.2 Interactive Element Inspector**
- Identifies all interactive widgets (buttons, inputs, chips, menus)
- Validates hover states by simulating pointer hover
- Validates focus states by simulating keyboard focus
- Checks cursor indication (pointer vs default)
- Validates disabled states (opacity 0.38-0.5, non-interactive)
- Checks loading state visual feedback

**2.3 Empty State Inspector**
- Identifies list, grid, and table views
- Tests with empty data to trigger empty states
- Validates empty state contains:
  - Descriptive text explaining why empty
  - Primary action button (when applicable)
  - Correct color tokens (textSecondary or textMuted)
- Flags raw empty containers without treatment

**2.4 Responsive Behavior Inspector**
- Runs application at multiple viewport widths:
  - 520px (mobile narrow)
  - 720px (mobile wide / tablet portrait)
  - 760px (tablet landscape)
  - 1100px (desktop two-column threshold)
  - 1280px (typography compact → regular)
  - 1720px (typography regular → large)
- Validates layout adaptations at each breakpoint
- Detects overflow and horizontal scrolling
- Validates two-column collapse behavior
- Checks touch target accessibility at all breakpoints

**2.5 Accessibility Inspector (Runtime)**
- Simulates keyboard navigation (Tab, Enter, Space)
- Validates focus order follows logical reading order
- Tests screen reader announcements (using Semantics tree)
- Validates error message announcements
- Tests with prefers-reduced-motion enabled

#### Implementation Language

Dart (using `flutter_test` package)

#### Key Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

### 3. Report Generator

The Report Generator aggregates findings from all analyzers and produces structured, actionable reports.

#### Report Structure

```json
{
  "metadata": {
    "auditDate": "2025-01-15T10:30:00Z",
    "auditVersion": "1.0.0",
    "projectPath": "/path/to/frontend",
    "filesAnalyzed": 247,
    "widgetsInspected": 1523
  },
  "summary": {
    "totalFindings": 142,
    "bySeverity": {
      "critical": 8,
      "high": 23,
      "medium": 67,
      "low": 44
    },
    "byCategory": {
      "visualHierarchy": 18,
      "spacing": 34,
      "typography": 21,
      "colorSystem": 29,
      "interactiveElements": 15,
      "emptyStates": 7,
      "responsiveness": 9,
      "componentConsistency": 6,
      "accessibility": 3
    }
  },
  "findings": [
    {
      "id": "VH-001",
      "category": "visualHierarchy",
      "severity": "high",
      "title": "Hardcoded font size deviates from StudioTypography",
      "description": "Text widget uses hardcoded fontSize: 19 instead of StudioTypography reference",
      "location": {
        "file": "lib/features/projects/project_card.dart",
        "line": 45,
        "column": 12
      },
      "codeSnippet": "Text('Project Title', style: TextStyle(fontSize: 19))",
      "recommendation": "Use StudioTypography.of(context).cardTitle (16-17px depending on profile)",
      "designSystemReference": "StudioTypography.cardTitle",
      "effort": "small",
      "beforeAfter": {
        "before": "Text('Project Title', style: TextStyle(fontSize: 19))",
        "after": "Text('Project Title', style: TextStyle(fontSize: StudioTypography.of(context).cardTitle))"
      }
    }
  ],
  "actionPlan": [
    {
      "priority": 1,
      "category": "accessibility",
      "findingIds": ["ACC-001", "ACC-002", "ACC-003"],
      "rationale": "Critical accessibility issues affect usability for users with disabilities",
      "estimatedEffort": "2-3 days"
    }
  ]
}
```

#### Severity Assignment Rules

- **Critical**: Accessibility violations (WCAG failures), broken layouts, non-functional interactive elements
- **High**: Significant design system violations, inconsistent component usage, missing empty states
- **Medium**: Hardcoded values that should reference design system, minor spacing inconsistencies
- **Low**: Legacy values that work but should be updated, minor typography deviations

#### Effort Estimation Rules

- **Small**: Single-line fix, simple token replacement (< 30 minutes)
- **Medium**: Multi-line refactor, component restructuring (30 minutes - 2 hours)
- **Large**: Architectural change, multiple file changes, new component creation (> 2 hours)

#### Output Formats

1. **JSON**: Machine-readable format for CI/CD integration
2. **Markdown**: Human-readable format with syntax highlighting and screenshots
3. **HTML**: Interactive report with filtering and sorting

## Data Models

### Finding

```dart
class Finding {
  final String id;
  final FindingCategory category;
  final Severity severity;
  final String title;
  final String description;
  final Location location;
  final String? codeSnippet;
  final String recommendation;
  final String? designSystemReference;
  final Effort effort;
  final BeforeAfter? beforeAfter;
  final String? screenshot;
}

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

enum Severity {
  critical,
  high,
  medium,
  low,
}

enum Effort {
  small,
  medium,
  large,
}
```

### Location

```dart
class Location {
  final String file;
  final int line;
  final int column;
  final String? widgetPath; // e.g., "Scaffold > Column > Card > Text"
}
```

### AuditConfiguration

```dart
class AuditConfiguration {
  final String projectPath;
  final List<String> includePaths;
  final List<String> excludePaths;
  final List<FindingCategory> enabledCategories;
  final Severity minimumSeverity;
  final List<int> testBreakpoints;
  final bool captureScreenshots;
  final bool runRuntimeInspection;
}
```

## Algorithms

### Contrast Ratio Calculation (WCAG 2.1)

```dart
double calculateContrastRatio(Color foreground, Color background) {
  double relativeLuminance(Color color) {
    double toLinear(int channel) {
      final double c = channel / 255.0;
      return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
    }
    
    final double r = toLinear(color.red);
    final double g = toLinear(color.green);
    final double b = toLinear(color.blue);
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  
  final double l1 = relativeLuminance(foreground);
  final double l2 = relativeLuminance(background);
  
  final double lighter = max(l1, l2);
  final double darker = min(l1, l2);
  
  return (lighter + 0.05) / (darker + 0.05);
}

bool meetsWCAG_AA(double contrastRatio, double fontSize) {
  // Large text: >= 18pt (24px) or >= 14pt (18.66px) bold
  final bool isLargeText = fontSize >= 24 || (fontSize >= 18.66 && isBold);
  final double threshold = isLargeText ? 3.0 : 4.5;
  
  return contrastRatio >= threshold;
}
```

### Heading Hierarchy Validation

```dart
List<Finding> validateHeadingHierarchy(List<TextWidget> headings) {
  final List<Finding> findings = [];
  int? previousLevel;
  
  for (final heading in headings) {
    final int currentLevel = getHeadingLevel(heading); // 1-6
    
    if (previousLevel != null && currentLevel > previousLevel + 1) {
      findings.add(Finding(
        category: FindingCategory.visualHierarchy,
        severity: Severity.medium,
        title: 'Heading hierarchy skip detected',
        description: 'Heading level $currentLevel follows level $previousLevel, skipping intermediate levels',
        location: heading.location,
        recommendation: 'Use heading level ${previousLevel + 1} or restructure hierarchy',
      ));
    }
    
    previousLevel = currentLevel;
  }
  
  return findings;
}

int getHeadingLevel(TextWidget widget) {
  // Map StudioTypography to heading levels
  final double fontSize = widget.fontSize;
  if (fontSize >= 28) return 1; // display
  if (fontSize >= 20) return 2; // pageTitle
  if (fontSize >= 16) return 3; // dialogTitle, projectTitle
  if (fontSize >= 15) return 4; // cardTitle, paneTitle
  if (fontSize >= 13) return 5; // body
  return 6; // hint, meta, label
}
```

### Spacing Alignment Detection

```dart
SpacingClassification classifySpacing(double value) {
  // Check design system constants
  const studioSpacing = [8, 16, 24, 32]; // xs, sm, md, lg
  const layoutSpacing = [10, 12, 14, 18]; // legacy semantic values
  
  if (studioSpacing.contains(value)) {
    return SpacingClassification.aligned;
  }
  
  if (layoutSpacing.contains(value)) {
    return SpacingClassification.legacy;
  }
  
  // Check if it's a multiple of 4 (half-grid)
  if (value % 4 == 0 && value >= 4 && value <= 48) {
    return SpacingClassification.halfGrid;
  }
  
  return SpacingClassification.nonStandard;
}

enum SpacingClassification {
  aligned,      // Matches StudioSpacing constant
  legacy,       // Matches legacy semantic value
  halfGrid,     // Multiple of 4, within reasonable range
  nonStandard,  // Does not match any pattern
}
```

### Touch Target Validation

```dart
Finding? validateTouchTarget(Widget widget, Size renderedSize) {
  double minimumSize;
  String targetType;
  
  if (widget is IconButton) {
    minimumSize = 36; // StudioSpacing.iconTouchTarget
    targetType = 'icon button';
  } else if (widget is NavigationItem) {
    minimumSize = 44; // StudioSpacing.navItemTouchTarget
    targetType = 'navigation item';
  } else if (widget is Button) {
    minimumSize = 40; // Minimum standard button height
    targetType = 'button';
  } else {
    return null; // Not an interactive element
  }
  
  if (renderedSize.width < minimumSize || renderedSize.height < minimumSize) {
    return Finding(
      category: FindingCategory.interactiveElements,
      severity: Severity.high,
      title: 'Touch target too small',
      description: '$targetType has size ${renderedSize.width}x${renderedSize.height}, below minimum $minimumSize',
      location: widget.location,
      recommendation: 'Increase size to at least ${minimumSize}x${minimumSize} or use StudioSpacing constants',
      designSystemReference: 'StudioSpacing.iconTouchTarget or StudioSpacing.navItemTouchTarget',
      effort: Effort.small,
    );
  }
  
  return null;
}
```

## Error Handling

### Graceful Degradation

- If AST parsing fails for a file, log error and continue with remaining files
- If runtime inspection fails for a screen, capture error and continue with remaining screens
- If screenshot capture fails, include placeholder and continue
- If contrast calculation encounters invalid colors, flag as error finding

### Error Reporting

```dart
class AuditError {
  final String phase; // 'static_analysis', 'runtime_inspection', 'report_generation'
  final String file;
  final String message;
  final String? stackTrace;
}

class AuditResult {
  final List<Finding> findings;
  final List<AuditError> errors;
  final AuditMetadata metadata;
}
```

## Performance Considerations

### Static Analysis Optimization

- Parse files in parallel using isolates
- Cache AST results for unchanged files
- Use incremental analysis for large codebases
- Skip generated files and third-party packages

### Runtime Inspection Optimization

- Run tests in parallel for independent screens
- Use golden file comparison to detect visual regressions
- Cache widget tree snapshots
- Limit screenshot resolution to reduce memory usage

### Report Generation Optimization

- Stream findings to disk instead of holding in memory
- Generate report sections in parallel
- Use lazy loading for large reports
- Compress screenshots

## Testing Strategy

### Unit Tests

- Test contrast ratio calculation with known color pairs
- Test heading hierarchy validation with various sequences
- Test spacing classification with edge cases
- Test touch target validation with boundary sizes
- Test severity assignment logic
- Test effort estimation logic

### Integration Tests

- Test static analyzer on sample Flutter files with known violations
- Test runtime inspector on sample screens with known issues
- Test report generator with sample findings
- Test end-to-end audit on minimal Flutter app

### Property-Based Tests

See Correctness Properties section below.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Hardcoded value detection accuracy

*For any* Flutter widget with a hardcoded font size, color, or spacing value, the static analyzer SHALL correctly identify it as a deviation from the design system.

**Validates: Requirements 1.2, 1.7, 2.1, 4.1, 4.8**

### Property 2: Contrast ratio calculation correctness

*For any* pair of foreground and background colors, the contrast ratio calculation SHALL produce a value that matches the WCAG 2.1 formula within 0.01 tolerance, and WCAG AA compliance SHALL be correctly determined based on font size.

**Validates: Requirements 1.3, 9.8**

### Property 3: Heading hierarchy validation correctness

*For any* sequence of heading levels, the hierarchy validator SHALL correctly identify all instances where a heading level is skipped (e.g., h1 → h3).

**Validates: Requirements 1.4**

### Property 4: Spacing classification correctness

*For any* spacing value, the classifier SHALL correctly categorize it as aligned (matches StudioSpacing), legacy (10, 12, 14, 18), or non-standard.

**Validates: Requirements 2.1, 2.3**

### Property 5: Spacing range validation

*For any* spacing value below 4px or above 48px, the analyzer SHALL flag it as requiring semantic justification.

**Validates: Requirements 2.7**

### Property 6: Line-height validation

*For any* text element with a line-height value, the analyzer SHALL correctly identify if it falls outside the 1.2-1.5 range.

**Validates: Requirements 3.5**

### Property 7: Color token validation

*For any* color value in the codebase, the analyzer SHALL correctly identify whether it references StudioTokens or is a hardcoded literal (Color(), Colors.*, hex).

**Validates: Requirements 3.7, 4.1, 4.8**

### Property 8: Glass token misuse detection

*For any* usage of glass or glassBorder tokens, the analyzer SHALL correctly identify if it appears on a non-overlay surface.

**Validates: Requirements 4.6**

### Property 9: Touch target dimension validation

*For any* interactive element (button, icon button, navigation item), the runtime inspector SHALL correctly verify if its rendered dimensions meet the minimum size requirements (36px for icons, 40-44px for buttons, 44px for navigation).

**Validates: Requirements 5.1, 5.5, 5.6**

### Property 10: Button padding validation

*For any* button widget, the analyzer SHALL correctly identify if its padding deviates from StudioTypography.buttonPadding or textButtonPadding values.

**Validates: Requirements 5.4**

### Property 11: Disabled state validation

*For any* widget in disabled state, the runtime inspector SHALL correctly verify that opacity is within 0.38-0.5 range and the element is non-interactive.

**Validates: Requirements 5.8**

### Property 12: Empty state completeness validation

*For any* empty state, the inspector SHALL correctly verify the presence of descriptive text, and when applicable, a primary action button.

**Validates: Requirements 6.2, 6.3**

### Property 13: Empty state color validation

*For any* empty state text element, the analyzer SHALL correctly verify it uses textSecondary or textMuted color tokens.

**Validates: Requirements 6.4**

### Property 14: Empty state treatment detection

*For any* view that can display empty content (list, grid, table), the inspector SHALL correctly identify if empty state treatment is missing.

**Validates: Requirements 6.7**

### Property 15: Fixed-width element detection

*For any* element with a fixed width constraint, the analyzer SHALL correctly identify if it prevents responsive adaptation.

**Validates: Requirements 7.6**

### Property 16: Semantic label validation

*For any* Image or Icon widget, the analyzer SHALL correctly identify if a semantic label is missing.

**Validates: Requirements 9.3**

### Property 17: Form input label validation

*For any* form input widget, the analyzer SHALL correctly verify the presence of an associated label or hint.

**Validates: Requirements 9.4**

### Property 18: Severity assignment consistency

*For any* finding, the severity assignment logic SHALL consistently assign the same severity level given the same finding characteristics (category, impact, scope).

**Validates: Requirements 10.1**

### Property 19: Finding evidence completeness

*For any* finding in the report, it SHALL include either a screenshot or a code reference as evidence.

**Validates: Requirements 10.2**

### Property 20: Recommendation completeness

*For any* finding in the report, the recommendation SHALL include a reference to the relevant Design_System component or token.

**Validates: Requirements 10.3**

### Property 21: Effort estimation consistency

*For any* recommended fix, the effort estimation logic SHALL consistently assign the same effort level (Small, Medium, Large) given the same fix characteristics (lines changed, files affected, complexity).

**Validates: Requirements 10.4**

### Property 22: Finding grouping correctness

*For any* set of findings, the report generator SHALL correctly group them by requirement area (Visual Hierarchy, Spacing, Typography, etc.).

**Validates: Requirements 10.5**

### Property 23: Summary statistics accuracy

*For any* set of findings, the summary dashboard SHALL correctly calculate total counts by severity and category.

**Validates: Requirements 10.6**

### Property 24: Before/after example presence

*For any* recommendation where a code change is applicable, the report SHALL include before/after examples.

**Validates: Requirements 10.7**

### Property 25: Action plan prioritization consistency

*For any* set of fixes, the prioritization logic SHALL consistently order them by the same priority rules (accessibility first, then critical severity, then high severity, etc.).

**Validates: Requirements 10.8**

## Implementation Phases

### Phase 1: Static Code Analyzer (Core)
- AST parser and symbol table builder
- Visual hierarchy analyzer
- Spacing analyzer
- Typography analyzer
- Color system analyzer
- Basic report generation (JSON output)

### Phase 2: Runtime Inspector
- Widget tree inspector
- Interactive element inspector
- Empty state inspector
- Responsive behavior inspector

### Phase 3: Advanced Analysis
- Component consistency analyzer
- Accessibility analyzer (static and runtime)
- Duplicate detection
- Pattern matching for common violations

### Phase 4: Report Enhancement
- Markdown and HTML output formats
- Screenshot capture and embedding
- Before/after example generation
- Interactive filtering and sorting

### Phase 5: CI/CD Integration
- Command-line interface
- Configuration file support
- Exit code based on severity thresholds
- Incremental analysis for changed files only

## Configuration

### Example Configuration File

```yaml
# .kiro/audit-config.yaml
audit:
  projectPath: frontend/
  
  include:
    - lib/**/*.dart
  
  exclude:
    - lib/generated/**
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
  
  categories:
    - visualHierarchy
    - spacing
    - typography
    - colorSystem
    - interactiveElements
    - emptyStates
    - responsiveness
    - componentConsistency
    - accessibility
  
  minimumSeverity: low
  
  runtime:
    enabled: true
    breakpoints: [520, 720, 760, 1100, 1280, 1720]
    captureScreenshots: true
    screenshotFormat: png
    screenshotQuality: 80
  
  output:
    formats: [json, markdown, html]
    directory: .kiro/audit-reports/
    includeBeforeAfter: true
    includeScreenshots: true
  
  thresholds:
    failOnCritical: true
    failOnHigh: false
    maxFindings: 200
```

## CLI Interface

```bash
# Run full audit
dart run audit

# Run specific categories
dart run audit --categories=spacing,typography

# Run static analysis only (skip runtime inspection)
dart run audit --static-only

# Run with custom config
dart run audit --config=custom-audit-config.yaml

# Output to specific format
dart run audit --format=markdown --output=audit-report.md

# CI mode (exit code 1 if critical findings)
dart run audit --ci --fail-on=critical

# Incremental mode (only changed files since last commit)
dart run audit --incremental
```

## Dependencies

### Production Dependencies

```yaml
dependencies:
  analyzer: ^6.0.0
  path: ^1.8.0
  yaml: ^3.1.0
  args: ^2.4.0
  json_annotation: ^4.8.0
  markdown: ^7.1.0
```

### Development Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  test: ^1.24.0
```

## Future Enhancements

1. **AI-Powered Recommendations**: Use LLM to generate context-aware fix suggestions
2. **Visual Regression Detection**: Compare screenshots across commits to detect unintended visual changes
3. **Performance Profiling**: Measure render times and identify performance bottlenecks
4. **Design System Evolution Tracking**: Track design system adoption over time
5. **Auto-Fix Mode**: Automatically apply simple fixes (e.g., replace hardcoded values with tokens)
6. **IDE Integration**: Provide real-time feedback in VS Code / Android Studio
7. **Team Metrics**: Track audit scores per team/developer
8. **Historical Trending**: Show improvement/regression trends over time

## References

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Dart Analyzer Package](https://pub.dev/packages/analyzer)
- [Flutter Testing](https://docs.flutter.dev/testing)
- Toonflow Design System: `frontend/lib/design_system/`

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-15  
**Author**: AI Agent (Kiro)  
**Status**: Draft
