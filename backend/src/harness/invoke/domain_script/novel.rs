use serde_json::Value;

use super::super::{project_numeric_from_ctx, require_pool, InvokeError};
use super::rows::{HarnessNovelEventRow, HarnessNovelRow};
use crate::harness::HarnessContext;

pub(crate) async fn invoke_get_novel_text(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelRow> = if let Some(novel_id) = novel_numeric_id {
        sqlx::query_as(
            r#"
            SELECT n.numeric_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND n.numeric_id = $3
            ORDER BY n.chapter_index ASC, n.numeric_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT n.numeric_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
            ORDER BY n.chapter_index ASC, n.numeric_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let total = rows.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": rows,
        "total": total,
    }))
}

pub(crate) async fn invoke_get_novel_events(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelEventRow> = if let Some(novel_id) = novel_numeric_id {
        sqlx::query_as(
            r#"
            SELECT e.numeric_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            INNER JOIN app_novel_event_chapter ec ON ec.event_id = e.id
            INNER JOIN app_novel n ON n.id = ec.novel_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND n.numeric_id = $3
            ORDER BY e.numeric_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT e.numeric_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
            ORDER BY e.numeric_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let total = rows.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": rows,
        "total": total,
    }))
}
