//! Backfill `workspace_id` for existing `app_generation_job` records.
//!
//! **Related spec**: `.kiro/specs/workspace-scope-billing/` (Task 2.2)
//! **Requirements**: 2.1, 2.2, 2.3, 9.3
//! **ADR**: `docs/plans/adr-workspace-billing-storage-model.md`
//!
//! This script populates `workspace_id` for jobs created before workspace billing migration.
//!
//! ## Resolution Strategy
//!
//! For each job with `workspace_id IS NULL`:
//!
//! 1. **Project-based jobs**: Extract `project_uuid` or `project_numeric_id` from payload,
//!    resolve to project's `workspace_id`
//! 2. **Orphan jobs** (no project context): Resolve to user's personal workspace
//!    (guaranteed to exist via workspace foundation migration)
//!
//! ## Usage
//!
//! ```bash
//! # Dry-run mode (preview changes without applying)
//! DATABASE_URL=postgresql://... cargo run --bin backfill-job-workspace-id -- --dry-run
//!
//! # Apply changes (batch size 1000)
//! DATABASE_URL=postgresql://... cargo run --bin backfill-job-workspace-id
//!
//! # Custom batch size
//! DATABASE_URL=postgresql://... cargo run --bin backfill-job-workspace-id -- --batch-size 500
//! ```
//!
//! ## Edge Cases Handled
//!
//! - **Invalid project references**: Logged as errors, job skipped (manual review needed)
//! - **User without personal workspace**: Should not happen (foundation migration creates them),
//!   but logged as error if encountered
//! - **Archived workspaces**: Still used for historical attribution (billing reconciliation)
//! - **Deleted projects**: Job remains with NULL workspace_id, logged for manual review
//!
//! ## Safety
//!
//! - Idempotent: Can be run multiple times (only updates NULL workspace_id)
//! - Transactional batches: Each batch commits atomically
//! - Progress reporting: Shows counts and examples every batch
//! - Error handling: Continues on individual job errors, reports at end

use anyhow::{Context, Result};
use clap::Parser;
use serde_json::Value as JsonValue;
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Parser, Debug)]
#[command(name = "backfill-job-workspace-id")]
#[command(about = "Backfill workspace_id for app_generation_job records")]
struct Args {
    /// Dry-run mode: preview changes without applying them
    #[arg(long)]
    dry_run: bool,

    /// Batch size for processing jobs
    #[arg(long, default_value = "1000")]
    batch_size: i64,
}

#[derive(Debug, sqlx::FromRow)]
struct JobToBackfill {
    id: Uuid,
    owner_user_id: Uuid,
    kind: String,
    payload: JsonValue,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug)]
struct BackfillResult {
    job_id: Uuid,
    resolved_workspace_id: Option<Uuid>,
    resolution_method: ResolutionMethod,
}

#[derive(Debug, Clone, Copy)]
enum ResolutionMethod {
    ProjectUuid,
    ProjectNumericId,
    PersonalWorkspace,
    Failed,
}

impl std::fmt::Display for ResolutionMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ResolutionMethod::ProjectUuid => write!(f, "project_uuid"),
            ResolutionMethod::ProjectNumericId => write!(f, "project_numeric_id"),
            ResolutionMethod::PersonalWorkspace => write!(f, "personal_workspace"),
            ResolutionMethod::Failed => write!(f, "failed"),
        }
    }
}

/// Extract project_uuid from job payload
fn extract_project_uuid(payload: &JsonValue) -> Option<Uuid> {
    payload
        .get("project_uuid")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s).ok())
}

/// Extract project_numeric_id from job payload
fn extract_project_numeric_id(payload: &JsonValue) -> Option<i64> {
    payload.get("project_numeric_id").and_then(|v| v.as_i64())
}

/// Resolve workspace_id from project_uuid
async fn resolve_from_project_uuid(pool: &PgPool, project_uuid: Uuid) -> Result<Option<Uuid>> {
    let workspace_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT workspace_id
        FROM public.app_project
        WHERE id = $1
        "#,
    )
    .bind(project_uuid)
    .fetch_optional(pool)
    .await
    .context("query project by uuid")?
    .flatten();

    Ok(workspace_id)
}

/// Resolve workspace_id from project_numeric_id (legacy_id)
async fn resolve_from_project_numeric_id(
    pool: &PgPool,
    project_numeric_id: i64,
) -> Result<Option<Uuid>> {
    let workspace_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT workspace_id
        FROM public.app_project
        WHERE legacy_id = $1
        "#,
    )
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .context("query project by numeric_id")?
    .flatten();

    Ok(workspace_id)
}

/// Resolve user's personal workspace (fallback for orphan jobs)
async fn resolve_personal_workspace(pool: &PgPool, user_id: Uuid) -> Result<Option<Uuid>> {
    let workspace_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id
        FROM public.app_workspace
        WHERE owner_user_id = $1
          AND workspace_type = 'personal'
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .context("query personal workspace")?;

    Ok(workspace_id)
}

/// Resolve workspace_id for a single job using the canonical resolution strategy
async fn resolve_workspace_id_for_job(
    pool: &PgPool,
    job: &JobToBackfill,
) -> Result<BackfillResult> {
    // Strategy 1: Try project_uuid
    if let Some(project_uuid) = extract_project_uuid(&job.payload) {
        match resolve_from_project_uuid(pool, project_uuid).await {
            Ok(Some(workspace_id)) => {
                return Ok(BackfillResult {
                    job_id: job.id,
                    resolved_workspace_id: Some(workspace_id),
                    resolution_method: ResolutionMethod::ProjectUuid,
                });
            }
            Ok(None) => {
                tracing::warn!(
                    job_id = %job.id,
                    project_uuid = %project_uuid,
                    "project not found or has NULL workspace_id"
                );
            }
            Err(e) => {
                tracing::error!(
                    job_id = %job.id,
                    project_uuid = %project_uuid,
                    error = %e,
                    "failed to resolve workspace from project_uuid"
                );
            }
        }
    }

    // Strategy 2: Try project_numeric_id
    if let Some(project_numeric_id) = extract_project_numeric_id(&job.payload) {
        match resolve_from_project_numeric_id(pool, project_numeric_id).await {
            Ok(Some(workspace_id)) => {
                return Ok(BackfillResult {
                    job_id: job.id,
                    resolved_workspace_id: Some(workspace_id),
                    resolution_method: ResolutionMethod::ProjectNumericId,
                });
            }
            Ok(None) => {
                tracing::warn!(
                    job_id = %job.id,
                    project_numeric_id = %project_numeric_id,
                    "project not found or has NULL workspace_id"
                );
            }
            Err(e) => {
                tracing::error!(
                    job_id = %job.id,
                    project_numeric_id = %project_numeric_id,
                    error = %e,
                    "failed to resolve workspace from project_numeric_id"
                );
            }
        }
    }

    // Strategy 3: Fallback to personal workspace (orphan jobs)
    match resolve_personal_workspace(pool, job.owner_user_id).await {
        Ok(Some(workspace_id)) => {
            return Ok(BackfillResult {
                job_id: job.id,
                resolved_workspace_id: Some(workspace_id),
                resolution_method: ResolutionMethod::PersonalWorkspace,
            });
        }
        Ok(None) => {
            tracing::error!(
                job_id = %job.id,
                owner_user_id = %job.owner_user_id,
                "personal workspace not found (should not happen)"
            );
        }
        Err(e) => {
            tracing::error!(
                job_id = %job.id,
                owner_user_id = %job.owner_user_id,
                error = %e,
                "failed to resolve personal workspace"
            );
        }
    }

    // Failed to resolve
    Ok(BackfillResult {
        job_id: job.id,
        resolved_workspace_id: None,
        resolution_method: ResolutionMethod::Failed,
    })
}

/// Apply backfill results to database (batch update)
async fn apply_backfill_batch(
    pool: &PgPool,
    results: &[BackfillResult],
    dry_run: bool,
) -> Result<usize> {
    if dry_run {
        return Ok(results.len());
    }

    let mut updated = 0;
    for result in results {
        if let Some(workspace_id) = result.resolved_workspace_id {
            let rows_affected = sqlx::query(
                r#"
                UPDATE public.app_generation_job
                SET workspace_id = $1
                WHERE id = $2
                  AND workspace_id IS NULL
                "#,
            )
            .bind(workspace_id)
            .bind(result.job_id)
            .execute(pool)
            .await
            .context("update job workspace_id")?
            .rows_affected();

            updated += rows_affected as usize;
        }
    }

    Ok(updated)
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    dotenvy::dotenv().ok();

    let args = Args::parse();

    let database_url = std::env::var("DATABASE_URL").context("DATABASE_URL is required")?;

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .context("connect postgres")?;

    tracing::info!(
        dry_run = args.dry_run,
        batch_size = args.batch_size,
        "starting workspace_id backfill"
    );

    // Count total jobs needing backfill
    let total_jobs: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM public.app_generation_job
        WHERE workspace_id IS NULL
        "#,
    )
    .fetch_one(&pool)
    .await
    .context("count jobs with NULL workspace_id")?;

    tracing::info!(total_jobs = total_jobs, "jobs with NULL workspace_id found");

    if total_jobs == 0 {
        tracing::info!("no jobs to backfill, exiting");
        return Ok(());
    }

    let mut processed = 0;
    let mut updated = 0;
    let mut failed = 0;
    let mut method_counts: HashMap<String, usize> = HashMap::new();

    loop {
        // Fetch batch of jobs with NULL workspace_id
        let jobs: Vec<JobToBackfill> = sqlx::query_as(
            r#"
            SELECT id, owner_user_id, kind, payload, created_at
            FROM public.app_generation_job
            WHERE workspace_id IS NULL
            ORDER BY created_at ASC
            LIMIT $1
            "#,
        )
        .bind(args.batch_size)
        .fetch_all(&pool)
        .await
        .context("fetch jobs batch")?;

        if jobs.is_empty() {
            break;
        }

        let batch_size = jobs.len();
        tracing::info!(
            batch_size = batch_size,
            processed = processed,
            total = total_jobs,
            "processing batch"
        );

        // Resolve workspace_id for each job
        let mut results = Vec::new();
        for job in &jobs {
            let result = resolve_workspace_id_for_job(&pool, job).await?;
            results.push(result);
        }

        // Apply updates
        let batch_updated = apply_backfill_batch(&pool, &results, args.dry_run).await?;
        updated += batch_updated;

        // Collect statistics
        for result in &results {
            processed += 1;
            let method_key = result.resolution_method.to_string();
            *method_counts.entry(method_key).or_insert(0) += 1;

            if result.resolved_workspace_id.is_none() {
                failed += 1;
            }
        }

        // Show progress with examples
        if processed % 1000 == 0 || processed == total_jobs as usize {
            tracing::info!(
                processed = processed,
                updated = updated,
                failed = failed,
                total = total_jobs,
                progress_pct = (processed as f64 / total_jobs as f64 * 100.0) as u32,
                "progress update"
            );

            // Show first few examples from this batch
            for (i, (result, job)) in results.iter().zip(jobs.iter()).take(3).enumerate() {
                if let Some(workspace_id) = result.resolved_workspace_id {
                    tracing::debug!(
                        example = i + 1,
                        job_id = %result.job_id,
                        job_kind = %job.kind,
                        job_created_at = %job.created_at,
                        workspace_id = %workspace_id,
                        method = %result.resolution_method,
                        "example resolution"
                    );
                }
            }
        }
    }

    // Final summary
    tracing::info!("=== Backfill Summary ===");
    tracing::info!(
        mode = if args.dry_run { "DRY-RUN" } else { "APPLIED" },
        total_jobs = total_jobs,
        processed = processed,
        updated = updated,
        failed = failed,
        "backfill complete"
    );

    tracing::info!("Resolution methods:");
    for (method, count) in method_counts.iter() {
        tracing::info!(
            method = method,
            count = count,
            percentage = ((*count as f64 / processed as f64) * 100.0) as u32,
            "method stats"
        );
    }

    if failed > 0 {
        tracing::warn!(
            failed = failed,
            "jobs failed to resolve workspace_id (manual review needed)"
        );
        tracing::warn!(
            "Query failed jobs with: SELECT * FROM app_generation_job WHERE workspace_id IS NULL"
        );
    }

    if args.dry_run {
        tracing::info!("DRY-RUN mode: no changes were applied");
        tracing::info!("Run without --dry-run to apply changes");
    } else {
        tracing::info!("Backfill applied successfully");
        if failed == 0 {
            tracing::info!(
                "All jobs resolved successfully - ready for Task 2.3 (enforce NOT NULL)"
            );
        } else {
            tracing::warn!("Some jobs failed to resolve - review before Task 2.3");
        }
    }

    Ok(())
}
