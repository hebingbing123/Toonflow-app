#!/usr/bin/env bash
# OpenAPI drift detection: compare generated spec with baseline
# Usage: bash scripts/check_openapi_drift.sh [--update-baseline]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE="scripts/fixtures/openapi_baseline.yaml"
GENERATED="${OPENFLOW_OPENAPI_SPEC:-/tmp/openapi_generated_$$.yaml}"
DIFF_OUTPUT="/tmp/openapi_diff_$$.txt"
GENERATED_FROM_ENV=false

if [ -n "${OPENFLOW_OPENAPI_SPEC:-}" ]; then
    GENERATED_FROM_ENV=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cleanup() {
    if [ "$GENERATED_FROM_ENV" = false ]; then
        rm -f "$GENERATED"
    fi
    rm -f "$DIFF_OUTPUT"
}
trap cleanup EXIT

if [ "$GENERATED_FROM_ENV" = true ]; then
    echo "==> Reusing pre-generated OpenAPI spec from \$OPENFLOW_OPENAPI_SPEC"
else
    echo "==> Generating current OpenAPI spec..."
    (cd backend && cargo run --quiet --bin export-openapi) > "$GENERATED"
fi

# Validate YAML is parseable
if ! ruby -ryaml -e "YAML.load(File.read('$GENERATED'))" 2>/dev/null; then
    echo -e "${RED}ERROR: Generated OpenAPI is not valid YAML${NC}" >&2
    exit 1
fi

# Check if baseline exists
if [ ! -f "$BASELINE" ]; then
    echo -e "${YELLOW}WARN: No baseline found at $BASELINE${NC}"
    echo "Creating initial baseline..."
    mkdir -p "$(dirname "$BASELINE")"
    cp "$GENERATED" "$BASELINE"
    echo -e "${GREEN}✓ Baseline created${NC}"
    exit 0
fi

# Update baseline if requested
if [ "${1:-}" = "--update-baseline" ]; then
    echo "Updating baseline..."
    cp "$GENERATED" "$BASELINE"
    echo -e "${GREEN}✓ Baseline updated at $BASELINE${NC}"
    exit 0
fi

# Compare generated with baseline
echo "==> Comparing with baseline..."
if diff -u "$BASELINE" "$GENERATED" > "$DIFF_OUTPUT" 2>&1; then
    echo -e "${GREEN}✓ No OpenAPI drift detected${NC}"
    exit 0
fi

# Drift detected - analyze changes
echo -e "${RED}✗ OpenAPI drift detected!${NC}"
echo ""
echo "Changes detected between baseline and current implementation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show summary of changes
ADDED=$(grep -c "^+" "$DIFF_OUTPUT" || true)
REMOVED=$(grep -c "^-" "$DIFF_OUTPUT" || true)
echo "  Lines added:   $ADDED"
echo "  Lines removed: $REMOVED"
echo ""

# Detect breaking changes
BREAKING=0
if grep -q "^-.*paths:" "$DIFF_OUTPUT" 2>/dev/null; then
    echo -e "${RED}⚠ BREAKING: Endpoints removed${NC}"
    BREAKING=1
fi
if grep -q "^-.*required:" "$DIFF_OUTPUT" 2>/dev/null; then
    echo -e "${RED}⚠ BREAKING: Required fields removed${NC}"
    BREAKING=1
fi
if grep -q "^+.*required:" "$DIFF_OUTPUT" 2>/dev/null; then
    echo -e "${YELLOW}⚠ POTENTIALLY BREAKING: New required fields added${NC}"
fi

echo ""
echo "Diff preview (first 50 lines):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
head -n 50 "$DIFF_OUTPUT"
if [ "$(wc -l < "$DIFF_OUTPUT")" -gt 50 ]; then
    echo "... (truncated, see full diff at $DIFF_OUTPUT)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Actions:"
echo "  1. Review changes above"
echo "  2. If changes are intentional, update baseline:"
echo "     bash scripts/check_openapi_drift.sh --update-baseline"
echo "  3. If changes are unintentional, fix the implementation"
echo "  4. Update rust_api Dart client if needed:"
echo "     bash scripts/regenerate_rust_api.sh"
echo ""

if [ "$BREAKING" -eq 1 ]; then
    echo -e "${RED}FAIL: Breaking changes detected${NC}"
    exit 2
else
    echo -e "${YELLOW}FAIL: Non-breaking drift detected${NC}"
    exit 1
fi
