# UI Audit — CI/CD Integration

This guide shows how to run the UI/UX audit tool in pull-request checks and local pre-push workflows.

## Prerequisites

- Flutter SDK (3.10+)
- Repository checked out with `frontend/` present

```bash
cd tools/ui_audit
flutter pub get
```

## Recommended CI job (static-only, incremental)

Static analysis is fast and does not require a display or golden harness. Use **incremental** mode on PRs so only changed Dart files under `frontend/` are analyzed.

```yaml
ui-audit:
  name: UI/UX audit (incremental)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - uses: subosito/flutter-action@v2
      with:
        channel: stable
        cache: true

    - name: Install ui_audit tool
      run: |
        cd tools/ui_audit
        flutter pub get

    - name: Run incremental static audit
      run: |
        cd tools/ui_audit
        dart run ui_audit:ui_audit \
          --config=../../.kiro/audit-config-quick.yaml \
          --incremental \
          --ci \
          --fail-on=high
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: ui-audit-report
        path: .kiro/audit-reports/
        if-no-files-found: ignore
```

### Why incremental + quick config?

| Mode | When to use |
|------|-------------|
| `--incremental --static-only` | PR checks; analyzes git-changed `frontend/**/*.dart` |
| `--incremental-base=origin/main...HEAD` | CI pull requests (also via `UI_AUDIT_DIFF_BASE`) |
| `.kiro/audit-config-ci.yaml` | CI preset: spacing + typography + accessibility, static only |
| `.kiro/audit-config-quick.yaml` | Local quick pass: spacing + typography only |
| `--ci --fail-on=high` | Exit 1 when high/critical findings remain (CI default after typography baseline cleanup) |

Full-category audits (all 9 categories) are better suited for scheduled nightly jobs or manual release gates.

## Full audit (scheduled / manual)

```yaml
- name: Full static audit
  run: |
    cd tools/ui_audit
    dart run ui_audit:ui_audit \
      --config=../../.kiro/audit-config.yaml \
      --static-only \
      --ci \
      --fail-on=critical
```

Runtime fixture inspection (touch targets, semantics) requires the Flutter tool:

```bash
./scripts/run_ui_audit.sh --config=../../.kiro/audit-config-accessibility.yaml --ci
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success; thresholds not exceeded |
| 1 | Audit failed (`--ci` + severity threshold exceeded) or runtime error |
| 64 | Invalid CLI arguments |

## Tuning for CI

Edit `.kiro/audit-config.yaml` (or a CI-specific copy):

```yaml
audit:
  minimumSeverity: medium   # ignore low-severity noise in CI
  thresholds:
    failOnCritical: true
    failOnHigh: false         # warn-only for high until baseline is clean
    maxFindings: 200          # cap report size
```

## Local pre-push hook (optional)

```bash
#!/bin/sh
cd tools/ui_audit || exit 1
dart run ui_audit:ui_audit \
  --config=../../.kiro/audit-config-quick.yaml \
  --incremental \
  --static-only
```

## Incremental path resolution

`--incremental` runs `git diff --name-only HEAD` from the **repository root**, then keeps only `.dart` files under the configured `projectPath` (typically `frontend/`). This avoids double-prefix bugs when git paths already include `frontend/`.

## Baseline strategy

1. ~~Start with `--fail-on=critical` only (current CI default).~~
2. Run full static audit locally; fix or suppress systematic false positives in analyzers.
3. CI now uses `--fail-on=high` (quick audit baseline: 0 high as of 2026-05-23 after typography scale helpers).
4. Optionally track finding counts in a JSON artifact and fail on regressions.

### Analyzer heuristics (reduces noise)

- `SizedBox` with a `child` → layout width/height, not spacing.
- `typography.body` / `typography?.meta` → treated as Studio typography scale (not only `StudioTypography` literal).
- `SizedBox(height: 2)` → medium (micro spacing), not high.

## Related files

- Tool README: `tools/ui_audit/README.md`
- Example configs: `.kiro/audit-config*.yaml`
- Sample report excerpt: `tools/ui_audit/examples/sample-audit-report.md`
