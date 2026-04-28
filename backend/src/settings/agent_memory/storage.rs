use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;

pub(crate) fn parse_agent_type(raw: &str) -> Result<&'static str, ApiError> {
    match raw {
        "scriptAgent" => Ok("scriptAgent"),
        "productionAgent" => Ok("productionAgent"),
        _ => Err(ApiError::BadRequest(
            "agentType must be scriptAgent or productionAgent".into(),
        )),
    }
}

pub(crate) async fn ensure_project_owned(
    pool: &PgPool,
    uid: Uuid,
    numeric_project_id: i32,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_project
          WHERE numeric_id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(numeric_project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ok {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

/// Same DELETE scope as POST /api/v1/agents/memory/clear with clearType: all.
pub(crate) async fn delete_all_agent_memory_rows(
    tx: &mut Transaction<'_, Postgres>,
    uid: Uuid,
    project_id: i32,
    agent_type: &'static str,
    episodes_id: Option<i32>,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = $3
          AND episodes_id IS NOT DISTINCT FROM $4
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(agent_type)
    .bind(episodes_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

/// Append a single memory row to app_agent_memory.
/// Used internally by quality feedback and other automated systems.
pub(crate) async fn append_agent_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    memory_type: &str,
    role: &str,
    content: &str,
    name: Option<&str>,
    create_time_ms: Option<i64>,
) -> Result<(), ApiError> {
    let time_ms = create_time_ms.unwrap_or_else(|| chrono::Utc::now().timestamp_millis());
    let summarized = if memory_type == "summary" { 1 } else { 0 };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
            owner_user_id, numeric_project_id, episodes_id, agent_type,
            memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(memory_type)
    .bind(role)
    .bind(name)
    .bind(content)
    .bind(summarized)
    .bind(time_ms)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Replace a named summary memory within the exact user/project/script/agent scope.
/// This keeps automated summary memories bounded instead of appending indefinitely.
pub(crate) async fn replace_named_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    role: &str,
    name: &str,
    content: &str,
    create_time_ms: Option<i64>,
) -> Result<(), ApiError> {
    let time_ms = create_time_ms.unwrap_or_else(|| chrono::Utc::now().timestamp_millis());

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'summary'
          AND name = $5
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
            owner_user_id, numeric_project_id, episodes_id, agent_type,
            memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'summary', $5, $6, $7, 1, $8)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(role)
    .bind(name)
    .bind(content)
    .bind(time_ms)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}
