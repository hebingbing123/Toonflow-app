# Search API Integration Tests

## Overview

This document describes the integration tests in `backend/tests/search_api_test.rs`.

The suite focuses on search behavior that depends on a live PostgreSQL test database plus
`sqlx::test` database setup. It exercises:

- workspace-scoped search visibility
- result filtering and pagination
- search history persistence
- concurrency and timeout scenarios
- end-to-end search flows across projects, scripts, and assets

Because these tests are database-heavy and rely on `sqlx::test` setup behavior, they are
marked `ignored` by default so they do not fail ordinary `cargo test` runs in environments
without the required Postgres setup.

## Running the Tests

### Prerequisites

1. PostgreSQL database available for `sqlx::test`
2. Environment/configuration required by your local SQLx test setup
3. Any schema extensions needed by the test tables, such as `gen_random_uuid()`

If you are using the repo's usual local database workflow, starting local Supabase is the
most likely path:

```bash
cd /path/to/Toonflow-app
yarn supabase:start:db
# or, if you need the whole stack:
supabase start
supabase db reset
```

For database-backed search tests, the DB-only helper is often the fastest and most reliable
option because it skips unrelated local services that can fail health checks without affecting
`sqlx::test`.

### Run the Search Test Suite

```bash
cd backend
cargo test --test search_api_test -- --ignored --nocapture
```

Or from the repo root:

```bash
yarn test:backend:search:db
```

The root helper script also supports a single test name:

```bash
./scripts/run_search_api_tests.sh --db test_search_pagination
```

Before invoking Cargo in `--db` mode, the helper checks that `DATABASE_URL` exists and that
the configured host/port is actually reachable. This avoids waiting through a long
`sqlx::test` timeout when local Supabase/Postgres is simply not running.

If `DATABASE_URL` is not already exported, the helper also tries `supabase status -o env`
and reuses the local `DB_URL` value automatically.

### Run a Single Search Test

```bash
cd backend
cargo test --test search_api_test test_search_pagination -- --ignored --nocapture
```

### Default Behavior

If you run the file without `--ignored`, only the lightweight non-database rate-limit test runs:

```bash
cd backend
cargo test --test search_api_test
```

Or from the repo root:

```bash
yarn test:backend:search
```

Or with the helper script directly:

```bash
./scripts/run_search_api_tests.sh
```

Expected shape:

```text
running 21 tests
test tests::test_rate_limit_configuration ... ok
test tests::test_search_pagination ... ignored, needs Postgres/sqlx test DB setup; run cargo test --test search_api_test -- --ignored --nocapture
...
```

## Test Coverage

The suite currently includes:

1. Workspace result visibility
2. Permission isolation between users and workspaces
3. Filtering by type and time range
4. Pagination behavior
5. Search history save/list/delete flows
6. Invalid query and invalid workspace handling
7. Search result consistency
8. Concurrency and connection-pool pressure scenarios
9. End-to-end search flow across related entities

## Notes

- The test file creates its own simplified schema for search-related tables.
- These tests are separate from the larger `pg_contract_tests` suite.
- If an ignored test fails after you enable the database environment, treat it as either:
  - a real search behavior regression, or
  - a drift between the simplified test schema and the current production schema assumptions.

## Related Files

- Test file: `backend/tests/search_api_test.rs`
- Backend guide: `backend/README.md`
- E2E database-heavy test guide: `backend/tests/E2E_REGRESSION_TESTS.md`
