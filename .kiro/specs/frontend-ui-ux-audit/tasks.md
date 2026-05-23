# Implementation Plan: Frontend UI/UX Audit

## Overview

This implementation plan breaks down the Frontend UI/UX Audit system into five phases, following the architecture outlined in the design document. The system consists of three main components: Static Code Analyzer (Dart-based AST parsing), Runtime Inspector (Flutter testing framework), and Report Generator (structured output with severity ratings and recommendations).

The implementation uses Dart as the primary language, leveraging the `analyzer` package for static analysis and `flutter_test` for runtime inspection.

## Tasks

- [x] 1. Set up project structure and core data models
  - Create `tools/ui_audit/` directory structure
  - Define core data models: `Finding`, `Location`, `AuditConfiguration`, `AuditResult`, `AuditError`
  - Define enums: `FindingCategory`, `Severity`, `Effort`, `SpacingClassification`
  - Set up `pubspec.yaml` with dependencies (`analyzer: ^6.0.0`, `path: ^1.8.0`, `yaml: ^3.1.0`, `args: ^2.4.0`)
  - Create configuration file schema and parser for `.kiro/audit-config.yaml`
  - _Requirements: 10.1, 10.4, 10.5_

- [x] 2. Implement Static Code Analyzer - Core Infrastructure
  - [x] 2.1 Implement AST Parser module
    - Create `ast_parser.dart` to parse `.dart` files using `analyzer` package
    - Build symbol table of widgets, styles, and theme references
    - Extract widget properties (colors, sizes, spacing, typography)
    - Implement file traversal with include/exclude pattern support
    - _Requirements: 1.2, 1.7, 2.1, 3.7, 4.1_
  
  - [x] 2.2 Implement Visual Hierarchy Analyzer
    - Create `visual_hierarchy_analyzer.dart`
    - Detect text widgets and extract font size, weight, and style
    - Map text widgets to StudioTypography scale (pageTitle, dialogTitle, cardTitle, etc.)
    - Implement heading hierarchy validation algorithm
    - Implement contrast ratio calculation using WCAG 2.1 formula
    - Flag contrast ratios below 4.5:1 (body) or 3:1 (large text)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7_
  
  - [x] 2.3 Write property test for Visual Hierarchy Analyzer
    - **Property 1: Hardcoded value detection accuracy**
    - **Property 2: Contrast ratio calculation correctness**
    - **Property 3: Heading hierarchy validation correctness**
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.7, 9.8**
  
  - [x] 2.4 Implement Spacing Analyzer
    - Create `spacing_analyzer.dart`
    - Extract padding, margin, gap, and SizedBox values from AST
    - Implement spacing classification algorithm (aligned, legacy, half-grid, non-standard)
    - Compare against StudioSpacing constants (xs=8, sm=16, md=24, lg=32)
    - Compare against StudioLayoutSpacing semantic values
    - Flag values below 4px or above 48px
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  
  - [x] 2.5 Write property test for Spacing Analyzer
    - **Property 4: Spacing classification correctness**
    - **Property 5: Spacing range validation**
    - **Validates: Requirements 2.1, 2.3, 2.7**

- [x] 3. Implement Static Code Analyzer - Typography and Color
  - [x] 3.1 Implement Typography Analyzer
    - Create `typography_analyzer.dart`
    - Validate text widgets use StudioTypography references
    - Check line-height values (1.2-1.5 range)
    - Verify font family references (Inter, Space Grotesk)
    - Validate font weight usage (w400, w500, w600, w700)
    - Check color token usage (textPrimary, textSecondary, textMuted)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 3.8_
  
  - [x] 3.2 Write property test for Typography Analyzer
    - **Property 6: Line-height validation**
    - **Validates: Requirements 3.5**
  
  - [x] 3.3 Implement Color System Analyzer
    - Create `color_system_analyzer.dart`
    - Identify all Color instantiations in AST
    - Classify as StudioTokens reference vs hardcoded
    - Validate semantic usage (backgrounds, borders, interactive, status, overlays)
    - Flag misuse of glass tokens (overlay surfaces only)
    - Detect Colors.white, Colors.black, hex literals outside StudioTokens
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_
  
  - [x] 3.4 Write property test for Color System Analyzer
    - **Property 7: Color token validation**
    - **Property 8: Glass token misuse detection**
    - **Validates: Requirements 3.7, 4.1, 4.6, 4.8**

- [x] 4. Implement Static Code Analyzer - Component Consistency and Accessibility
  - [x] 4.1 Implement Component Consistency Analyzer
    - Create `component_consistency_analyzer.dart`
    - Detect duplicate widget implementations
    - Validate theme usage (CardTheme, DialogTheme, InputDecorationTheme, MenuTheme, ChipTheme, SnackBarTheme)
    - Check card radius (14px), input radius (10px), chip radius (999px)
    - Identify custom-styled components deviating from design system
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9_
  
  - [x] 4.2 Implement Accessibility Analyzer (Static)
    - Create `accessibility_analyzer_static.dart`
    - Check for semantic labels on Image and Icon widgets
    - Validate form inputs have labels or hints
    - Identify color-only information patterns
    - Check for prefers-reduced-motion handling in animations
    - _Requirements: 9.3, 9.4, 9.6, 9.7, 9.8_
  
  - [x] 4.3 Write property test for Accessibility Analyzer (Static)
    - **Property 16: Semantic label validation**
    - **Property 17: Form input label validation**
    - **Validates: Requirements 9.3, 9.4**

- [x] 5. Checkpoint - Ensure static analyzer tests pass
  - Run all static analyzer unit tests
  - Verify AST parsing works on sample Flutter files
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement Runtime Inspector - Core Infrastructure
  - [x] 6.1 Set up Widget Tree Inspector
    - Create `widget_tree_inspector.dart` using `flutter_test` package
    - Implement widget tree traversal to extract runtime properties
    - Measure actual rendered dimensions and positions
    - Create test harness for running Flutter app in headless mode (`FlutterRuntimeInspector` + `benchmarkWidgets`)
    - _Requirements: 5.1, 5.5, 5.6_
  
  - [x] 6.2 Implement Interactive Element Inspector
    - Create `interactive_element_inspector.dart`
    - Identify all interactive widgets (buttons, inputs, chips, menus)
    - Validate touch target sizes (36px icons, 40-44px buttons, 44px navigation)
    - Simulate hover states and validate visual feedback _(MVP: touch target + disabled opacity)_
    - Simulate focus states and validate focus indicators _(deferred)_
    - Check cursor indication (pointer vs default) _(deferred)_
    - Validate disabled states (opacity 0.38-0.5, non-interactive)
    - Check loading state visual feedback _(deferred)_
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9_
  
  - [x] 6.3 Write property test for Interactive Element Inspector
    - **Property 9: Touch target dimension validation**
    - **Property 10: Button padding validation**
    - **Property 11: Disabled state validation**
    - **Validates: Requirements 5.1, 5.4, 5.5, 5.6, 5.8**

- [x] 7. Implement Runtime Inspector - Empty States and Responsiveness
  - [x] 7.1 Implement Empty State Inspector
    - `empty_state_inspector.dart` (runtime) + `empty_state_analyzer_static.dart` (static)
    - Identify list, grid, and table views
    - Test with empty data to trigger empty states
    - Validate empty state contains descriptive text
    - Validate primary action button presence (when applicable)
    - Check color tokens (textSecondary or textMuted)
    - Flag raw empty containers without treatment
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  
  - [x] 7.2 Write property test for Empty State Inspector
    - **Property 12: Empty state completeness validation**
    - **Property 13: Empty state color validation**
    - **Property 14: Empty state treatment detection**
    - **Validates: Requirements 6.2, 6.3, 6.4, 6.7**
  
  - [x] 7.3 Implement Responsive Behavior Inspector
    - `responsive_behavior_inspector.dart` (runtime) + `responsive_analyzer_static.dart` (static)
    - Run application at multiple viewport widths (520px, 720px, 760px, 1100px, 1280px, 1720px)
    - Validate layout adaptations at each breakpoint
    - Detect overflow and horizontal scrolling
    - Validate two-column collapse behavior
    - Check touch target accessibility at all breakpoints
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_
  
  - [x] 7.4 Write property test for Responsive Behavior Inspector
    - **Property 15: Fixed-width element detection**
    - **Validates: Requirements 7.6**
  
  - [x] 7.5 Implement Accessibility Inspector (Runtime)
    - Create `accessibility_inspector_runtime.dart`
    - Simulate keyboard navigation (Tab, Enter, Space) _(deferred)_
    - Validate focus order follows logical reading order _(semantics order heuristic)_
    - Test screen reader announcements using Semantics tree
    - Validate error message announcements _(deferred)_
    - Test with prefers-reduced-motion enabled _(deferred)_
    - _Requirements: 9.1, 9.2, 9.5, 9.7_

- [x] 8. Checkpoint - Ensure runtime inspector tests pass
  - Run all runtime inspector integration tests
  - Verify widget tree inspection works on sample screens
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement Report Generator
  - [x] 9.1 Implement Findings Aggregator
    - Create `findings_aggregator.dart`
    - Aggregate findings from all analyzers
    - Implement severity assignment rules (Critical, High, Medium, Low)
    - Implement effort estimation rules (Small, Medium, Large)
    - Group findings by category and severity
    - _Requirements: 10.1, 10.4, 10.5, 10.6_
  
  - [x] 9.2 Write property test for Findings Aggregator
    - **Property 18: Severity assignment consistency**
    - **Property 21: Effort estimation consistency**
    - **Property 22: Finding grouping correctness**
    - **Property 23: Summary statistics accuracy**
    - **Validates: Requirements 10.1, 10.4, 10.5, 10.6**
  
  - [x] 9.3 Implement Report Generator - JSON Output
    - Create `report_generator.dart`
    - Generate JSON report with metadata, summary, findings, and action plan
    - Include file location, code snippet, recommendation, and design system reference
    - Include before/after examples for code changes
    - Calculate summary statistics (total findings by severity and category)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_
  
  - [ ] 9.4 Write property test for Report Generator _(covered indirectly via orchestrator integration test)_
    - **Property 19: Finding evidence completeness**
    - **Property 20: Recommendation completeness**
    - **Property 24: Before/after example presence**
    - **Property 25: Action plan prioritization consistency**
    - **Validates: Requirements 10.2, 10.3, 10.7, 10.8**
  
  - [x] 9.5 Implement Report Generator - Markdown and HTML Output
    - Create `markdown_formatter.dart` for human-readable reports
    - Create `html_formatter.dart` for interactive reports
    - Implement syntax highlighting for code snippets
    - Add screenshot embedding support
    - Implement filtering and sorting for HTML reports
    - _Requirements: 10.2, 10.3, 10.7_

- [x] 10. Implement Audit Orchestrator
  - [x] 10.1 Create Audit Orchestrator
    - Create `audit_orchestrator.dart`
    - Coordinate analysis phases (static → runtime → report)
    - Manage configuration and scope
    - Implement error handling and graceful degradation
    - Aggregate findings from all analyzers
    - Handle file parsing failures, runtime inspection failures, screenshot failures
    - _Requirements: 1.1-10.8 (all)_
  
  - [x] 10.2 Implement CLI Interface
    - Create `bin/ui_audit.dart` as CLI entry point
    - Parse command-line arguments using `args` package
    - Support flags: `--categories`, `--static-only`, `--config`, `--format`, `--output`, `--ci`, `--fail-on`, `--incremental`
    - Implement exit codes based on severity thresholds
    - _Requirements: 10.1, 10.8_
  
  - [x] 10.3 Write integration tests for Audit Orchestrator
    - Test end-to-end audit on minimal Flutter app
    - Test static analyzer on sample files with known violations
    - Test runtime inspector on sample screens with known issues
    - Test report generation with sample findings
    - Test CLI argument parsing and exit codes

- [x] 11. Checkpoint - Ensure all integration tests pass _(static + report path; runtime phase stubbed)_
  - Run full audit on sample Flutter application
  - Verify JSON, Markdown, and HTML reports are generated correctly
  - Test CLI with various flags and configurations
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement Performance Optimizations
  - [x] 12.1 Optimize Static Analysis
    - Implement parallel file parsing using isolates _(deferred)_
    - [x] Add AST result caching for unchanged files (mtime-keyed in-memory cache)
    - Implement incremental analysis for large codebases
    - Add filters to skip generated files and third-party packages
    - _Requirements: 1.1-4.8 (performance)_
  
  - [ ] 12.2 Optimize Runtime Inspection
    - Implement parallel test execution for independent screens
    - Add golden file comparison for visual regression detection
    - Implement widget tree snapshot caching
    - Limit screenshot resolution to reduce memory usage
    - _Requirements: 5.1-9.8 (performance)_
  
  - [ ] 12.3 Optimize Report Generation
    - Stream findings to disk instead of holding in memory
    - Generate report sections in parallel
    - Implement lazy loading for large reports
    - Add screenshot compression
    - _Requirements: 10.1-10.8 (performance)_

- [x] 13. Create Documentation and Examples
  - [x] 13.1 Write README for UI Audit Tool
    - Document installation and setup
    - Provide usage examples for CLI
    - Document configuration file format
    - Include troubleshooting guide
  
  - [x] 13.2 Create Example Configuration Files
  
  - [x] 13.3 Create Sample Audit Reports
    - `tools/ui_audit/examples/sample-audit-report.md` (excerpt + interpretation guide)
    - Full reports generated under `.kiro/audit-reports/` when CLI runs

- [x] 14. Final checkpoint and CI integration preparation
  - [x] Run quick static audit on Toonflow frontend (677 files; 267 findings after SizedBox layout heuristic)
  - [x] Tune false positives: skip SizedBox width/height when `child` is present; recognize `typography.*` scale vars; micro spacing (<4px) → medium
  - [x] Test incremental mode with git diff (29 changed files → 19 findings)
  - [x] Prepare CI/CD integration documentation (`tools/ui_audit/docs/ci-integration.md`)
  - [x] Wire GitHub Actions jobs (`ui-audit-tool`, `ui-audit` in `.github/workflows/ci.yml`)
  - [x] Ensure all tests pass (54 tests)

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The implementation follows the five-phase architecture: Static Analyzer → Runtime Inspector → Advanced Analysis → Report Enhancement → CI/CD Integration
- All code will be written in Dart, using the `analyzer` package for static analysis and `flutter_test` for runtime inspection
- The tool will be located in `tools/ui_audit/` directory to keep it separate from the main application code

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.4"] },
    { "id": 2, "tasks": ["2.3", "2.5", "3.1", "3.3"] },
    { "id": 3, "tasks": ["3.2", "3.4", "4.1", "4.2"] },
    { "id": 4, "tasks": ["4.3"] },
    { "id": 5, "tasks": ["6.1"] },
    { "id": 6, "tasks": ["6.2", "7.1", "7.3", "7.5"] },
    { "id": 7, "tasks": ["6.3", "7.2", "7.4"] },
    { "id": 8, "tasks": ["9.1"] },
    { "id": 9, "tasks": ["9.2", "9.3"] },
    { "id": 10, "tasks": ["9.4", "9.5"] },
    { "id": 11, "tasks": ["10.1"] },
    { "id": 12, "tasks": ["10.2", "10.3"] },
    { "id": 13, "tasks": ["12.1", "12.2", "12.3"] },
    { "id": 14, "tasks": ["13.1", "13.2", "13.3"] }
  ]
}
```
