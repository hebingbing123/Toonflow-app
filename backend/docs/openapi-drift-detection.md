# OpenAPI Drift Detection and Contract Consistency

## Overview

This document describes the OpenAPI drift detection and rust_api contract consistency checking system implemented in Phase K.6. These automated checks ensure that:

1. The OpenAPI specification stays synchronized with the actual API implementation
2. The Dart rust_api client remains consistent with backend API contracts
3. Breaking changes are detected before they reach production
4. Contract violations are caught in CI/CD pipeline

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Backend (Rust)                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  utoipa annotations on handlers and types            │  │
│  │  ↓                                                    │  │
│  │  combined_openapi() merges all domain APIs           │  │
│  │  ↓                                                    │  │
│  │  export-openapi binary generates YAML                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              OpenAPI Drift Detection                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Generate current spec                            │  │
│  │  2. Compare with baseline (scripts/fixtures/)        │  │
│  │  3. Detect additions, removals, breaking changes     │  │
│  │  4. Report drift with actionable messages            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│           rust_api Consistency Check                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  1. Extract paths from OpenAPI spec                  │  │
│  │  2. Verify Dart client structure                     │  │
│  │  3. Check endpoint coverage                          │  │
│  │  4. Detect stale references                          │  │
│  │  5. Validate response types                          │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Gate                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  scripts/refactor-check.sh runs all checks           │  │
│  │  ↓                                                    │  │
│  │  Fail build if drift or inconsistency detected       │  │
│  │  ↓                                                    │  │
│  │  Provide clear error messages and remediation steps  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## OpenAPI Drift Detection

### How It Works

1. **Baseline Creation**: The first time the check runs, it creates a baseline OpenAPI spec at `scripts/fixtures/openapi_baseline.yaml`
2. **Generation**: On each check, generates current OpenAPI spec from Rust code
3. **Comparison**: Diffs current spec against baseline
4. **Analysis**: Detects breaking changes (removed endpoints, removed required fields)
5. **Reporting**: Provides detailed diff and actionable remediation steps

### Usage

#### Check for Drift

```bash
bash scripts/check_openapi_drift.sh
```

**Exit codes:**
- `0`: No drift detected
- `1`: Non-breaking drift detected
- `2`: Breaking changes detected

#### Update Baseline

After intentional API changes:

```bash
bash scripts/check_openapi_drift.sh --update-baseline
```

This updates the baseline to match the current implementation.

### Breaking Change Detection

The script automatically detects:

1. **Removed Endpoints**: Paths that existed in baseline but are missing in current spec
2. **Removed Required Fields**: Required fields that were removed from request/response schemas
3. **New Required Fields**: New required fields added (potentially breaking for clients)

### Example Output

#### No Drift

```
==> Generating current OpenAPI spec...
==> Comparing with baseline...
✓ No OpenAPI drift detected
```

#### Drift Detected

```
==> Generating current OpenAPI spec...
==> Comparing with baseline...
✗ OpenAPI drift detected!

Changes detected between baseline and current implementation:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Lines added:   15
  Lines removed: 3

⚠ BREAKING: Endpoints removed

Diff preview (first 50 lines):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--- scripts/fixtures/openapi_baseline.yaml
+++ /tmp/openapi_generated_12345.yaml
@@ -100,6 +100,9 @@
   /api/v1/metrics/sli:
     get:
       summary: Get SLI status
+      parameters:
+        - name: window_minutes
+          in: query
...

Actions:
  1. Review changes above
  2. If changes are intentional, update baseline:
     bash scripts/check_openapi_drift.sh --update-baseline
  3. If changes are unintentional, fix the implementation
  4. Update rust_api Dart client if needed:
     bash scripts/regenerate_rust_api.sh

FAIL: Breaking changes detected
```

## rust_api Consistency Check

### How It Works

1. **Spec Extraction**: Generates OpenAPI spec and extracts all paths
2. **Structure Validation**: Verifies rust_api directory structure
3. **Domain Coverage**: Checks that expected domain modules exist
4. **Endpoint Coverage**: Verifies critical endpoints are referenced in Dart code
5. **Type Validation**: Checks that response types are defined
6. **Stale Detection**: Identifies endpoints in Dart code that don't exist in spec

### Usage

```bash
bash scripts/check_rust_api_consistency.sh
```

**Exit codes:**
- `0`: All checks passed
- `1`: Consistency issues detected

### Checks Performed

#### 1. Core Module Structure

Verifies that `frontend/lib/rust_api/core.dart` and `index.dart` exist.

#### 2. Domain Modules

Checks for expected domain directories:
- `assets/`
- `production/`
- `project/`
- `scripts/`
- `system/`
- `jobs/`
- `harness/`

#### 3. Critical Endpoint Coverage

Verifies that critical endpoints are referenced in rust_api:
- `/api/v1/health`
- `/api/v1/projects`
- `/api/v1/metrics`
- `/api/v1/metrics/sli`

#### 4. Response Type Definitions

Checks for critical schema definitions:
- `HealthResponse`
- `ErrorBody`
- `MetricsResponse`
- `SliStatusResponse`

#### 5. Stale Endpoint Detection

Identifies endpoints referenced in Dart code that don't exist in OpenAPI spec.

### Example Output

#### All Checks Passed

```
==> Generating OpenAPI spec...
==> Checking rust_api consistency...
Check 1: Core module structure...
  ✓ core.dart exists
Check 2: Index module...
  ✓ index.dart exists
Check 3: Domain modules...
  ✓ Domain exists: assets
  ✓ Domain exists: production
  ✓ Domain exists: project
  ✓ Domain exists: scripts
  ✓ Domain exists: system
  ✓ Domain exists: jobs
  ✓ Domain exists: harness
Check 4: Critical endpoint coverage...
  ✓ Endpoint referenced: /api/v1/health
  ✓ Endpoint referenced: /api/v1/projects
  ✓ Endpoint referenced: /api/v1/metrics
  ✓ Endpoint referenced: /api/v1/metrics/sli
Check 5: Response type definitions...
  ✓ Schema defined: HealthResponse
  ✓ Schema defined: ErrorBody
  ✓ Schema defined: MetricsResponse
  ✓ Schema defined: SliStatusResponse
Check 6: Stale endpoint detection...
  ✓ Valid endpoint: /api/v1/health
  ✓ Valid endpoint: /api/v1/projects
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ rust_api consistency check passed

Summary: All critical checks passed
```

#### Issues Detected

```
==> Generating OpenAPI spec...
==> Checking rust_api consistency...
Check 1: Core module structure...
  ✓ core.dart exists
Check 2: Index module...
  ✓ index.dart exists
Check 3: Domain modules...
  ✓ Domain exists: assets
  ✗ Missing domain: billing
Check 4: Critical endpoint coverage...
  ✓ Endpoint referenced: /api/v1/health
  ✗ Endpoint not found in rust_api: /api/v1/billing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ rust_api consistency issues detected: 2

Summary: 2 issue(s) found

Actions:
  1. Review issues above
  2. Regenerate rust_api if needed:
     bash scripts/regenerate_rust_api.sh
  3. Update OpenAPI annotations if backend changed
```

## Integration with CI/CD

### refactor-check.sh

The checks are integrated into `scripts/refactor-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> merged OpenAPI export (YAML parse)"
(cd backend && cargo run --quiet --bin export-openapi) | ruby -ryaml -e "YAML.load(STDIN.read)"

echo "==> OpenAPI drift detection"
bash scripts/check_openapi_drift.sh

echo "==> rust_api contract consistency"
bash scripts/check_rust_api_consistency.sh

echo "==> backend/ (fmt, clippy, test)"
# ... rest of checks
```

### CI Workflow

The checks run automatically in `.github/workflows/ci.yml` via the `refactor-monorepo` job:

```yaml
- name: Refactor check
  run: bash scripts/refactor-check.sh
```

**Build will fail if:**
- OpenAPI drift is detected
- rust_api consistency issues are found
- Any other refactor check fails

## Development Workflow

### Making API Changes

1. **Update Rust Code**: Modify handlers, types, or utoipa annotations
2. **Run Local Check**: `bash scripts/refactor-check.sh`
3. **Review Drift**: If drift detected, review changes
4. **Update Baseline**: If changes are intentional:
   ```bash
   bash scripts/check_openapi_drift.sh --update-baseline
   ```
5. **Update rust_api**: If needed:
   ```bash
   bash scripts/regenerate_rust_api.sh
   ```
6. **Commit Changes**: Include baseline and rust_api updates in commit
7. **Push**: CI will verify consistency

### Handling Drift in CI

If CI fails due to drift:

1. **Pull Latest**: Ensure you have latest baseline
2. **Regenerate Locally**: Run checks locally
3. **Review Changes**: Understand what changed
4. **Update Baseline**: If intentional, update and commit
5. **Fix Implementation**: If unintentional, fix code
6. **Update rust_api**: Regenerate if needed
7. **Push Again**: CI should pass

## Baseline Management

### Location

Baseline is stored at: `scripts/fixtures/openapi_baseline.yaml`

### When to Update

Update baseline when:
- Adding new endpoints
- Modifying existing endpoints
- Changing request/response schemas
- Updating OpenAPI metadata

### Version Control

- **Commit baseline**: Always commit baseline updates
- **Review diffs**: Review baseline diffs in PRs
- **Document changes**: Include API changes in commit message

### Baseline Conflicts

If baseline conflicts in merge:

1. **Resolve conflict**: Manually merge or regenerate
2. **Regenerate baseline**: Run with `--update-baseline`
3. **Verify**: Run full refactor check
4. **Commit**: Commit resolved baseline

## rust_api Regeneration

### Current Status

The `scripts/regenerate_rust_api.sh` script is currently a placeholder. Actual regeneration depends on your code generation setup.

### Implementation Options

#### Option 1: OpenAPI Generator

```bash
# Install openapi-generator-cli
npm install -g @openapitools/openapi-generator-cli

# Generate Dart client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g dart \
  -o frontend/lib/rust_api \
  --additional-properties=pubName=rust_api
```

#### Option 2: Custom Generator

Create a custom Dart code generator that:
1. Parses OpenAPI spec
2. Generates Dart classes for schemas
3. Generates API client methods
4. Handles authentication and error handling

#### Option 3: Manual Updates

For small projects, manually update rust_api based on OpenAPI changes.

### Recommended Approach

For this project, we recommend:

1. **Start with manual updates**: Keep rust_api manually maintained
2. **Add generation later**: Implement automated generation when needed
3. **Use consistency checks**: Rely on checks to catch drift
4. **Document patterns**: Document rust_api patterns for consistency

## Testing

### Unit Tests

No unit tests needed - these are integration checks.

### Integration Tests

The checks themselves are integration tests:
- They run against real code
- They verify actual contracts
- They catch real drift

### Manual Testing

To manually test the checks:

1. **Test drift detection**:
   ```bash
   # Make a change to an endpoint
   # Run drift check
   bash scripts/check_openapi_drift.sh
   # Should detect drift
   ```

2. **Test baseline update**:
   ```bash
   # Update baseline
   bash scripts/check_openapi_drift.sh --update-baseline
   # Run check again
   bash scripts/check_openapi_drift.sh
   # Should pass
   ```

3. **Test consistency check**:
   ```bash
   # Run consistency check
   bash scripts/check_rust_api_consistency.sh
   # Review output
   ```

4. **Test CI integration**:
   ```bash
   # Run full refactor check
   bash scripts/refactor-check.sh
   # Should include all checks
   ```

## Monitoring and Alerts

### Metrics to Track

1. **Drift frequency**: How often drift is detected
2. **Baseline updates**: How often baseline is updated
3. **CI failures**: How often CI fails due to drift
4. **Time to fix**: Time from drift detection to resolution

### Recommended Alerts

1. **Drift detected in CI**: Alert team when drift fails CI
2. **Stale baseline**: Alert if baseline hasn't been updated in X days
3. **Consistency failures**: Alert on rust_api consistency issues

## Troubleshooting

### Issue: Drift check fails but no changes made

**Cause**: Baseline may be out of sync with main branch

**Solution**:
```bash
git pull origin main
bash scripts/check_openapi_drift.sh --update-baseline
```

### Issue: Consistency check fails for valid endpoints

**Cause**: Endpoint may use different naming pattern

**Solution**: Update consistency check to handle pattern

### Issue: CI fails but local check passes

**Cause**: Different Ruby/Rust versions or missing dependencies

**Solution**: Ensure CI and local environments match

### Issue: Baseline conflicts in merge

**Cause**: Multiple PRs updating API simultaneously

**Solution**:
```bash
# Regenerate baseline from current code
bash scripts/check_openapi_drift.sh --update-baseline
git add scripts/fixtures/openapi_baseline.yaml
git commit -m "Regenerate OpenAPI baseline after merge"
```

## Related Features

- **K.1**: Version conflict detection (prevents concurrent write conflicts)
- **K.3**: Standardized error messages (consistent error format)
- **K.4**: Cross-panel snapshot versioning (detects stale data)
- **K.5**: Metrics and SLI (monitors critical paths)

## Future Enhancements

1. **Automated rust_api generation**: Implement full code generation
2. **Semantic versioning**: Track API versions and breaking changes
3. **Change documentation**: Auto-generate API changelog
4. **Client SDK generation**: Generate SDKs for multiple languages
5. **Contract testing**: Add Pact or similar contract tests
6. **Backward compatibility**: Verify backward compatibility automatically
7. **API deprecation**: Track and enforce deprecation policies
8. **Performance regression**: Detect performance regressions in API

## References

- OpenAPI Specification: https://swagger.io/specification/
- utoipa documentation: https://docs.rs/utoipa/
- OpenAPI Generator: https://openapi-generator.tech/
- Contract Testing: https://pact.io/

## Conclusion

The OpenAPI drift detection and rust_api consistency checking system provides automated contract governance for the API. It ensures that:

- API contracts stay synchronized with implementation
- Breaking changes are detected early
- Client code stays consistent with backend
- CI/CD pipeline enforces contract compliance

This reduces integration issues, improves API reliability, and provides confidence when making API changes.
