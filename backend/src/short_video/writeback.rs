//! Storyboard **`metadata.shortVideo.lastWriteback`** persistence (MP-W4 / J4).

use chrono::Utc;
use serde_json::json;
use sqlx::PgPool;

/// Persist per-shot video writeback diagnostics for Space / production clients.
pub async fn persist_storyboard_last_writeback(
    pool: &PgPool,
    project_numeric_id: i32,
    storyboard_numeric_id: i32,
    status: &str,
    error_code: Option<&str>,
) -> Result<(), sqlx::Error> {
    let at = Utc::now().to_rfc3339();
    let patch = json!({
        "status": status,
        "at": at,
        "errorCode": error_code,
    });
    sqlx::query(
        r#"
        UPDATE app_storyboard sb
        SET
          metadata = jsonb_set(
            jsonb_set(
              COALESCE(sb.metadata, '{}'::jsonb),
              '{shortVideo}',
              COALESCE(sb.metadata->'shortVideo', '{}'::jsonb),
              true
            ),
            '{shortVideo,lastWriteback}',
            $1::jsonb,
            true
          ),
          updated_at = NOW()
        FROM app_script sc
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE sb.script_id = sc.id
          AND p.numeric_id = $2
          AND sb.numeric_id = $3
        "#,
    )
    .bind(patch)
    .bind(project_numeric_id)
    .bind(storyboard_numeric_id)
    .execute(pool)
    .await?;
    Ok(())
}

/// Best-effort metadata mirror after worker writeback attempt.
pub async fn persist_from_job_writeback_json(
    pool: &PgPool,
    project_numeric_id: Option<i32>,
    storyboard_numeric_id: Option<i32>,
    writeback: &serde_json::Value,
) {
    let (Some(pid), Some(sid)) = (project_numeric_id, storyboard_numeric_id) else {
        return;
    };
    let (status, error_code) = last_writeback_status_from_writeback_json(writeback);
    if let Err(e) =
        persist_storyboard_last_writeback(pool, pid, sid, status, error_code.as_deref()).await
    {
        tracing::warn!(
            project_numeric_id = pid,
            storyboard_numeric_id = sid,
            error = %e,
            "failed to persist shortVideo.lastWriteback metadata"
        );
    }
}

#[inline]
pub fn last_writeback_status_from_writeback_json(
    writeback: &serde_json::Value,
) -> (&'static str, Option<String>) {
    let status = writeback
        .get("status")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");
    let code = writeback
        .get("code")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    match status {
        "ok" => ("ok", None),
        "skipped_missing_scope" => (
            "incomplete",
            Some(code.unwrap_or_else(|| "writeback_skipped_missing_scope".to_string())),
        ),
        "no_row_matched" => (
            "incomplete",
            Some(code.unwrap_or_else(|| "writeback_no_row_matched".to_string())),
        ),
        "sql_error" => (
            "failed",
            Some(code.unwrap_or_else(|| "writeback_sql_error".to_string())),
        ),
        _ => ("incomplete", code),
    }
}
