#!/usr/bin/env bash
# rust_api consistency check: verify Dart client matches backend API contracts
# Usage: bash scripts/check_rust_api_consistency.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OPENAPI_SPEC="${OPENFLOW_OPENAPI_SPEC:-/tmp/openapi_for_consistency_$$.yaml}"
CONSISTENCY_REPORT="/tmp/rust_api_consistency_$$.txt"
OPENAPI_SPEC_FROM_ENV=false

if [ -n "${OPENFLOW_OPENAPI_SPEC:-}" ]; then
    OPENAPI_SPEC_FROM_ENV=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cleanup() {
    if [ "$OPENAPI_SPEC_FROM_ENV" = false ]; then
        rm -f "$OPENAPI_SPEC"
    fi
    rm -f "$CONSISTENCY_REPORT"
}
trap cleanup EXIT

if [ "$OPENAPI_SPEC_FROM_ENV" = true ]; then
    echo "==> Reusing pre-generated OpenAPI spec from \$OPENFLOW_OPENAPI_SPEC"
else
    echo "==> Generating OpenAPI spec..."
    (cd backend && cargo run --quiet --bin export-openapi) > "$OPENAPI_SPEC"
fi

echo "==> Checking rust_api consistency..."

# Extract all paths from OpenAPI spec
OPENAPI_PATHS=$(ruby -ryaml -e "
spec = YAML.load(File.read('$OPENAPI_SPEC'))
paths = spec['paths'] || {}
paths.keys.sort.each { |p| puts p }
" 2>/dev/null || echo "")

if [ -z "$OPENAPI_PATHS" ]; then
    echo -e "${RED}ERROR: Could not extract paths from OpenAPI spec${NC}" >&2
    exit 1
fi

# Check if rust_api directory exists
if [ ! -d "frontend/lib/rust_api" ]; then
    echo -e "${RED}ERROR: rust_api directory not found at frontend/lib/rust_api${NC}" >&2
    exit 1
fi

# Initialize report
echo "rust_api Consistency Report" > "$CONSISTENCY_REPORT"
echo "Generated: $(date)" >> "$CONSISTENCY_REPORT"
echo "" >> "$CONSISTENCY_REPORT"

ISSUES=0

# Check 1: Verify core.dart exists and has basic structure
echo "Check 1: Core module structure..." | tee -a "$CONSISTENCY_REPORT"
if [ ! -f "frontend/lib/rust_api/core.dart" ]; then
    echo "  ✗ Missing core.dart" | tee -a "$CONSISTENCY_REPORT"
    ISSUES=$((ISSUES + 1))
else
    echo "  ✓ core.dart exists" | tee -a "$CONSISTENCY_REPORT"
fi

# Check 2: Verify index.dart exists
echo "Check 2: Index module..." | tee -a "$CONSISTENCY_REPORT"
if [ ! -f "frontend/lib/rust_api/index.dart" ]; then
    echo "  ✗ Missing index.dart" | tee -a "$CONSISTENCY_REPORT"
    ISSUES=$((ISSUES + 1))
else
    echo "  ✓ index.dart exists" | tee -a "$CONSISTENCY_REPORT"
fi

# Check 3: Verify domain modules exist for major API groups
echo "Check 3: Domain modules..." | tee -a "$CONSISTENCY_REPORT"
EXPECTED_DOMAINS=("assets" "production" "project" "scripts" "system" "jobs" "harness")
for domain in "${EXPECTED_DOMAINS[@]}"; do
    if [ ! -d "frontend/lib/rust_api/$domain" ]; then
        echo "  ✗ Missing domain: $domain" | tee -a "$CONSISTENCY_REPORT"
        ISSUES=$((ISSUES + 1))
    else
        echo "  ✓ Domain exists: $domain" | tee -a "$CONSISTENCY_REPORT"
    fi
done

# Check 4: Verify critical endpoints are referenced in Dart code
echo "Check 4: Critical endpoint coverage..." | tee -a "$CONSISTENCY_REPORT"
CRITICAL_ENDPOINTS=(
    "/api/v1/health"
    "/api/v1/projects"
)

for endpoint in "${CRITICAL_ENDPOINTS[@]}"; do
    # Search for endpoint reference in rust_api directory
    if grep -r -q "$endpoint" frontend/lib/rust_api/ 2>/dev/null; then
        echo "  ✓ Endpoint referenced: $endpoint" | tee -a "$CONSISTENCY_REPORT"
    else
        echo "  ✗ Endpoint not found in rust_api: $endpoint" | tee -a "$CONSISTENCY_REPORT"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check new endpoints (K.5 metrics) - informational only
echo "Check 4b: New endpoint coverage (informational)..." | tee -a "$CONSISTENCY_REPORT"
NEW_ENDPOINTS=(
    "/api/v1/metrics"
    "/api/v1/metrics/sli"
)

for endpoint in "${NEW_ENDPOINTS[@]}"; do
    if grep -r -q "$endpoint" frontend/lib/rust_api/ 2>/dev/null; then
        echo "  ✓ New endpoint referenced: $endpoint" | tee -a "$CONSISTENCY_REPORT"
    else
        echo "  ℹ New endpoint not yet in rust_api: $endpoint" | tee -a "$CONSISTENCY_REPORT"
    fi
done

# Check 5: Verify response types exist for critical schemas
echo "Check 5: Response type definitions..." | tee -a "$CONSISTENCY_REPORT"
CRITICAL_SCHEMAS=(
    "HealthResponse"
    "ErrorBody"
    "MetricsResponse"
    "SliStatusResponse"
)

for schema in "${CRITICAL_SCHEMAS[@]}"; do
    # Search for class/type definition in rust_api
    if grep -r -q "class $schema" frontend/lib/rust_api/ 2>/dev/null; then
        echo "  ✓ Schema defined: $schema" | tee -a "$CONSISTENCY_REPORT"
    else
        echo "  ⚠ Schema not found: $schema (may use different name)" | tee -a "$CONSISTENCY_REPORT"
    fi
done

# Check 6: Verify no stale endpoint references
echo "Check 6: Stale endpoint detection..." | tee -a "$CONSISTENCY_REPORT"
# Extract all /api/v1/* paths from Dart files
DART_ENDPOINTS=$(
    ruby 2>/dev/null <<'RUBY' || echo ""
paths = Dir.glob('frontend/lib/rust_api/**/*.dart').sort
found = []
paths.each do |path|
  text = File.read(path)
  text.scan(/['"](\/api\/v1\/[^'"]*)['"]/).each do |match|
    endpoint = match.first
    endpoint = endpoint.gsub(/\$[A-Za-z_][A-Za-z0-9_]*/, '{param}')
    found << endpoint
  end
end
puts found.uniq.sort
RUBY
)

if [ -n "$DART_ENDPOINTS" ]; then
    while IFS= read -r dart_endpoint; do
        # Check if this endpoint exists in OpenAPI spec
        if echo "$OPENAPI_PATHS" | grep -q "^$dart_endpoint$"; then
            echo "  ✓ Valid endpoint: $dart_endpoint" >> "$CONSISTENCY_REPORT"
        else
            # Check if it's a parameterized path (simple check - just see if any similar path exists)
            BASE_PATH=$(echo "$dart_endpoint" | sed 's/{[^}]*}//g' | sed 's/\/\//\//g')
            if echo "$OPENAPI_PATHS" | grep -q "$BASE_PATH"; then
                echo "  ✓ Valid parameterized endpoint: $dart_endpoint" >> "$CONSISTENCY_REPORT"
            else
                echo "  ⚠ Potentially stale endpoint: $dart_endpoint" | tee -a "$CONSISTENCY_REPORT"
            fi
        fi
    done <<< "$DART_ENDPOINTS"
else
    echo "  ⚠ No /api/v1/* endpoints found in rust_api (may use different pattern)" | tee -a "$CONSISTENCY_REPORT"
fi

echo "" | tee -a "$CONSISTENCY_REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$CONSISTENCY_REPORT"

if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✓ rust_api consistency check passed${NC}" | tee -a "$CONSISTENCY_REPORT"
    echo "" | tee -a "$CONSISTENCY_REPORT"
    echo "Summary: All critical checks passed" | tee -a "$CONSISTENCY_REPORT"
    exit 0
else
    echo -e "${YELLOW}⚠ rust_api consistency issues detected: $ISSUES${NC}" | tee -a "$CONSISTENCY_REPORT"
    echo "" | tee -a "$CONSISTENCY_REPORT"
    echo "Summary: $ISSUES issue(s) found" | tee -a "$CONSISTENCY_REPORT"
    echo "" | tee -a "$CONSISTENCY_REPORT"
    echo "Actions:" | tee -a "$CONSISTENCY_REPORT"
    echo "  1. Review issues above" | tee -a "$CONSISTENCY_REPORT"
    echo "  2. Regenerate rust_api if needed:" | tee -a "$CONSISTENCY_REPORT"
    echo "     bash scripts/regenerate_rust_api.sh" | tee -a "$CONSISTENCY_REPORT"
    echo "  3. Update OpenAPI annotations if backend changed" | tee -a "$CONSISTENCY_REPORT"
    echo "" | tee -a "$CONSISTENCY_REPORT"
    echo "Full report saved to: $CONSISTENCY_REPORT" | tee -a "$CONSISTENCY_REPORT"
    exit 1
fi
