# Database Migration History Policy

## Why we do **not** "clean migration history"

- Applied SQL migrations are an immutable audit trail. Deleting or rewriting old files can break reproducibility across environments.
- Supabase/Postgres migration order is part of deployment state. History edits create drift between local/dev/prod.
- Historical names like `legacy_*` in old migration files are expected and acceptable as long as the **current schema** is converged by later forward migrations.

## Naming guidance

- In new docs and new schema changes, prefer `historical` / `import_*` / `numeric_*` terminology instead of `legacy`.
- Do **not** rename old migration filenames only for style.
- Do **not** edit historical migration SQL except for emergency recovery with explicit DBA process.

## Safe cleanup approach

When old naming still exists in the live schema:

1. Add a **new forward migration** to rename objects/columns.
2. Keep backward compatibility where needed (views, aliases, or staged rollout).
3. Update app code and contract tests in the same PR.
4. Verify with full gate (`yarn refactor:check`) before merge.

## Scope of this policy

- `supabase/migrations/*.sql` files are treated as immutable history.
- Cleanup work should target:
  - runtime schema convergence via new migrations
  - code/doc terminology clarity
  - removal of truly unused runtime directories/files (non-migration artifacts)

