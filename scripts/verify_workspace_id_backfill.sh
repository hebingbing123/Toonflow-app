#!/usr/bin/env bash
# Verification script for workspace_id backfill
# Related: .kiro/specs/workspace-scope-billing/ (Task 2.2)
# Runbook: docs/runbooks/backfill-job-workspace-id.md

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if DATABASE_URL is set
if [ -z "${DATABASE_URL:-}" ]; then
    echo -e "${RED}ERROR: DATABASE_URL environment variable is not set${NC}"
    echo "Usage: DATABASE_URL=postgresql://... $0"
    exit 1
fi

echo -e "${BLUE}=== Workspace ID Backfill Verification ===${NC}"
echo ""

# Function to run SQL query and display results
run_query() {
    local title="$1"
    local query="$2"
    local expected="$3"
    
    echo -e "${BLUE}${title}${NC}"
    result=$(psql "${DATABASE_URL}" -t -c "${query}" | xargs)
    
    if [ -n "${expected}" ]; then
        if [ "${result}" = "${expected}" ]; then
            echo -e "${GREEN}✓ PASS: ${result}${NC}"
        else
            echo -e "${RED}✗ FAIL: Expected '${expected}', got '${result}'${NC}"
        fi
    else
        echo -e "${YELLOW}Result: ${result}${NC}"
    fi
    echo ""
}

# 1. Check NULL count
echo -e "${BLUE}1. Checking for jobs with NULL workspace_id...${NC}"
null_count=$(psql "${DATABASE_URL}" -t -c "SELECT COUNT(*) FROM public.app_generation_job WHERE workspace_id IS NULL;" | xargs)
if [ "${null_count}" = "0" ]; then
    echo -e "${GREEN}✓ PASS: All jobs have workspace_id (count: 0)${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: ${null_count} jobs still have NULL workspace_id${NC}"
    echo "  Run: SELECT id, owner_user_id, kind, created_at FROM app_generation_job WHERE workspace_id IS NULL LIMIT 10;"
fi
echo ""

# 2. Check total job count
echo -e "${BLUE}2. Total jobs with workspace_id...${NC}"
total_with_workspace=$(psql "${DATABASE_URL}" -t -c "SELECT COUNT(*) FROM public.app_generation_job WHERE workspace_id IS NOT NULL;" | xargs)
echo -e "${GREEN}Total jobs with workspace_id: ${total_with_workspace}${NC}"
echo ""

# 3. Check workspace distribution
echo -e "${BLUE}3. Workspace distribution by type...${NC}"
psql "${DATABASE_URL}" -c "
SELECT 
  w.workspace_type,
  COUNT(*) as job_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM public.app_generation_job j
INNER JOIN public.app_workspace w ON w.id = j.workspace_id
GROUP BY w.workspace_type
ORDER BY job_count DESC;
"
echo ""

# 4. Verify project-based jobs
echo -e "${BLUE}4. Verifying project-based jobs (sample)...${NC}"
psql "${DATABASE_URL}" -c "
SELECT 
  j.id as job_id,
  j.workspace_id as job_workspace_id,
  p.workspace_id as project_workspace_id,
  CASE 
    WHEN j.workspace_id = p.workspace_id THEN '✓ MATCH'
    ELSE '✗ MISMATCH'
  END as status
FROM public.app_generation_job j
INNER JOIN public.app_project p ON p.id::text = j.payload->>'project_uuid'
WHERE j.workspace_id IS NOT NULL
LIMIT 10;
"
echo ""

# 5. Check orphan jobs
echo -e "${BLUE}5. Verifying orphan jobs (sample)...${NC}"
psql "${DATABASE_URL}" -c "
SELECT 
  j.id as job_id,
  j.owner_user_id,
  w.workspace_type,
  CASE 
    WHEN j.owner_user_id = w.owner_user_id AND w.workspace_type = 'personal' THEN '✓ CORRECT'
    ELSE '✗ INCORRECT'
  END as status
FROM public.app_generation_job j
INNER JOIN public.app_workspace w ON w.id = j.workspace_id
WHERE j.payload->>'project_uuid' IS NULL
  AND j.payload->>'project_numeric_id' IS NULL
  AND j.workspace_id IS NOT NULL
LIMIT 10;
"
echo ""

# 6. Check for workspace_id consistency
echo -e "${BLUE}6. Checking workspace_id consistency...${NC}"
inconsistent=$(psql "${DATABASE_URL}" -t -c "
SELECT COUNT(*)
FROM public.app_generation_job j
INNER JOIN public.app_project p ON p.id::text = j.payload->>'project_uuid'
WHERE j.workspace_id IS NOT NULL
  AND p.workspace_id IS NOT NULL
  AND j.workspace_id != p.workspace_id;
" | xargs)

if [ "${inconsistent}" = "0" ]; then
    echo -e "${GREEN}✓ PASS: All project-based jobs have consistent workspace_id${NC}"
else
    echo -e "${RED}✗ FAIL: ${inconsistent} jobs have inconsistent workspace_id${NC}"
    echo "  This indicates a problem with the backfill logic"
fi
echo ""

# 7. Check indexes
echo -e "${BLUE}7. Verifying indexes exist...${NC}"
psql "${DATABASE_URL}" -c "
SELECT 
  indexname,
  indexdef
FROM pg_indexes 
WHERE tablename = 'app_generation_job' 
  AND indexname LIKE '%workspace%'
ORDER BY indexname;
"
echo ""

# 8. Summary
echo -e "${BLUE}=== Summary ===${NC}"
if [ "${null_count}" = "0" ] && [ "${inconsistent}" = "0" ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}✓ Ready for Task 2.3 (enforce NOT NULL constraint)${NC}"
else
    echo -e "${YELLOW}⚠ Some issues found - review above output${NC}"
    if [ "${null_count}" != "0" ]; then
        echo -e "${YELLOW}  - ${null_count} jobs still have NULL workspace_id${NC}"
    fi
    if [ "${inconsistent}" != "0" ]; then
        echo -e "${RED}  - ${inconsistent} jobs have inconsistent workspace_id${NC}"
    fi
fi
echo ""

echo -e "${BLUE}For detailed troubleshooting, see:${NC}"
echo "  docs/runbooks/backfill-job-workspace-id.md"
