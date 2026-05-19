# Export Artifacts on S3 (Runbook)

## Overview

Openflow can persist **large export artifacts** to **S3-compatible object storage** instead of local disk so that **multiple API replicas** can enqueue workers, serve downloads, and run migrations without relying on a shared filesystem.

This runbook covers two features that share the same Rust client (`crate::settings::export_s3`):

| Feature | Job kind / API | Bucket env | Default object prefix |
|--------|----------------|--------------|------------------------|
| Workspace shared cleared-template audit export (async) | `settings.workspace_shared_audit.export` | `OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET` | `workspace-shared-audit-exports` |
| Account data export (zip) | `settings.account.export` | `OPENFLOW_ACCOUNT_EXPORT_S3_BUCKET` | `account-exports` |

**Export history** for workspace shared audit lives in Postgres table `app_workspace_shared_audit_export` (not S3). **Account export** history remains `app_generation_job` rows; only the **zip bytes** move to S3 when configured.

## When to enable S3

- You run **more than one** `openflow-server` / worker pod without a **ReadWriteMany** volume for export directories.
- You want **lifecycle / retention** on objects via bucket policies instead of only local disk cleanup.
- You need **cross-region** or **centralized** storage for compliance backups (combine with bucket policies and encryption at rest).

If **no** bucket env vars are set, behavior stays **local**: `OPENFLOW_LOCAL_*` dirs or OS temp (see `backend/src/state/from_env.rs` and account/workspace export modules).

## Prerequisites

1. **Migrations applied** (includes `app_workspace_shared_audit_export` and RLS policies for that table).
2. **Buckets created** (can be one bucket with two prefixes, or two buckets—recommended for IAM separation).
3. **Credentials** available to the API/worker process via the **AWS SDK default credential chain** (see below).
4. **`AWS_REGION`** set for real AWS S3 (or a region string your provider accepts).

## Environment variables

### Shared (all S3 exports)

| Variable | Required | Description |
|----------|----------|-------------|
| `AWS_REGION` | Yes (AWS) | Region passed to the SDK. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Usually | Static keys for workers (or use IRSA / instance role on EKS/EC2). |
| `OPENFLOW_EXPORT_S3_ENDPOINT` | Optional | **Preferred** single URL for MinIO or a custom S3 endpoint. First non-empty among the three endpoint vars wins for client configuration. |
| `OPENFLOW_EXPORT_S3_FORCE_PATH_STYLE` | Optional | `1` / `true` forces path-style addressing (typical for MinIO). If you set any custom endpoint and do **not** set any `*_FORCE_PATH_STYLE` to `false`, the server defaults path-style to **true**. |

Per-feature endpoint overrides (used only if `OPENFLOW_EXPORT_S3_ENDPOINT` is empty):

- `OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_ENDPOINT`
- `OPENFLOW_ACCOUNT_EXPORT_S3_ENDPOINT`

Per-feature force-path overrides:

- `OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_FORCE_PATH_STYLE`
- `OPENFLOW_ACCOUNT_EXPORT_S3_FORCE_PATH_STYLE`

### Workspace shared audit **async** artifacts

| Variable | Required for S3 | Description |
|----------|-------------------|-------------|
| `OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET` | **Yes** to enable S3 | Target bucket name. |
| `OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_PREFIX` | No | Key prefix; default `workspace-shared-audit-exports`. No leading/trailing slashes required. |

Local fallback when S3 is **not** enabled:

- `OPENFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR` (optional; otherwise temp under `openflow-workspace-shared-audit-exports`).

### Account export zip

| Variable | Required for S3 | Description |
|----------|-----------------|-------------|
| `OPENFLOW_ACCOUNT_EXPORT_S3_BUCKET` | **Yes** to enable S3 | Target bucket name. |
| `OPENFLOW_ACCOUNT_EXPORT_S3_PREFIX` | No | Key prefix; default `account-exports`. |

Local fallback:

- `OPENFLOW_LOCAL_ACCOUNT_EXPORT_DIR` (optional; otherwise temp).

## Object key layout

Keys are deterministic and include the **owner user id** (job owner):

```text
{prefix}/{owner_user_id}/{file_name}
```

Examples:

- `workspace-shared-audit-exports/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/workspace_shared_template_audit_20260511T120000Z.json`
- `account-exports/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/openflow-account-export-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee-20260511T120000Z.zip`

`job.result` JSON stores `storage`, `file_name`, `content_type`, `byte_size`, and for S3 also `s3_bucket` and `s3_key` (see worker completion payloads in `workspace_audit_export.rs` and `settings/account/storage.rs`).

## MinIO (quick checklist)

1. Create **two buckets** (or one bucket; separate prefixes still work).
2. Create an **access key** with `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`, `s3:DeleteObject` on those bucket ARNs (delete used on **account delete** cleanup and prefix purge).
3. Set `OPENFLOW_EXPORT_S3_ENDPOINT` to your MinIO API base URL (e.g. `https://minio.example.com`) and `OPENFLOW_EXPORT_S3_FORCE_PATH_STYLE=true` if you use path-style.
4. Set both bucket env vars (or only the features you use).
5. Roll out env + restart **API and workers** together so in-flight jobs do not mix “local result” with “S3-only download” across versions.

## AWS IAM (sketch)

Grant the task role (or access keys) least privilege on the two bucket ARNs:

- `s3:PutObject`, `s3:GetObject` on `arn:aws:s3:::bucket-name/*`
- `s3:ListBucket` with `s3:prefix` condition matching `{prefix}/` if you want tighter List
- `s3:DeleteObject` on `arn:aws:s3:::bucket-name/*` (account delete and optional cleanup)

Enable **default encryption** and **block public access** on both buckets.

## Deploy order

1. Apply **Supabase / Postgres migrations** (includes `app_workspace_shared_audit_export` and RLS).
2. Create buckets and IAM / MinIO policies.
3. Set env vars on **API** and **job worker** processes (same values).
4. Deploy application version that contains S3 support (already in `main` once merged).
5. Smoke-test: enqueue **one** workspace shared audit async export and **one** account export; confirm `GET …/file` returns bytes and `Content-Type` is correct.

## Verification

### Logs

On startup, when buckets are set, the server logs informational lines (see `backend/src/state/from_env.rs`):

- Workspace shared audit S3 bucket set.
- Account export S3 bucket set.
- `OPENFLOW_EXPORT_S3_ENDPOINT` set (shared override).

### Database

- Workspace export history rows: `SELECT COUNT(*) FROM public.app_workspace_shared_audit_export WHERE workspace_id = '…';`
- Jobs: `SELECT id, kind, status, result->>'storage' FROM public.app_generation_job WHERE kind IN ('settings.workspace_shared_audit.export','settings.account.export') ORDER BY created_at DESC LIMIT 10;`

### S3

List a prefix after a test export:

```bash
aws s3 ls "s3://$OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET/workspace-shared-audit-exports/$USER_UUID/" --endpoint-url "$OPENFLOW_EXPORT_S3_ENDPOINT"
```

## Account delete behavior

When a user confirms account deletion, the server **best-effort** deletes:

1. Objects under **`{OPENFLOW_ACCOUNT_EXPORT_S3_PREFIX}/{user_id}/`** in the account export bucket (if account S3 is enabled).
2. Objects under **`{OPENFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_PREFIX}/{user_id}/`** in the workspace shared audit bucket (if that bucket is enabled).

Local directories under `OPENFLOW_LOCAL_*` are still removed as before. Failures in S3 cleanup are **non-fatal** (logged only via `let _ =`); add bucket lifecycle rules as a safety net.

## Troubleshooting

| Symptom | Likely cause | Mitigation |
|---------|----------------|------------|
| `503` / DB errors on export history | Migration not applied | Run migrations; confirm table exists. |
| Job `succeeded` but download `404` | Wrong region/credentials; or file on another replica’s disk (local mode) | Switch to S3 or use shared volume; verify `AWS_REGION` and keys. |
| MinIO `SignatureDoesNotMatch` | Clock skew or wrong endpoint / path-style | Sync NTP; try `OPENFLOW_EXPORT_S3_FORCE_PATH_STYLE=true`. |
| `AccessDenied` on PutObject | IAM / policy | Add `s3:PutObject` on prefix. |
| Stale objects after delete user | S3 cleanup failed silently | Lifecycle rule on `account-exports/` prefix; check worker logs. |

## Related code

- Shared client: `backend/src/settings/export_s3.rs`
- Workspace artifact wrapper: `backend/src/settings/notifications/workspace_audit_export_artifact_storage.rs`
- Workspace worker + download: `backend/src/settings/notifications/workspace_audit_export.rs`
- Account worker + download + delete cleanup: `backend/src/settings/account/storage.rs`
- DB: `supabase/migrations/20260521120000_app_workspace_shared_audit_export.sql`, `…113000…_rls.sql`

## CI

The GitHub Actions workflow that runs `supabase db reset` and `cargo test … --ignored` for workspace shared audit export does **not** configure S3; those tests use **local temp** directories. No S3 credentials are required in CI unless you add an optional job with MinIO as a service container.
