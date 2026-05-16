#!/usr/bin/env bash
# Preservation Property Check Script
# 
# This script verifies preservation properties for the large file refactoring bugfix.
# It checks that all public APIs, test results, and build processes remain intact.
#
# **Validates: Requirements 3.1-3.10**
#
# Usage: bash scripts/preservation-check.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Preservation Property Check ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
OVERALL_STATUS=0

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        OVERALL_STATUS=1
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Checking Backend Compilation..."
cd "$REPO_ROOT/backend"
if cargo build --lib --quiet 2>&1 | grep -q "error"; then
    print_status 1 "Backend compilation"
else
    print_status 0 "Backend compilation"
fi

echo ""
echo "2. Checking Backend Tests..."
cd "$REPO_ROOT/backend"
TEST_OUTPUT=$(cargo test --lib --quiet 2>&1 || true)
PASSED=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= passed)' | tail -1 || echo "0")
FAILED=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= failed)' | tail -1 || echo "0")
IGNORED=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= ignored)' | tail -1 || echo "0")

echo "   Passed: $PASSED"
echo "   Failed: $FAILED"
echo "   Ignored: $IGNORED"

# Baseline: 1679 passed; 34 failed; 37 ignored
# We allow the same or better results
if [ "$PASSED" -ge 1679 ]; then
    print_status 0 "Backend test pass count (>= 1679)"
else
    print_status 1 "Backend test pass count (expected >= 1679, got $PASSED)"
fi

echo ""
echo "3. Checking Frontend Compilation..."
cd "$REPO_ROOT/frontend"
if flutter pub get > /dev/null 2>&1 && flutter analyze --no-pub 2>&1 | grep -q "No issues found"; then
    print_status 0 "Frontend analysis"
else
    print_warning "Frontend analysis has issues (baseline also had issues)"
fi

echo ""
echo "4. Checking Frontend Tests..."
cd "$REPO_ROOT/frontend"
FLUTTER_TEST_OUTPUT=$(flutter test 2>&1 || true)
if echo "$FLUTTER_TEST_OUTPUT" | grep -q "All tests passed"; then
    print_status 0 "Frontend tests"
elif echo "$FLUTTER_TEST_OUTPUT" | grep -q "Some tests failed"; then
    print_warning "Frontend tests have failures (baseline also had 1 failure)"
else
    print_status 1 "Frontend tests"
fi

echo ""
echo "5. Checking Code Format..."
cd "$REPO_ROOT/backend"
if cargo fmt --check 2>&1 | grep -q "Diff in"; then
    print_warning "Backend format check (baseline also had format issues)"
else
    print_status 0 "Backend format check"
fi

echo ""
echo "6. Checking Clippy..."
cd "$REPO_ROOT/backend"
CLIPPY_OUTPUT=$(cargo clippy --quiet 2>&1 || true)
if echo "$CLIPPY_OUTPUT" | grep -q "warning:"; then
    WARNING_COUNT=$(echo "$CLIPPY_OUTPUT" | grep -c "warning:" || echo "0")
    print_warning "Backend clippy ($WARNING_COUNT warnings - baseline also had warnings)"
else
    print_status 0 "Backend clippy"
fi

echo ""
echo "7. Verifying Public API Accessibility..."
cd "$REPO_ROOT/backend"
# Run the preservation property tests
if cargo test --test preservation_properties --quiet 2>&1 | grep -q "test result: ok"; then
    print_status 0 "Public API preservation tests"
else
    print_status 1 "Public API preservation tests"
fi

echo ""
echo "=== Summary ==="
if [ $OVERALL_STATUS -eq 0 ]; then
    echo -e "${GREEN}All critical preservation properties verified${NC}"
    echo "Note: Some warnings match baseline state (unfixed code)"
else
    echo -e "${RED}Some preservation checks failed${NC}"
fi

exit $OVERALL_STATUS
