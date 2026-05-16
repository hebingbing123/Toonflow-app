#!/bin/bash
# Bug Condition Exploration Test
# Property 1: Bug Condition - File Size Exceeds 800 Lines
# 
# This test checks if the 14 identified files exceed 800 lines.
# EXPECTED OUTCOME: This test SHOULD FAIL on unfixed code (proving the bug exists)
# After refactoring, this test should PASS (proving the bug is fixed)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Bug Condition Exploration Test"
echo "Property 1: File Size Exceeds 800 Lines"
echo "=========================================="
echo ""

# Define the 14 files to check (from bugfix.md requirements 1.1-1.14)
FILES=(
    "backend/src/production/workbench/video_prompt_memory/mod.rs"
    "backend/src/production/workbench/meta/generate/tests.rs"
    "backend/src/production/workbench/video/generate.rs"
    "backend/src/production/workbench/video_prompt_memory/tests.rs"
    "backend/src/production/workbench/meta/generate/builder.rs"
    "backend/src/production/workbench/meta/generate/memory.rs"
    "backend/src/production/workbench/video_prompt_memory/rejected.rs"
    "backend/src/production/workbench/meta/generate/director.rs"
    "backend/src/prompting/quality/handlers/aggregates.rs"
    "backend/src/app/pg_contract_tests/production_suite/production_workbench_video_roundtrip.rs"
    "frontend/lib/agent_workspaces/contexts/production/support.dart"
    "frontend/lib/projects/workbenches/agent_memory_view.dart"
    "frontend/lib/rust_api/benchmark/api.dart"
    "frontend/lib/quality_reviews/workbench_view.dart"
)

LIMIT=800
FAILED_COUNT=0
PASSED_COUNT=0
declare -a COUNTEREXAMPLES

echo "Checking 14 files against 800-line limit..."
echo ""

resolve_file_path() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "$file"
        return 0
    fi

    case "$file" in
        *.rs)
            local mod_candidate="${file%.rs}/mod.rs"
            if [ -f "$mod_candidate" ]; then
                echo "$mod_candidate"
                return 0
            fi
            ;;
    esac

    return 1
}

for FILE in "${FILES[@]}"; do
    RESOLVED_FILE="$(resolve_file_path "$FILE")"
    if [ -z "$RESOLVED_FILE" ]; then
        echo -e "${RED}✗ MISSING: $FILE${NC}"
        echo "  File does not exist"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        COUNTEREXAMPLES+=("$FILE: FILE NOT FOUND")
        continue
    fi
    
    # Count lines in the file
    ACTUAL_LINES=$(wc -l < "$RESOLVED_FILE" | tr -d ' ')
    
    # Calculate how many times it exceeds the limit
    MULTIPLIER=$(awk "BEGIN {printf \"%.1f\", $ACTUAL_LINES/$LIMIT}")
    if [ "$RESOLVED_FILE" != "$FILE" ]; then
        RESOLVED_NOTE=" -> $RESOLVED_FILE"
    else
        RESOLVED_NOTE=""
    fi
    
    if [ "$ACTUAL_LINES" -gt "$LIMIT" ]; then
        echo -e "${RED}✗ EXCEEDS LIMIT: $FILE${RESOLVED_NOTE}${NC}"
        echo "  Actual: $ACTUAL_LINES lines (exceeds limit by ${MULTIPLIER}x)"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        COUNTEREXAMPLES+=("$FILE${RESOLVED_NOTE}: $ACTUAL_LINES lines (exceeds limit by ${MULTIPLIER}x)")
    else
        echo -e "${GREEN}✓ COMPLIANT: $FILE${RESOLVED_NOTE}${NC}"
        echo "  Actual: $ACTUAL_LINES lines (within limit)"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    fi
done

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "Files exceeding limit: $FAILED_COUNT"
echo "Files within limit: $PASSED_COUNT"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}TEST RESULT: FAILED (Bug condition detected)${NC}"
    echo ""
    echo "Counterexamples (files exceeding 800 lines):"
    for EXAMPLE in "${COUNTEREXAMPLES[@]}"; do
        echo "  - $EXAMPLE"
    done
    echo ""
    echo "This is EXPECTED on unfixed code - the test confirms the bug exists."
    exit 1
else
    echo -e "${GREEN}TEST RESULT: PASSED (All files comply with 800-line limit)${NC}"
    echo ""
    echo "All files are within the 800-line limit. Bug is fixed!"
    exit 0
fi
