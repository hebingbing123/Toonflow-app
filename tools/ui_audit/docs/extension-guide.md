# UI Audit — Extension Guide

## Add a static analyzer

1. Create `lib/analyzers/my_analyzer.dart` extending `StaticAnalyzer`.
2. Register it in `lib/analyzers/static_analysis_runner.dart`.
3. Add `FindingCategory` in `lib/models/enums.dart` if needed.
4. Add tests under `test/analyzers/my_analyzer_test.dart`.
5. Enable the category in `.kiro/audit-config.yaml`.

## Add a remediation template

1. Add logic in `lib/remediation/` (see `spacing_fix.dart`).
2. Wire category handling in `lib/remediation/auto_fix_applicator.dart`.
3. Run `ui_audit fix --report=... --dry-run` before applying.

## Metrics and trends

Each audit appends one JSON line to `.kiro/audit-metrics/history.jsonl`.

```bash
dart run ui_audit:ui_audit report --trend
```

## Related specs

- Detection MVP: [frontend-ui-ux-audit/tasks.md](../../../.kiro/specs/frontend-ui-ux-audit/tasks.md)
- Improvements (remediation + monitoring): [frontend-ui-ux-improvements/tasks.md](../../../.kiro/specs/frontend-ui-ux-improvements/tasks.md)
