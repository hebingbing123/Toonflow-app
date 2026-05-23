# Full static UI/UX audit baseline (2026-05-23)

**Config**: [`.kiro/audit-config.yaml`](../audit-config.yaml) with `--static-only` (all static categories, no runtime).

| Metric | Value |
|--------|-------|
| Files analyzed | 679 |
| Total findings | 200 (capped by `maxFindings: 200` in config) |
| Report JSON | `audit-reports/audit-2026-05-23T10-14-37.202750Z.json` |

## Findings breakdown (capped at 200)

| Category | Count |
|----------|------:|
| spacing | 78 |
| componentConsistency | 69 |
| colorSystem | 51 |
| responsiveness | 2 |

| Severity | Count |
|----------|------:|
| low | 133 |
| high | 51 |
| medium | 16 |

Run locally for uncapped inventory (raise `maxFindings` in config if needed):

```bash
cd tools/ui_audit
dart run ui_audit:ui_audit --config=../../.kiro/audit-config.yaml --static-only
dart run ui_audit:ui_audit report --trend
```

## Burn-down notes

- **Quick preset** ([`audit-config-quick.yaml`](../audit-config-quick.yaml)): spacing + typography only — **0** findings (2026-05-23).
- **Burn-down preset** ([`audit-config-burn-down.yaml`](../audit-config-burn-down.yaml)): all static categories — **0** findings after waves 4–6 (2026-05-23); see [burn-down-progress-2026-05-23.md](./burn-down-progress-2026-05-23.md).
- **Original capped baseline** (this document): 200 findings with `maxFindings: 200` on full config — historical snapshot only.

## Related

- [UI_UX_AUTO_FIX_SUMMARY.md](../UI_UX_AUTO_FIX_SUMMARY.md) — quick preset auto-fix history
- [frontend-ui-ux-improvements/tasks.md](../specs/frontend-ui-ux-improvements/tasks.md) — tool chain progress
