# UI/UX Audit Tool

A comprehensive UI/UX audit tool for Flutter applications that systematically evaluates design system compliance, accessibility, and user experience quality.

## Overview

This tool analyzes Flutter codebases to identify:

- **Visual Hierarchy Issues**: Inconsistent typography, heading levels, and contrast ratios
- **Spacing Violations**: Deviations from the 8px grid system
- **Typography Problems**: Hardcoded font sizes, incorrect line heights, missing design system references
- **Color System Misuse**: Hardcoded colors, incorrect token usage
- **Interactive Element Issues**: Missing hover/focus states, inadequate touch targets
- **Empty State Problems**: Missing or incomplete empty state handling
- **Responsiveness Issues**: Layout breaks at different viewport sizes
- **Component Inconsistencies**: Duplicate implementations, theme violations
- **Accessibility Violations**: WCAG 2.1 AA compliance issues

## Installation

```bash
cd tools/ui_audit
flutter pub get
```

## Usage

Preset configs (from repo root):

| Config | Scope |
|--------|--------|
| `.kiro/audit-config.yaml` | Full audit (static + runtime) |
| `.kiro/audit-config-ci.yaml` | CI preset (spacing + typography, static, `--fail-on=high`) |
| `.kiro/audit-config-quick.yaml` | Spacing + typography, static only |
| `.kiro/audit-config-burn-down.yaml` | Full static inventory (local burn-down, `maxFindings: 10000`) |
| `.kiro/audit-config-accessibility.yaml` | Accessibility + interactive elements |

### Run Full Audit (static + runtime fixtures)

Runtime inspection needs the Flutter tool:

```bash
cd tools/ui_audit
./scripts/run_ui_audit.sh --config=../../.kiro/audit-config.yaml
```

### Static Analysis Only

Plain `dart run` works when runtime is disabled (`--static-only` or preset quick config):

```bash
dart run ui_audit:ui_audit --config=../../.kiro/audit-config-quick.yaml
```

### Run with Custom Configuration

```bash
dart run ui_audit:ui_audit --config=path/to/config.yaml
```

### Run Specific Categories

```bash
dart run ui_audit:ui_audit --categories=spacing --categories=typography
```

### Static Analysis Only

```bash
dart run ui_audit:ui_audit --static-only --config=../../.kiro/audit-config.yaml
```

### CI Mode

```bash
dart run ui_audit:ui_audit --ci --fail-on=critical
```

### Incremental (git changed files only)

```bash
dart run ui_audit:ui_audit --incremental --static-only
```

### Apply automated fixes

```bash
dart run ui_audit:ui_audit fix --report=.kiro/audit-reports/audit-<timestamp>.json --dry-run
dart run ui_audit:ui_audit fix --report=.kiro/audit-reports/audit-<timestamp>.json
```

### Metrics and trends

Each audit appends to `<repo>/.kiro/audit-metrics/history.jsonl` (gitignored).

```bash
dart run ui_audit:ui_audit report --trend
```

### Burn-down verification (local)

```bash
cd tools/ui_audit
dart run ui_audit:ui_audit --config=../../.kiro/audit-config-burn-down.yaml
dart run ui_audit:ui_audit --config=../../.kiro/audit-config-quick.yaml
```

See also [docs/extension-guide.md](docs/extension-guide.md) and [CHANGELOG.md](CHANGELOG.md).

## Configuration

Create a configuration file at `.kiro/audit-config.yaml`:

```yaml
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
  
  output:
    formats: [json, markdown, html]
    directory: .kiro/audit-reports/
    includeBeforeAfter: true
  
  thresholds:
    failOnCritical: true
    failOnHigh: false
    maxFindings: 200
```

## Output

The audit generates reports in multiple formats:

- **JSON**: Machine-readable format for CI/CD integration
- **Markdown**: Human-readable format with code examples
- **HTML**: Interactive report with filtering and sorting

Reports are saved to `.kiro/audit-reports/` by default.

## Architecture

The tool consists of three main components:

1. **Static Code Analyzer**: Parses Dart/Flutter source files using AST analysis
2. **Runtime Inspector**: Executes the app to validate runtime behavior
3. **Report Generator**: Produces structured, actionable reports

## Development

### Generate JSON Serialization Code

```bash
dart run build_runner build
```

### Run Tests

```bash
flutter test
```

Note: `ui_audit` depends on the Flutter SDK for runtime inspection. Use `flutter test` (not plain `dart test`).

## CI/CD Integration

See [docs/ci-integration.md](docs/ci-integration.md) for GitHub Actions examples, incremental PR checks, and threshold tuning.

## Requirements

- Dart SDK >= 3.0.0
- Flutter (for runtime inspection)

## License

See LICENSE file in the project root.
