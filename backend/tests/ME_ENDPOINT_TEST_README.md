# GET /api/v1/me Integration Tests

## Overview

This document describes the integration tests for the `/me` endpoint (Task 5.4) that validate v1 and v2 API behavior for workspace-scope billing.

## Test Coverage

The test suite validates:

1. **v1 backward compatibility** (Requirements 3.1, 9.1)
   - Flat response structure unchanged
   - No v2-specific fields present
   - User billing fields present

2. **v2 workspace billing happy path** (Requirements 3.2, 3.3, 9.2)
   - Nested `user` and `current_workspace_billing` objects
   - `billing_scope = "workspace"` when workspace has plan_tier
   - Workspace quota and jobs_today aggregates

3. **v2 personal workspace user-scope** (Requirements 3.3, 9.3)
   - `billing_scope = "user"` for personal workspaces without plan_tier
   - `current_workspace_billing` is null
   - User billing fields used

4. **v2 forbidden workspace** (Requirements 10.1)
   - Non-members cannot access workspace billing data
   - Membership checks enforced

5. **v2 with workspace billing disabled**
   - Global `WORKSPACE_BILLING_ENABLED` flag respected
   - Falls back to user-scope even when workspace has plan_tier

## Running the Tests

### Prerequisites

1. PostgreSQL database (local Supabase or test database)
2. Database migrations applied
3. `TEST_DATABASE_URL` environment variable set

### Setup

```bash
# Start local Supabase (if using local development)
cd /path/to/Openflow-app
supabase start

# Set test database URL
export TEST_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:64322/postgres"
```

### Run Tests

```bash
# Run all /me endpoint tests
cd backend
cargo test --test me_endpoint_test

# Run specific test
cargo test --test me_endpoint_test test_me_v1_backward_compatibility

# Run with output
cargo test --test me_endpoint_test -- --nocapture
```

### Without Database

If `TEST_DATABASE_URL` is not set, tests will be skipped with a warning:

```
⚠️  Skipping integration test: TEST_DATABASE_URL not set
   Set TEST_DATABASE_URL to run database integration tests
```

## Test Structure

Each test follows this pattern:

1. **Setup**: Create test user with personal and enterprise workspaces
2. **Execute**: Call helper functions that simulate endpoint logic
3. **Assert**: Verify response structure and values
4. **Cleanup**: Remove test data

### Helper Functions

- `setup_test_user()`: Creates user with personal and enterprise workspaces
- `cleanup_test_user()`: Removes all test data
- `get_me_v1()`: Simulates v1 endpoint logic
- `get_me_v2()`: Simulates v2 endpoint logic

## Validation

The tests validate the implementation without running the full test suite:

```bash
# Quick validation (format + clippy, no tests)
yarn refactor:quick

# Full validation (includes tests)
yarn refactor:check
```

## Test Data

Each test creates:

- **User**: UUID-based user with email and plan_tier
- **Personal Workspace**: `workspace_type = 'personal'`, no plan_tier
- **Enterprise Workspace**: `workspace_type = 'enterprise'`, `plan_tier = 'enterprise'`, `daily_job_quota = 1000`
- **Memberships**: User is owner of both workspaces

## Environment Variables

- `TEST_DATABASE_URL`: PostgreSQL connection string for tests
- `WORKSPACE_BILLING_ENABLED`: Feature flag for workspace-scope billing (set in tests)
- `ENTERPRISE_WORKSPACE_BILLING_DEFAULT`: Policy for enterprise workspaces (optional)

## Requirements Mapping

| Test | Requirements |
|------|--------------|
| `test_me_v1_backward_compatibility` | 3.1, 9.1 |
| `test_me_v2_workspace_billing_happy_path` | 3.2, 3.3, 9.2 |
| `test_me_v2_personal_workspace_user_scope` | 3.3, 9.3 |
| `test_me_v2_forbidden_workspace_non_member` | 10.1 |
| `test_me_v2_workspace_billing_disabled` | 3.3, 4.1 |

## Notes

- Tests use helper functions that simulate endpoint logic rather than making HTTP requests
- This allows testing the core business logic without requiring a running server
- Database queries match the actual endpoint implementation
- Tests are isolated and clean up after themselves
- Tests skip gracefully if database is not available

## Related Files

- Implementation: `backend/src/app/handlers/me.rs`
- Types: `backend/src/app/handlers/types.rs`
- Billing Context: `backend/src/metering/billing_context.rs`
- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md`
- Design: `.kiro/specs/workspace-scope-billing/design.md`
