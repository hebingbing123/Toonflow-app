use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::state::AppState;

use super::super::storage::{delete_all_agent_memory_rows, ensure_project_owned, parse_agent_type};
use super::super::types::{ClearMemoryBody, ClearMemoryResponse};

#[utoipa::path(
    post,
    path = "/api/v1/agents/memory/clear",
    operation_id = "clearAgentMemoryV1",
    tag = "agents",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn clear_memory(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearMemoryBody>,
) -> Result<Json<ClearMemoryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let agent_type = parse_agent_type(&body.agent_type)?;
    let pool = state.require_pool()?;

    ensure_project_owned(pool, uid, body.project_id).await?;
    observe::memory_http(uid, body.project_id, "clear");

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    match body.clear_type.as_str() {
        "all" => {
            delete_all_agent_memory_rows(
                &mut tx,
                uid,
                body.project_id,
                agent_type,
                body.episodes_id,
            )
            .await?;
        }
        "message" => {
            sqlx::query(
                r#"
                DELETE FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'message'
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
        "summary" => {
            sqlx::query(
                r#"
                UPDATE app_agent_memory
                SET summarized = 0
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'message'
                  AND summarized = 1
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            sqlx::query(
                r#"
                DELETE FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND agent_type = $3
                  AND episodes_id IS NOT DISTINCT FROM $4
                  AND memory_type = 'summary'
                "#,
            )
            .bind(uid)
            .bind(body.project_id)
            .bind(agent_type)
            .bind(body.episodes_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }
        _ => {
            return Err(ApiError::BadRequest(
                "clearType must be all, message, or summary".into(),
            ));
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ClearMemoryResponse { ok: true }))
}
