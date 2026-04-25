use serde_json::Value;

use super::super::{
    apply_text_window, parse_optional_string_array, parse_optional_usize,
    parse_optional_zero_based_usize, project_numeric_from_ctx, require_pool, select_object_fields,
    InvokeError,
};
use super::rows::{HarnessNovelEventRow, HarnessNovelRow};
use crate::harness::HarnessContext;

pub(crate) async fn invoke_get_novel_text(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let line_start = parse_optional_usize(arguments, "lineStart")?;
    let line_end = parse_optional_usize(arguments, "lineEnd")?;
    let max_chars = parse_optional_usize(arguments, "maxChars")?;
    let fields = parse_optional_string_array(arguments, "fields")?;
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = parse_optional_usize(arguments, "limit")?;
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

    let items = rows
        .into_iter()
        .skip(offset)
        .take(limit.unwrap_or(usize::MAX))
        .map(|row| {
            let mut value = serde_json::to_value(row)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize novel row".into()))?;
            if let Some(text) = value.get("chapter_data").and_then(Value::as_str) {
                let windowed = apply_text_window(text, line_start, line_end, max_chars);
                if let Some(obj) = value.as_object_mut() {
                    obj.insert("chapter_data".into(), Value::String(windowed));
                }
            }
            if let Some(fields) = fields.as_ref() {
                value = select_object_fields(&value, fields);
            }
            Ok(value)
        })
        .collect::<Result<Vec<_>, InvokeError>>()?;
    let total = items.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": items,
        "total": total,
    }))
}

pub(crate) async fn invoke_get_novel_events(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let max_chars = parse_optional_usize(arguments, "maxChars")?;
    let fields = parse_optional_string_array(arguments, "fields")?;
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = parse_optional_usize(arguments, "limit")?;
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

    let items = rows
        .into_iter()
        .skip(offset)
        .take(limit.unwrap_or(usize::MAX))
        .map(|row| {
            let mut value = serde_json::to_value(row)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize event row".into()))?;
            if let Some(text) = value.get("detail").and_then(Value::as_str) {
                let windowed = apply_text_window(text, None, None, max_chars);
                if let Some(obj) = value.as_object_mut() {
                    obj.insert("detail".into(), Value::String(windowed));
                }
            }
            if let Some(fields) = fields.as_ref() {
                value = select_object_fields(&value, fields);
            }
            Ok(value)
        })
        .collect::<Result<Vec<_>, InvokeError>>()?;
    let total = items.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": items,
        "total": total,
    }))
}
