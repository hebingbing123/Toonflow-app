# Changelog

## 1.1.1 — 2026-05-23

### Fixed

- `ui_audit fix` resolves `frontend/` from repo root when run inside `tools/ui_audit/` (`FixValidator` + `ConfigParser.resolveProjectDirectory`)

## 1.1.0 — 2026-05-23

### Added

- `ui_audit fix --report=<json>` — automated spacing/typography fixes with optional `flutter analyze` validation
- `ui_audit report --trend` — metrics history and regression summary (`.kiro/audit-metrics/history.jsonl`)
- `lib/remediation/` — `AutoFixApplicator`, `FixValidator`, spacing/typography fix helpers
- `lib/monitoring/` — `MetricsTracker`, `TrendAnalyzer`
- Extension guide: `docs/extension-guide.md`

### Changed

- Audit runs append metrics to JSONL history
- `scripts/auto_fix.dart` delegates to `AutoFixApplicator`

## 1.0.0

- Initial static + runtime auditors, CLI audit command, CI integration
