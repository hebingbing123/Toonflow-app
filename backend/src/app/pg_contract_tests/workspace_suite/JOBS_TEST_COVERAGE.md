# Jobs Workspace Visibility Test Coverage

This document describes the comprehensive integration test coverage for workspace member jobs permission matrix (Task W2.9).

## Test File
`backend/src/app/pg_contract_tests/workspace_suite/jobs_workspace_visibility.rs`

## Test Coverage Matrix

### 1. List/Page Operations

#### Test: `jobs_page_workspace_visibility_owner_and_member`
**Endpoint**: `GET /api/v1/jobs/page`

| Scenario | Owner | Member | Outsider | Status |
|----------|-------|--------|----------|--------|
| View jobs with `project_uuid` | ✅ Can see | ✅ Can see | ❌ Cannot see | ✅ Covered |
| View jobs with `project_numeric_id` | ✅ Can see | ✅ Can see | ❌ Cannot see | ✅ Covered |
| View jobs with both IDs | ✅ Can see | ✅ Can see | ❌ Cannot see | ✅ Covered |
| View personal jobs (no project) | ✅ Can see | ❌ Cannot see | ❌ Cannot see | ✅ Covered |
| Filter by `project_id` (member) | ✅ Can filter | ✅ Can filter | ❌ 404 | ✅ Covered |

#### Test: `jobs_list_endpoint_workspace_visibility`
**Endpoint**: `GET /api/v1/jobs`

| Scenario | Owner | Member | Outsider | Status |
|----------|-------|--------|----------|--------|
| List workspace jobs | ✅ Can see | ✅ Can see | N/A | ✅ Covered |
| List personal jobs | ✅ Can see | ❌ Cannot see | N/A | ✅ Covered |

#### Test: `jobs_summary_workspace_visibility`
**Endpoint**: `GET /api/v1/jobs/summary`

| Scenario | Owner | Member | Status |
|----------|-------|--------|--------|
| Summary includes workspace jobs | ✅ Included | ✅ Included | ✅ Covered |
| Summary includes personal jobs | ✅ Included | ❌ Not included | ✅ Covered |
| Total count accuracy | ✅ Accurate | ✅ Accurate | ✅ Covered |

### 2. Detail Operations

#### Test: `jobs_detail_cancel_retry_workspace_permissions`
**Endpoint**: `GET /api/v1/jobs/{id}`

| Scenario | Owner | Member | Outsider | Status |
|----------|-------|--------|----------|--------|
| View workspace job detail | ✅ Can view | ✅ Can view | ❌ 404 | ✅ Covered |
| View personal job detail | ✅ Can view | ❌ 404 | ❌ 404 | ✅ Covered |

### 3. Cancel Operations

#### Test: `jobs_detail_cancel_retry_workspace_permissions`
**Endpoint**: `POST /api/v1/jobs/{id}/cancel`

| Scenario | Owner | Member | Outsider | Status |
|----------|-------|--------|----------|--------|
| Cancel workspace job | ✅ Can cancel | ✅ Can cancel | ❌ 404 | ✅ Covered |
| Cancel personal job | ✅ Can cancel | ❌ 404 | ❌ 404 | ✅ Covered |

### 4. Retry Operations

#### Test: `jobs_detail_cancel_retry_workspace_permissions`
**Endpoint**: `POST /api/v1/jobs/{id}/retry`

| Scenario | Owner | Member | Outsider | Status |
|----------|-------|--------|----------|--------|
| Retry workspace job | ✅ Can retry | ✅ Can retry | ❌ 404 | ✅ Covered |
| Retry personal job | ✅ Can retry | ❌ 404 | ❌ 404 | ✅ Covered |

### 5. Archived Project Handling

#### Test: `jobs_page_workspace_visibility_archived_project`
**Endpoint**: `GET /api/v1/jobs/page`

| Scenario | Owner | Status |
|----------|-------|--------|
| View jobs from archived project (as job owner) | ✅ Can see | ✅ Covered |

#### Test: `jobs_detail_archived_project_permission`
**Endpoint**: `GET /api/v1/jobs/{id}`

| Scenario | Owner | Member | Status |
|----------|-------|--------|--------|
| View job detail from archived project (as job owner) | ✅ Can view | ❌ 404 | ✅ Covered |

## Requirements Coverage

### Requirement 14: Jobs Workspace 可见性

| Acceptance Criteria | Test Coverage | Status |
|---------------------|---------------|--------|
| AC1: Query jobs by `project_uuid` + `project_numeric_id` | `jobs_page_workspace_visibility_owner_and_member` | ✅ |
| AC2: Personal jobs (no project) filtered by `owner_user_id` | `jobs_page_workspace_visibility_owner_and_member` | ✅ |
| AC3: Project jobs visible to owner or workspace members | `jobs_page_workspace_visibility_owner_and_member` | ✅ |
| AC4: `/api/v1/jobs/page` filtered by workspace | `jobs_page_workspace_visibility_owner_and_member` | ✅ |
| AC5: `/api/v1/jobs` filtered by workspace | `jobs_list_endpoint_workspace_visibility` | ✅ |
| AC6: Jobs summary filtered by workspace | `jobs_summary_workspace_visibility` | ✅ |
| AC7: Detail/cancel/retry by workspace member | `jobs_detail_cancel_retry_workspace_permissions` | ✅ |
| AC8: POST `/api/v1/jobs` validates project membership | Not in integration tests (unit test) | ⚠️ |
| AC9: Worker queries validate workspace membership | Not in integration tests (unit test) | ⚠️ |
| AC10: Archived/deleted project jobs still visible to owner | `jobs_page_workspace_visibility_archived_project`, `jobs_detail_archived_project_permission` | ✅ |

## Test Scenarios Summary

### Total Tests: 6

1. **jobs_page_workspace_visibility_owner_and_member** (15 assertions)
   - Owner/member/outsider visibility for paginated list
   - Project UUID, numeric ID, and both ID scenarios
   - Personal job visibility
   - Project filter validation

2. **jobs_page_workspace_visibility_archived_project** (1 assertion)
   - Owner can see jobs from archived projects

3. **jobs_detail_cancel_retry_workspace_permissions** (9 assertions)
   - Detail view permissions
   - Cancel operation permissions
   - Retry operation permissions
   - Personal job access control

4. **jobs_detail_archived_project_permission** (2 assertions)
   - Owner can view archived project job details
   - Member cannot view archived project job details

5. **jobs_list_endpoint_workspace_visibility** (4 assertions)
   - Non-paginated list endpoint visibility
   - Personal job filtering

6. **jobs_summary_workspace_visibility** (4 assertions)
   - Summary endpoint workspace filtering
   - Personal job exclusion from member summaries

## Edge Cases Covered

- ✅ Jobs with only `project_uuid` in payload
- ✅ Jobs with only `project_numeric_id` in payload
- ✅ Jobs with both `project_uuid` and `project_numeric_id` in payload
- ✅ Jobs with no project information (personal jobs)
- ✅ Archived project jobs
- ✅ Outsider access attempts (security - 404 instead of 403)
- ✅ Member access to owner's personal jobs (denied)
- ✅ Filter by project_id with/without access

## Security Considerations

All tests verify that:
1. **404 (Not Found)** is returned instead of **403 (Forbidden)** for unauthorized access
   - This prevents information leakage about job existence
2. Personal jobs are never visible to workspace members
3. Outsiders cannot see any workspace jobs
4. Archived project jobs maintain proper access control

## Running the Tests

```bash
# Set up environment
export DATABASE_URL="postgresql://..."
export SUPABASE_JWT_SECRET="..."

# Reset database schema
supabase db reset

# Run all jobs workspace visibility tests
cargo test --test pg_contract_tests jobs_workspace_visibility -- --ignored --nocapture

# Run specific test
cargo test --test pg_contract_tests jobs_page_workspace_visibility_owner_and_member -- --ignored --nocapture
```

## Notes

- All tests use `#[ignore]` attribute and require database setup
- Tests create isolated test data and clean up after execution
- Tests use JWT tokens for authentication simulation
- Tests verify both positive (can access) and negative (cannot access) scenarios
