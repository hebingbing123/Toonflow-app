# L.2 End-to-End Regression Test Suite for Staging Environment

## Overview

This document describes the comprehensive end-to-end (E2E) regression test suite that validates the complete workflow from project creation to publish in a staging environment. The tests are designed to be idempotent, repeatable, and include proper cleanup logic.

**Test File**: `backend/src/app/pg_contract_tests/e2e_regression_suite.rs`

## Test Execution

### Prerequisites

1. **Database**: PostgreSQL database with migrated schema
2. **Environment Variables**:
   - `DATABASE_URL`: Connection string to staging database
   - `SUPABASE_JWT_SECRET`: JWT secret for authentication

### Running Tests

```bash
# Run all E2E regression tests
cd backend
cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite -- --ignored --nocapture

# Run specific test
cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite::test_e2e_project_creation_to_publish_workflow -- --ignored --nocapture
```

## Test Suite Coverage

### 1. Complete Workflow Test (`test_e2e_project_creation_to_publish_workflow`)

**Purpose**: Validates the entire workflow from project creation to publish job queueing.

**Steps**:
1. **Project Creation**: Create a new project with title and description
2. **Script Creation**: Create a script associated with the project
3. **Asset Creation**: Create test assets (characters, scenes, props)
4. **Storyboard Generation**: Create storyboard items with video descriptions
5. **Quality Gate Validation**: Create quality reviews and validate grading
6. **Draft Creation**: Create publish drafts for the project
7. **Publish Job Queueing**: Queue publish jobs for target platforms
8. **Data Consistency Verification**: Verify all data is correctly stored and retrievable

**Validations**:
- ✓ Project created with correct metadata
- ✓ Script associated with project
- ✓ Assets created and linked to project
- ✓ Storyboard items created with proper structure
- ✓ Quality reviews recorded with grades
- ✓ Drafts created and linked to project/script
- ✓ Publish jobs queued with correct delivery mode
- ✓ Data consistency across all stages

**Cleanup**:
- Removes all created jobs, drafts, storyboards, assets, scripts, and projects

### 2. Video Generation Workflow Test (`test_e2e_video_generation_workflow`)

**Purpose**: Validates the video generation workflow from storyboard to video output.

**Steps**:
1. **Setup**: Create project and script
2. **Video Generation**: Initiate video generation with test parameters
3. **Video List Retrieval**: Verify video list endpoint returns correct data
4. **Status Tracking**: Validate video generation status updates

**Validations**:
- ✓ Video generation endpoint accepts valid requests
- ✓ Video generation initiated successfully
- ✓ Video list endpoint returns structured data
- ✓ Total count field present in response

**Cleanup**:
- Removes all created test data

### 3. Quality Gate Enforcement Test (`test_e2e_quality_gate_enforcement`)

**Purpose**: Validates quality gate validation across different stages and grades.

**Steps**:
1. **Setup**: Create test project
2. **Quality Review Creation**: Create reviews with grades A, B, C, D
3. **Stats Retrieval**: Verify quality review statistics endpoint
4. **Grade Distribution**: Validate grade distribution across stages

**Validations**:
- ✓ Quality reviews created for all grades (A, B, C, D)
- ✓ Quality review stats endpoint returns structured data
- ✓ Grade distribution calculated correctly
- ✓ Stage-specific quality metrics available

**Cleanup**:
- Removes all quality reviews and test projects

### 4. Performance Monitoring Test (`test_e2e_performance_monitoring`)

**Purpose**: Validates performance monitoring endpoints and metrics collection.

**Steps**:
1. **Metrics Endpoint**: Test `/metrics` endpoint accessibility
2. **Health Check**: Verify `/health` endpoint returns OK status
3. **Response Time**: Validate endpoints respond within acceptable time

**Validations**:
- ✓ Metrics endpoint accessible (200 OK)
- ✓ Health check endpoint returns OK status
- ✓ Endpoints respond quickly (< 1s)

**Cleanup**:
- No cleanup needed (read-only operations)

### 5. Data Consistency Test (`test_e2e_data_consistency_across_stages`)

**Purpose**: Validates data consistency across create, read, update operations.

**Steps**:
1. **Create**: Create project with initial data
2. **Read**: Verify data immediately after creation
3. **Update**: Update project data
4. **Verify**: Confirm updates persisted correctly
5. **Cross-Stage Validation**: Verify data consistency across different API endpoints

**Validations**:
- ✓ Created data matches input
- ✓ Data retrievable immediately after creation
- ✓ Updates persist correctly
- ✓ Data consistent across different endpoints
- ✓ No data loss during operations

**Cleanup**:
- Removes all test data

## Test Context Structure

The test suite uses a shared `E2ETestContext` structure to manage test data and cleanup:

```rust
struct E2ETestContext {
    pool: PgPool,
    app: axum::Router,
    token: String,
    project_id: i32,
    project_uuid: String,
    script_id: i32,
    script_uuid: String,
    asset_ids: Vec<i32>,
    storyboard_ids: Vec<i32>,
    draft_ids: Vec<Uuid>,
    job_ids: Vec<Uuid>,
    quality_review_ids: Vec<Uuid>,
}
```

### Cleanup Strategy

The `E2ETestContext::cleanup()` method ensures proper cleanup in reverse dependency order:

1. **Jobs**: Delete generation jobs and usage events
2. **Quality Reviews**: Delete quality review records
3. **LLM Usage Logs**: Delete LLM usage logs associated with jobs
4. **Drafts**: Delete publish drafts
5. **Storyboards**: Delete storyboard items
6. **Assets**: Delete asset records
7. **Scripts**: Delete script records
8. **Projects**: Delete project records

This order ensures referential integrity is maintained during cleanup.

## Idempotency

All tests are designed to be idempotent:

- **Unique Test Data**: Each test uses unique identifiers and titles
- **Cleanup on Failure**: Cleanup runs even if test assertions fail
- **No Side Effects**: Tests don't depend on external state
- **Isolated Transactions**: Each test operates in isolation

## Integration Points

The E2E test suite validates integration with:

1. **Project Management** (`/api/v1/projects`)
   - Project CRUD operations
   - Project metadata management
   - Project ownership validation

2. **Script Management** (`/api/v1/projects/{id}/scripts`)
   - Script creation and association
   - Script content management
   - Script-project relationship

3. **Asset Management** (`/api/v1/assets`)
   - Asset creation (characters, scenes, props)
   - Asset-project linking
   - Asset metadata management

4. **Production Workbench** (`/api/v1/production`)
   - Storyboard creation and management
   - Video generation workflow
   - Video list retrieval
   - Flow data management

5. **Quality Reviews** (`/api/v1/quality-reviews`)
   - Quality review creation
   - Grade assignment (A, B, C, D)
   - Quality statistics aggregation
   - Stage-specific reviews

6. **Publish Pipeline** (`/api/v1/publish`)
   - Draft creation and management
   - Job queueing for platforms
   - Delivery mode configuration
   - Platform-specific validation

7. **Monitoring** (`/metrics`, `/health`)
   - Metrics collection
   - Health check validation
   - Performance monitoring

## Test Results

Expected output when all tests pass:

```
running 5 tests
test app::pg_contract_tests::e2e_regression_suite::test_e2e_project_creation_to_publish_workflow ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_video_generation_workflow ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_quality_gate_enforcement ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_performance_monitoring ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_data_consistency_across_stages ... ok

test result: ok. 5 passed; 0 failed; 0 ignored; 0 measured
```

## Coverage Summary

- **Total Tests**: 5 comprehensive E2E tests
- **Workflow Coverage**: Complete workflow from project creation to publish
- **API Endpoints Covered**: 15+ endpoints
- **Data Consistency**: Validated across all stages
- **Cleanup**: 100% cleanup coverage
- **Idempotency**: All tests repeatable

## Staging Environment Requirements

### Database Configuration

The staging database should have:

1. **Schema**: Fully migrated schema matching production
2. **Isolation**: Separate from production database
3. **Permissions**: Test user with full CRUD permissions
4. **Connection Pool**: Minimum 5 connections for concurrent tests

### Environment Setup

```bash
# .env file for staging
DATABASE_URL=postgresql://user:password@staging-db:5432/openflow_staging
SUPABASE_JWT_SECRET=your-staging-jwt-secret
```

### Test User

The tests use a fixed test user UUID:
```
CONTRACT_USER_SUB = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
```

This user should exist in the `auth.users` table in the staging database.

## Troubleshooting

### Test Failures

**Database Connection Issues**:
```
Error: DATABASE_URL when running with --ignored
```
**Solution**: Ensure `DATABASE_URL` is set in environment or `.env` file

**JWT Secret Issues**:
```
Error: SUPABASE_JWT_SECRET must match JWT signing
```
**Solution**: Ensure `SUPABASE_JWT_SECRET` matches the secret used by Supabase

**Schema Migration Issues**:
```
Error: relation "app_project" does not exist
```
**Solution**: Run `supabase db reset` to apply all migrations

### Cleanup Issues

If tests fail and leave orphaned data:

```sql
-- Manual cleanup script
DELETE FROM public.app_generation_job WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_quality_review WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_publish_draft WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_storyboard WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_asset WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_script WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
DELETE FROM public.app_project WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
```

## Future Enhancements

Potential areas for expansion:

1. **Concurrent Workflow Tests**: Test multiple users creating projects simultaneously
2. **Long-Running Workflow Tests**: Test workflows that span multiple hours
3. **Error Recovery Tests**: Test recovery from various failure scenarios
4. **Performance Benchmarks**: Add performance benchmarks for critical paths
5. **Platform-Specific Tests**: Add tests for each publish platform's specific requirements
6. **Callback Handling Tests**: Test platform callback processing
7. **Retry Logic Tests**: Test retry behavior for failed operations
8. **Data Migration Tests**: Test data migration scenarios

## Maintenance

### Adding New Tests

When adding new E2E tests:

1. Follow the existing test structure with `E2ETestContext`
2. Ensure proper cleanup in reverse dependency order
3. Use descriptive test names starting with `test_e2e_`
4. Add `#[ignore]` attribute for database-dependent tests
5. Document the test purpose and steps in this file

### Updating Tests

When updating existing tests:

1. Maintain backward compatibility with staging database
2. Update documentation to reflect changes
3. Ensure cleanup logic handles new data types
4. Run full test suite to verify no regressions

### Test Data Management

- Use unique identifiers for test data (e.g., "E2E Test Project")
- Avoid hardcoded IDs except for the test user UUID
- Clean up all created data, even on test failure
- Use transactions where possible for atomic operations

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Regression Tests

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Run migrations
        run: |
          cd backend
          sqlx migrate run
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/postgres
      
      - name: Run E2E tests
        run: |
          cd backend
          cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite -- --ignored --nocapture
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/postgres
          SUPABASE_JWT_SECRET: test-secret-for-ci
```

## Conclusion

The E2E regression test suite provides comprehensive coverage of the complete workflow from project creation to publish. The tests are designed to be:

- **Comprehensive**: Cover all major workflow stages
- **Idempotent**: Can be run repeatedly without side effects
- **Isolated**: Each test operates independently
- **Clean**: Proper cleanup ensures no data leakage
- **Maintainable**: Clear structure and documentation

This test suite serves as a safety net for staging deployments and provides confidence that the complete workflow functions correctly before production release.
