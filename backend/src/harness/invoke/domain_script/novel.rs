use serde_json::Value;

use super::super::{
    apply_text_window, parse_optional_string_array, parse_optional_usize,
    parse_optional_zero_based_usize, project_numeric_from_ctx, require_pool, select_object_fields,
    InvokeError,
};
use super::rows::{HarnessNovelEventRow, HarnessNovelRow};
use crate::harness::HarnessContext;

const DEFAULT_NOVEL_TEXT_LIMIT: usize = 1;
const DEFAULT_NOVEL_TEXT_LINE_START: usize = 1;
const DEFAULT_NOVEL_TEXT_LINE_END: usize = 80;
const DEFAULT_NOVEL_TEXT_MAX_CHARS: usize = 1800;
const DEFAULT_NOVEL_EVENTS_LIMIT: usize = 8;
const DEFAULT_NOVEL_EVENTS_MAX_CHARS: usize = 1200;
const QUERY_FETCH_CAP: usize = 200;

fn default_novel_text_fields() -> Vec<String> {
    vec![
        "numeric_id".into(),
        "chapter_index".into(),
        "chapter".into(),
        "chapter_data".into(),
    ]
}

fn default_novel_event_fields() -> Vec<String> {
    vec!["numeric_id".into(), "name".into(), "detail".into()]
}

fn effective_novel_text_fields(fields: Option<Vec<String>>) -> Vec<String> {
    fields.unwrap_or_else(default_novel_text_fields)
}

fn effective_novel_event_fields(fields: Option<Vec<String>>) -> Vec<String> {
    fields.unwrap_or_else(default_novel_event_fields)
}

fn effective_novel_text_limit(limit: Option<usize>) -> usize {
    limit.unwrap_or(DEFAULT_NOVEL_TEXT_LIMIT)
}

fn effective_novel_events_limit(limit: Option<usize>) -> usize {
    limit.unwrap_or(DEFAULT_NOVEL_EVENTS_LIMIT)
}

fn effective_novel_text_max_chars(max_chars: Option<usize>) -> usize {
    max_chars.unwrap_or(DEFAULT_NOVEL_TEXT_MAX_CHARS)
}

fn effective_novel_events_max_chars(max_chars: Option<usize>) -> usize {
    max_chars.unwrap_or(DEFAULT_NOVEL_EVENTS_MAX_CHARS)
}

fn effective_novel_text_line_start(line_start: Option<usize>) -> usize {
    line_start.unwrap_or(DEFAULT_NOVEL_TEXT_LINE_START)
}

fn effective_novel_text_line_end(line_end: Option<usize>) -> usize {
    line_end.unwrap_or(DEFAULT_NOVEL_TEXT_LINE_END)
}

fn query_fetch_limit(offset: usize, limit: usize) -> i64 {
    let requested = offset.saturating_add(limit);
    let capped = requested.min(QUERY_FETCH_CAP);
    i64::try_from(capped).unwrap_or(QUERY_FETCH_CAP as i64)
}

pub(crate) async fn invoke_get_novel_text(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let line_start = effective_novel_text_line_start(parse_optional_usize(arguments, "lineStart")?);
    let line_end = effective_novel_text_line_end(parse_optional_usize(arguments, "lineEnd")?);
    let max_chars = effective_novel_text_max_chars(parse_optional_usize(arguments, "maxChars")?);
    let fields = effective_novel_text_fields(parse_optional_string_array(arguments, "fields")?);
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = effective_novel_text_limit(parse_optional_usize(arguments, "limit")?);
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);
    let fetch_limit = query_fetch_limit(offset, limit);

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
            LIMIT $4
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .bind(fetch_limit)
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
            LIMIT $3
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(fetch_limit)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let items = rows
        .into_iter()
        .skip(offset)
        .take(limit)
        .map(|row| {
            let mut value = serde_json::to_value(row)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize novel row".into()))?;
            if let Some(text) = value.get("chapter_data").and_then(Value::as_str) {
                let windowed =
                    apply_text_window(text, Some(line_start), Some(line_end), Some(max_chars));
                if let Some(obj) = value.as_object_mut() {
                    obj.insert("chapter_data".into(), Value::String(windowed));
                }
            }
            value = select_object_fields(&value, &fields);
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
    let max_chars = effective_novel_events_max_chars(parse_optional_usize(arguments, "maxChars")?);
    let fields = effective_novel_event_fields(parse_optional_string_array(arguments, "fields")?);
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = effective_novel_events_limit(parse_optional_usize(arguments, "limit")?);
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);
    let fetch_limit = query_fetch_limit(offset, limit);

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
            LIMIT $4
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .bind(fetch_limit)
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
            LIMIT $3
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(fetch_limit)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let items = rows
        .into_iter()
        .skip(offset)
        .take(limit)
        .map(|row| {
            let mut value = serde_json::to_value(row)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize event row".into()))?;
            if let Some(text) = value.get("detail").and_then(Value::as_str) {
                let windowed = apply_text_window(text, None, None, Some(max_chars));
                if let Some(obj) = value.as_object_mut() {
                    obj.insert("detail".into(), Value::String(windowed));
                }
            }
            value = select_object_fields(&value, &fields);
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn novel_text_defaults_are_compact() {
        assert_eq!(effective_novel_text_limit(None), 1);
        assert_eq!(effective_novel_text_line_start(None), 1);
        assert_eq!(effective_novel_text_line_end(None), 80);
        assert_eq!(effective_novel_text_max_chars(None), 1800);
        assert_eq!(
            effective_novel_text_fields(None),
            vec![
                "numeric_id".to_string(),
                "chapter_index".to_string(),
                "chapter".to_string(),
                "chapter_data".to_string()
            ]
        );
    }

    #[test]
    fn novel_event_defaults_are_compact() {
        assert_eq!(effective_novel_events_limit(None), 8);
        assert_eq!(effective_novel_events_max_chars(None), 1200);
        assert_eq!(
            effective_novel_event_fields(None),
            vec![
                "numeric_id".to_string(),
                "name".to_string(),
                "detail".to_string()
            ]
        );
    }

    #[test]
    fn query_fetch_limit_caps_requested_window() {
        assert_eq!(query_fetch_limit(0, 1), 1);
        assert_eq!(query_fetch_limit(5, 8), 13);
        assert_eq!(query_fetch_limit(500, 50), 200);
    }
}
