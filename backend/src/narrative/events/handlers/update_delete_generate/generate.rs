use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::super::dto::{
    GenerateNovelEventsBody, NovelEventExtractionRow, NovelOkMessageResponse,
};
use super::super::super::extraction::{
    resolve_event_extraction_prompt, run_novel_event_extraction_task,
};
use super::super::super::MAX_GENERATE_EVENTS_CONCURRENCY;

fn is_blocked_intake_status(status: Option<&str>) -> bool {
    matches!(
        status,
        Some("draft") | Some("pending_review") | Some("rejected")
    )
}

fn invalid_novel_quality_reason(chapter_data: &str) -> Option<&'static str> {
    let len = chapter_data.chars().count();
    if len < 30 {
        return Some("正文过短");
    }
    None
}

pub(crate) async fn post_generate_novel_events_for_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_uuid): Path<Uuid>,
    Json(body): Json<GenerateNovelEventsBody>,
) -> Result<JsonResponse<NovelOkMessageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.novel_ids.is_empty() {
        return Err(bad_request_i18n(
            "novelIds must not be empty",
            "novelIds 不能为空",
        ));
    }
    if body.concurrent_count == 0 {
        return Err(bad_request_i18n(
            "concurrentCount must be >= 1",
            "concurrentCount 必须大于等于 1",
        ));
    }
    if body.concurrent_count > MAX_GENERATE_EVENTS_CONCURRENCY {
        return Err(ApiError::BadRequest(format!(
            "concurrentCount must be at most {MAX_GENERATE_EVENTS_CONCURRENCY}"
        )));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_project_write_scope(&state, uid, project_uuid).await?;

    let novels: Vec<NovelEventExtractionRow> = sqlx::query_as(
        r#"
        SELECT n.id,
               p.numeric_id AS project_numeric_id,
               n.numeric_id,
               n.chapter_index,
               n.reel,
               n.chapter,
               n.chapter_data,
               n.metadata->>'intakeStatus' AS intake_status
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = $1
          AND n.numeric_id = ANY($2)
        ORDER BY n.chapter_index ASC, n.numeric_id ASC
        "#,
    )
    .bind(project_uuid)
    .bind(&body.novel_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if novels.is_empty() {
        return Err(ApiError::BadRequest("没有对应章节".into()));
    }
    let blocked_ids: Vec<i32> = novels
        .iter()
        .filter(|row| is_blocked_intake_status(row.intake_status.as_deref()))
        .map(|row| row.numeric_id)
        .collect();
    if !blocked_ids.is_empty() {
        return Err(ApiError::BadRequest(format!(
            "以下章节尚未准入，不可直接生成事件：{}",
            blocked_ids
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join(", ")
        )));
    }
    let low_quality_ids: Vec<String> = novels
        .iter()
        .filter_map(|row| {
            invalid_novel_quality_reason(&row.chapter_data)
                .map(|reason| format!("{}({reason})", row.numeric_id))
        })
        .collect();
    if !low_quality_ids.is_empty() {
        return Err(ApiError::BadRequest(format!(
            "以下章节未通过质量门，不可直接生成事件：{}",
            low_quality_ids.join(", ")
        )));
    }

    let ids: Vec<Uuid> = novels.iter().map(|n| n.id).collect();
    sqlx::query(
        r#"
        UPDATE app_novel
        SET event = NULL, event_state = 0, error_reason = NULL, updated_at = NOW()
        WHERE id = ANY($1)
        "#,
    )
    .bind(&ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let prompt = resolve_event_extraction_prompt(pool, uid).await?;
    let pool_clone = pool.clone();
    let llm = state.llm.clone();
    let http_client = state.http_client.clone();
    let concurrency = body.concurrent_count;

    tokio::spawn(async move {
        run_novel_event_extraction_task(
            pool_clone,
            uid,
            llm,
            http_client,
            prompt,
            novels,
            concurrency,
        )
        .await;
    });

    Ok(JsonResponse(NovelOkMessageResponse {
        message: "生成事件成功",
    }))
}

#[cfg(test)]
mod tests {
    use super::{invalid_novel_quality_reason, is_blocked_intake_status};

    #[test]
    fn blocks_pending_and_rejected_intake_status() {
        assert!(is_blocked_intake_status(Some("draft")));
        assert!(is_blocked_intake_status(Some("pending_review")));
        assert!(is_blocked_intake_status(Some("rejected")));
        assert!(!is_blocked_intake_status(Some("admitted")));
        assert!(!is_blocked_intake_status(None));
    }

    #[test]
    fn blocks_short_chapter_data_in_quality_gate() {
        assert_eq!(invalid_novel_quality_reason("短内容"), Some("正文过短"));
        assert_eq!(
            invalid_novel_quality_reason(&"a".repeat(29)),
            Some("正文过短")
        );
        assert_eq!(invalid_novel_quality_reason(&"a".repeat(30)), None);
    }
}
