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
