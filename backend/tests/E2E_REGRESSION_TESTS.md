# End-to-End Regression Tests - Execution Guide

## Quick Start

### Prerequisites

1. **PostgreSQL Database**: Running instance with migrated schema
2. **Environment Variables**: Set in `.env` file or environment

```bash
# Required environment variables
DATABASE_URL=postgresql://user:password@localhost:5432/openflow_staging
SUPABASE_JWT_SECRET=your-jwt-secret-here
```

### Running All E2E Tests

```bash
cd backend
cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite -- --ignored --nocapture
```

### Running Individual Tests

```bash
# Complete workflow test
cargo test test_e2e_project_creation_to_publish_workflow -- --ignored --nocapture

# Video generation workflow test
cargo test test_e2e_video_generation_workflow -- --ignored --nocapture

# Quality gate enforcement test
cargo test test_e2e_quality_gate_enforcement -- --ignored --nocapture

# Performance monitoring test
cargo test test_e2e_performance_monitoring -- --ignored --nocapture

# Data consistency test
cargo test test_e2e_data_consistency_across_stages -- --ignored --nocapture
```

## Test Coverage

### 1. Complete Workflow Test
- **Duration**: ~5-10 seconds
- **Coverage**: Project → Script → Assets → Storyboard → Quality Review → Draft → Publish Job
- **Validates**: End-to-end workflow integrity

### 2. Video Generation Workflow Test
- **Duration**: ~3-5 seconds
- **Coverage**: Video generation initiation and status tracking
- **Validates**: Video generation pipeline

### 3. Quality Gate Enforcement Test
- **Duration**: ~2-3 seconds
- **Coverage**: Quality reviews with grades A, B, C, D
- **Validates**: Quality gate validation logic

### 4. Performance Monitoring Test
- **Duration**: ~1-2 seconds
- **Coverage**: Metrics and health check endpoints
- **Validates**: Monitoring infrastructure

### 5. Data Consistency Test
- **Duration**: ~2-3 seconds
- **Coverage**: CRUD operations and data persistence
- **Validates**: Data consistency across operations

## Expected Output

### Successful Test Run

```
running 5 tests
test app::pg_contract_tests::e2e_regression_suite::test_e2e_project_creation_to_publish_workflow ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_video_generation_workflow ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_quality_gate_enforcement ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_performance_monitoring ... ok
test app::pg_contract_tests::e2e_regression_suite::test_e2e_data_consistency_across_stages ... ok

test result: ok. 5 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 15.23s
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed

**Error**:
```
Error: DATABASE_URL when running with --ignored
```

**Solution**:
```bash
# Check .env file exists
cat backend/.env

# Or set environment variable
export DATABASE_URL=postgresql://user:password@localhost:5432/openflow_staging
```

#### 2. JWT Secret Mismatch

**Error**:
```
Error: SUPABASE_JWT_SECRET must match JWT signing
```

**Solution**:
```bash
# Get JWT secret from Supabase
supabase status

# Set in environment
export SUPABASE_JWT_SECRET=your-secret-here
```

#### 3. Schema Not Migrated

**Error**:
```
Error: relation "app_project" does not exist
```

**Solution**:
```bash
# Reset database and apply migrations
cd backend
supabase db reset
```

#### 4. Test User Not Found

**Error**:
```
Error: User not found: aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
```

**Solution**:
```sql
-- Create test user in database
INSERT INTO auth.users (id, email)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'test@example.com')
ON CONFLICT (id) DO NOTHING;
```

### Cleanup Orphaned Data

If tests fail and leave data behind:

```sql
-- Connect to database
psql $DATABASE_URL

-- Run cleanup
DELETE FROM public.app_generation_job 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_quality_review 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_publish_draft 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_storyboard 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_asset 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_script 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

DELETE FROM public.app_project 
WHERE owner_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-8aaa-aaaaaaaaaaaa';
```

## Staging Environment Setup

### Local Staging Database

```bash
# Start PostgreSQL with Docker
docker run -d \
  --name openflow-staging \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=openflow_staging \
  -p 5432:5432 \
  postgres:15

# Apply migrations
cd backend
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/openflow_staging
sqlx migrate run

# Create test user
psql $DATABASE_URL -c "INSERT INTO auth.users (id, email) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'test@example.com') ON CONFLICT DO NOTHING;"
```

### Remote Staging Database

```bash
# Set environment variables
export DATABASE_URL=postgresql://user:password@staging-db.example.com:5432/openflow_staging
export SUPABASE_JWT_SECRET=your-staging-jwt-secret

# Run tests
cd backend
cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite -- --ignored --nocapture
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/e2e-tests.yml`:

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
          POSTGRES_DB: openflow_staging
        ports:
          - 5432:5432
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
      
      - name: Install sqlx-cli
        run: cargo install sqlx-cli --no-default-features --features postgres
      
      - name: Run migrations
        run: |
          cd backend
          sqlx migrate run
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/openflow_staging
      
      - name: Create test user
        run: |
          psql postgresql://postgres:postgres@localhost:5432/openflow_staging -c "INSERT INTO auth.users (id, email) VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'test@example.com') ON CONFLICT DO NOTHING;"
      
      - name: Run E2E tests
        run: |
          cd backend
          cargo test --package openflow-server --lib app::pg_contract_tests::e2e_regression_suite -- --ignored --nocapture
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/openflow_staging
          SUPABASE_JWT_SECRET: test-secret-for-ci
```

## Performance Benchmarks

Expected test execution times on standard hardware:

| Test | Duration | Operations |
|------|----------|------------|
| Complete Workflow | 5-10s | 8 API calls, 7 DB writes |
| Video Generation | 3-5s | 3 API calls, 2 DB writes |
| Quality Gate | 2-3s | 5 API calls, 4 DB writes |
| Performance Monitoring | 1-2s | 2 API calls, 0 DB writes |
| Data Consistency | 2-3s | 4 API calls, 2 DB writes |
| **Total** | **13-23s** | **22 API calls, 15 DB writes** |

## Test Data

### Test User

- **UUID**: `aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`
- **Email**: `test@example.com`
- **Purpose**: Fixed user for all E2E tests

### Test Projects

All test projects use descriptive names:
- "E2E Test Project"
- "Video Gen Test"
- "Quality Gate Test"
- "Consistency Test"

### Cleanup

All tests include automatic cleanup that runs even if assertions fail. Cleanup order:

1. Jobs and usage events
2. Quality reviews
3. LLM usage logs
4. Publish drafts
5. Storyboards
6. Assets
7. Scripts
8. Projects

## Best Practices

### Running Tests

1. **Always use staging database**: Never run against production
2. **Check environment variables**: Verify DATABASE_URL and JWT secret
3. **Run migrations first**: Ensure schema is up to date
4. **Monitor test duration**: Tests should complete in < 30 seconds
5. **Check cleanup**: Verify no orphaned data after tests

### Debugging Tests

1. **Use --nocapture**: See detailed output during test execution
2. **Run individual tests**: Isolate failing tests
3. **Check database state**: Query database to verify data
4. **Review logs**: Check application logs for errors
5. **Verify cleanup**: Ensure cleanup runs even on failure

### Maintaining Tests

1. **Update documentation**: Keep this file in sync with tests
2. **Add new tests**: Follow existing patterns
3. **Test idempotency**: Ensure tests can run multiple times
4. **Verify cleanup**: Test cleanup logic separately
5. **Monitor performance**: Track test execution time

## Support

For issues or questions:

1. Check this documentation first
2. Review test source code: `backend/src/app/pg_contract_tests/e2e_regression_suite.rs`
3. Check detailed documentation: `backend/docs/L.2-e2e-regression-test-suite.md`
4. Review existing contract tests for patterns
5. Contact the development team

## Related Documentation

- [L.2 E2E Regression Test Suite](../backend/docs/L.2-e2e-regression-test-suite.md) - Detailed technical documentation
- [L.1 Nine-Platform Acceptance Coverage](../backend/docs/L.1-nine-platform-acceptance-coverage.md) - Platform acceptance tests
- [Contract Tests](../backend/src/app/pg_contract_tests/README.md) - General contract testing guide
