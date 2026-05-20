use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::payload_project_numeric_id;
use crate::jobs::worker::common::{job_ok, JobRunError};
use crate::narrative::novels::crawl_auth::resolve_stored_crawl_auth;
use crate::narrative::novels::handlers::crawl_preview::{
    crawl_preview_adaptive, evaluate_novel_import_quality, insert_imported_novels_for_project,
    normalize_extracted_text_for_import, parse_whole_book_chapters_from_normalized,
    CrawlAuditSummary,
};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::dto::JobRow;

pub(crate) async fn run_novel_crawl_import_batch(
    state: &AppState,
    pool: &PgPool,
    row: &JobRow,
) -> Result<(serde_json::Value, Option<serde_json::Value>), JobRunError> {
    let project_id = row
        .payload
        .get("project_id")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s).ok())
        .ok_or_else(|| JobRunError::Failed("payload.project_id must be a UUID string".into()))?;

    let intake_status = row
        .payload
        .get("intake_status")
        .and_then(|v| v.as_str())
        .unwrap_or("pending_review")
        .trim()
        .to_string();

    let intake_note = row
        .payload
        .get("intake_note")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());

    let urls = row
        .payload
        .get("urls")
        .and_then(|v| v.as_array())
        .ok_or_else(|| JobRunError::Failed("payload.urls must be an array".into()))?
        .iter()
        .filter_map(|v| v.as_str().map(|s| s.trim().to_string()))
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>();

    if urls.is_empty() {
        return Err(JobRunError::Failed("payload.urls must not be empty".into()));
    }
    if urls.len() > 50 {
        return Err(JobRunError::Failed("payload.urls too many (max 50)".into()));
    }

    // Enforce workspace write scope for the job owner (same semantics as HTTP mutation handlers).
    require_project_write_scope(state, row.owner_user_id, project_id)
        .await
        .map_err(|e| JobRunError::Failed(format!("project write scope check failed: {e:?}")))?;

    let auth = resolve_stored_crawl_auth(state, pool, project_id)
        .await
        .map_err(|e| JobRunError::Failed(format!("crawl auth resolve failed: {e:?}")))?;

    let mut succeeded = 0i32;
    let mut failed = 0i32;
    let mut items = Vec::<serde_json::Value>::new();

    for url in urls {
        let parsed = match url::Url::parse(&url) {
            Ok(v) => v,
            Err(_) => {
                failed += 1;
                items.push(json!({"url": url, "ok": false, "error_code": "invalid_url", "error_message": "invalid url"}));
                continue;
            }
        };

        let outcome = async {
            let preview = crawl_preview_adaptive(state, &parsed, &auth).await?;
            let normalized_for_import = normalize_extracted_text_for_import(&preview.body_text);
            let mut chapters: Vec<(i32, String, String)> =
                parse_whole_book_chapters_from_normalized(&normalized_for_import, "导入章节");
            chapters.retain(|(_, _, data): &(i32, String, String)| !data.trim().is_empty());
            for (idx, ch) in chapters.iter_mut().enumerate() {
                ch.0 = (idx + 1) as i32;
            }

            let (blockers, warnings): (Vec<String>, Vec<String>) =
                evaluate_novel_import_quality(&chapters, 200, 50, 40);
            if !blockers.is_empty() {
                return Err(crate::error::ApiError::BadRequest(format!(
                    "导入质量门未通过：{}",
                    blockers.join("；")
                )));
            }

            let created = insert_imported_novels_for_project(
                pool,
                project_id,
                &chapters,
                &intake_status,
                intake_note.as_deref(),
                &url,
                &CrawlAuditSummary {
                    mode: preview.mode.clone(),
                    page_count: preview.page_count,
                    chapter_url_count: preview.chapter_url_count,
                    body_char_count: preview.body_char_count,
                },
            )
            .await?;

            Ok::<_, crate::error::ApiError>((preview, created, warnings))
        }
        .await;

        match outcome {
            Ok((preview, created, warnings)) => {
                succeeded += 1;
                items.push(json!({
                  "url": url,
                  "ok": true,
                  "title": preview.title,
                  "mode": preview.mode,
                  "page_count": preview.page_count,
                  "chapter_url_count": preview.chapter_url_count,
                  "body_char_count": preview.body_char_count,
                  "chapters_created": created,
                  "quality_warnings": warnings,
                }));
            }
            Err(e) => {
                failed += 1;
                let (code, msg) = match &e {
                    crate::error::ApiError::BadRequest(m) => ("bad_request", m.clone()),
                    crate::error::ApiError::Forbidden(m) => ("forbidden", m.clone()),
                    crate::error::ApiError::NotFound => ("not_found", "not found".into()),
                    crate::error::ApiError::DatabaseError(m) => ("database_error", m.clone()),
                    crate::error::ApiError::QuotaExceeded(m) => ("quota_exceeded", m.clone()),
                    _ => ("import_failed", format!("{e:?}")),
                };
                items.push(json!({
                  "url": url,
                  "ok": false,
                  "error_code": code,
                  "error_message": msg,
                }));
            }
        }
    }

    // Optional recurrence: if payload.repeat_interval_ms is set, enqueue next run.
    if let Some(interval_ms) = row
        .payload
        .get("repeat_interval_ms")
        .and_then(|v| v.as_i64())
        .filter(|v| *v > 0)
    {
        let now_ms = chrono::Utc::now().timestamp_millis();
        let next_run_at_ms = now_ms + interval_ms;
        let mut next_payload = row.payload.clone();
        next_payload["run_at_ms"] = json!(next_run_at_ms);
        // Keep any existing project UUID / numeric scope keys for task-center filtering.
        if let Err(e) = crate::jobs::enqueue_generation_job(
            pool,
            row.owner_user_id,
            crate::jobs::JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH,
            next_payload,
            None,
            &state.billing_config,
        )
        .await
        {
            tracing::warn!(error = ?e, "failed to enqueue next recurring novel crawl batch job");
        }
    }

    let mut result = json!({
      "project_uuid": project_id,
      "total": succeeded + failed,
      "succeeded": succeeded,
      "failed": failed,
      "items": items
    });
    if let Some(project_numeric_id) = payload_project_numeric_id(&row.payload) {
        result["project_numeric_id"] = json!(project_numeric_id);
    }

    Ok(job_ok(result))
}
