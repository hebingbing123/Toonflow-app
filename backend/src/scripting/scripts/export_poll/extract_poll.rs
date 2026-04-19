use axum::{extract::State, http::HeaderMap, Json};
use sqlx::{Postgres, QueryBuilder};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{ScriptExtractPollBody, ScriptExtractPollRow, MAX_SCRIPT_EXTRACT_POLL};
use super::helpers::normalize_numeric_id_list;

pub(in crate::scripting::scripts) async fn poll_script_extract_state(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ScriptExtractPollBody>,
) -> Result<Json<Vec<ScriptExtractPollRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let numeric_ids = normalize_numeric_id_list(body.numeric_ids, MAX_SCRIPT_EXTRACT_POLL)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT s.numeric_id, s.extract_state, s.error_reason
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(" AND s.numeric_id IN (");
    {
        let mut separated = qb.separated(", ");
        for id in &numeric_ids {
            separated.push_bind(*id);
        }
    }
    qb.push(") AND (s.extract_state IS DISTINCT FROM 0) ORDER BY s.numeric_id");

    let rows: Vec<ScriptExtractPollRow> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
