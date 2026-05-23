# Sample UI/UX Audit Report (excerpt)

This is a truncated example from a quick static audit (`spacing` + `typography`) on the Toonflow `frontend/` tree.

**Date:** 2026-05-23  
**Project:** `frontend/`  
**Files analyzed:** 677  
**Findings (medium+):** 217 medium, **0 high** (after shared `studio_*` text style helpers)  

## Summary

| Severity | Count |
|----------|------:|
| high     | 0     |
| medium   | 217   |

## Example findings

### SP-008: Non-standard spacing value

- **Severity:** medium  
- **Category:** spacing  
- **Location:** `frontend/lib/account/section.dart:613`

SizedBox.width uses hardcoded spacing `6.0` instead of `StudioSpacing`.

**Recommendation:** Use `StudioSpacing.xs` (8) or a semantic layout token.

```dart
const SizedBox(width: 6)
```

### TY-001: Hardcoded font size deviates from StudioTypography

- **Severity:** medium  
- **Category:** typography  

Text widget uses hardcoded `fontSize: 19.0` instead of a `StudioTypography` reference.

**Recommendation:** Replace with the nearest design-system text style.

## Report formats

Full runs emit timestamped files under `.kiro/audit-reports/`:

- `audit-<timestamp>.json` — CI / tooling integration  
- `audit-<timestamp>.md` — human review  
- `audit-<timestamp>.html` — filterable dashboard (when enabled in config)

## Interpreting severity

| Level  | Typical action                          |
|--------|-----------------------------------------|
| critical | Block merge; accessibility / broken UX |
| high     | Fix in current sprint                  |
| medium   | Track in design-system cleanup         |
| low      | Optional polish                        |
