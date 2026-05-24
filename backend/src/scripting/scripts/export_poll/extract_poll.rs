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
        WHERE EXISTS (
          SELECT 1
          FROM app_workspace_member wm
          WHERE wm.workspace_id = p.workspace_id
            AND wm.user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(
        r#"
        )
        AND s.numeric_id IN ("#,
    );
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

#[cfg(test)]
mod sql_tests {
    use sqlx::{Execute, Postgres, QueryBuilder};
    use uuid::Uuid;

    fn extract_poll_sql(uid: Uuid, numeric_ids: &[i32]) -> String {
        let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
            r#"
        SELECT s.numeric_id, s.extract_state, s.error_reason
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE EXISTS (
          SELECT 1
          FROM app_workspace_member wm
          WHERE wm.workspace_id = p.workspace_id
            AND wm.user_id = "#,
        );
        qb.push_bind(uid);
        qb.push(
            r#"
        )
        AND s.numeric_id IN ("#,
        );
        {
            let mut separated = qb.separated(", ");
            for id in numeric_ids {
                separated.push_bind(*id);
            }
        }
        qb.push(") AND (s.extract_state IS DISTINCT FROM 0) ORDER BY s.numeric_id");
        qb.build().sql().to_string()
    }

    #[test]
    fn poll_sql_closes_exists_before_numeric_id_filter() {
        let sql = extract_poll_sql(Uuid::nil(), &[1, 2]);
        assert!(
            sql.contains("AND s.numeric_id IN ($2"),
            "expected workspace filter then numeric_id IN, got: {sql}"
        );
        assert!(
            !sql.contains("wm.user_id = $1 AND s.numeric_id"),
            "numeric_id filter must be outside EXISTS, got: {sql}"
        );
    }
}
