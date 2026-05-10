use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

pub(super) fn is_unique_violation(e: &sqlx::Error) -> bool {
    match e {
        sqlx::Error::Database(db) => db.code().map(|c| c == "23505").unwrap_or(false),
        _ => false,
    }
}

pub(super) fn trim_opt(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

pub(super) async fn resolve_owned_project_uuid(
    pool: &PgPool,
    uid: Uuid,
    project_numeric_id: i32,
) -> Result<Uuid, ApiError> {
    if project_numeric_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE numeric_id = $1 AND owner_user_id = $2
          AND archived_at IS NULL
        "#,
    )
    .bind(project_numeric_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

pub(super) async fn select_plan_row(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Uuid,
) -> Result<Option<(i64, Value)>, ApiError> {
    let row: Option<(i64, Value)> = sqlx::query_as(
        r#"
        SELECT id, plan_data
        FROM app_script_agent_plan
        WHERE owner_user_id = $1 AND project_id = $2 AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(uid)
    .bind(project_uuid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row)
}

pub(super) async fn scripts_json_for_project(
    pool: &PgPool,
    project_uuid: Uuid,
) -> Result<Value, ApiError> {
    let rows: Vec<(i32, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT numeric_id, name, content
        FROM app_script
        WHERE project_id = $1
        ORDER BY numeric_id ASC
        "#,
    )
    .bind(project_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let arr: Vec<Value> = rows
        .into_iter()
        .map(|(id, name, content)| {
            json!({
                "id": id,
                "name": name.unwrap_or_default(),
                "content": content.unwrap_or_default(),
            })
        })
        .collect();
    Ok(Value::Array(arr))
}
