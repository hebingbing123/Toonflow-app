use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

pub(super) fn payload_coerced_i32(payload: &Value, key: &str) -> Option<i32> {
    payload.get(key).and_then(|v| {
        if let Some(n) = v.as_i64() {
            return i32::try_from(n).ok();
        }
        if let Some(s) = v.as_str() {
            return s.trim().parse().ok();
        }
        None
    })
}

/// Structured diagnostics for task center / clients when `file_path` writeback fails (J4).
pub(super) fn video_file_writeback_error_details(
    job_kind: &'static str,
    code: &'static str,
    message: impl Into<String>,
    project_numeric_id: Option<i32>,
    script_numeric_id: Option<i32>,
    storyboard_numeric_id: Option<i32>,
) -> Value {
    let message = message.into();
    json!({
        "schema_version": 1,
        "domain": "production.video_file_writeback",
        "code": code,
        "job_kind": job_kind,
        "message": message,
        "action_codes": [
            "workbench_refresh_video_data",
            "workbench_manual_select_video",
            "verify_project_script_storyboard_scope"
        ],
        "context": {
            "project_numeric_id": project_numeric_id,
            "script_numeric_id": script_numeric_id,
            "storyboard_numeric_id": storyboard_numeric_id,
        }
    })
}

pub(super) async fn store_video_reference(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
    storyboard_numeric_id: i32,
    video_url: &str,
) -> Result<u64, sqlx::Error> {
    let res = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $1, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = app_project.workspace_id
                  AND wm.user_id = $2
          )
          AND app_project.numeric_id = $3
          AND app_storyboard.numeric_id = $4
        "#,
    )
    .bind(video_url)
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .bind(storyboard_numeric_id)
    .execute(pool)
    .await?;

    Ok(res.rows_affected())
}
