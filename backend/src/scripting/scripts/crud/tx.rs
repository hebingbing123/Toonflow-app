//! 事务内剧本写入（advisory lock + 分配 numeric_id）。

use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;

use super::super::types::{
    BatchAddScriptItem, BatchAddScriptResponse, CreateScriptBody, ScriptRow,
    ADV_LOCK_SCRIPT_NUMERIC_ID,
};

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(super) async fn create_script_locked(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    body: CreateScriptBody,
) -> Result<ScriptRow, ApiError> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_script
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    sqlx::query_as::<_, ScriptRow>(
        r#"
        INSERT INTO app_script (
          project_id, numeric_id, name, content, extract_state, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
        RETURNING id, project_id, numeric_id, name, content, extract_state, create_time_ms
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.content))
    .bind(body.extract_state)
    .bind(now_ms)
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn batch_add_scripts_locked(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    data: Vec<BatchAddScriptItem>,
) -> Result<BatchAddScriptResponse, ApiError> {
    if data.is_empty() {
        return Ok(BatchAddScriptResponse {
            message: "添加剧本成功".into(),
            inserted: 0,
            scripts: Vec::new(),
        });
    }

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_script
        "#,
    )
    .fetch_one(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut inserted = Vec::with_capacity(data.len());
    for item in data {
        let row = sqlx::query_as::<_, ScriptRow>(
            r#"
            INSERT INTO app_script (
              project_id, numeric_id, name, content, extract_state, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, NULL, $5, '{}'::jsonb)
            RETURNING id, project_id, numeric_id, name, content, extract_state, create_time_ms
            "#,
        )
        .bind(project_uuid)
        .bind(next_numeric_id)
        .bind(item.script_name)
        .bind(item.script_data)
        .bind(now_ms)
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        inserted.push(row);
        next_numeric_id += 1;
    }

    Ok(BatchAddScriptResponse {
        message: "添加剧本成功".into(),
        inserted: i32::try_from(inserted.len()).unwrap_or(i32::MAX),
        scripts: inserted,
    })
}
