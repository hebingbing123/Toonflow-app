//! Postgres access for publish tables.

mod draft;
mod job;
mod metric;
mod profile;
mod target;

// Re-export all public functions
pub(crate) use draft::{
    batch_archive_drafts, batch_set_draft_scheduled_at, delete_draft, fetch_draft,
    fetch_drafts_by_ids, insert_draft, list_drafts, merge_draft_platform_copy, patch_draft_row,
    ScheduledDraftUtcWindow,
};
pub(crate) use job::{
    await_publish_job_confirmation, cancel_job_if_non_terminal, claim_next_publish_job,
    confirm_semi_auto_job, fail_publish_job_claim, fetch_job_owned, finalize_job_with_attempts,
    insert_publish_job, list_attempt_audit, list_jobs, list_low_performance_alerts,
    retry_job_if_allowed, ListAttemptAuditFilter, PublishAttemptUpsert,
};
pub(crate) use metric::{
    claim_next_metric_sync_cursor, complete_metric_sync_cursor, fail_metric_sync_cursor,
    insert_publish_performance_snapshot, PublishPerformanceSnapshotUpsert,
};
pub(crate) use profile::{
    delete_profile, fetch_profile, insert_profile, list_profiles, patch_profile_row,
};
pub(crate) use target::{draft_has_semi_auto_target, list_targets, replace_targets};
