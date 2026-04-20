use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::{json, Value};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::storage::{is_unique_violation, trim_opt};
use super::super::types::{
    CodeDataEnvelope, ScriptAgentKind, SetScriptAgentPlanBody, ADV_LOCK_SCRIPT_NUMERIC_ID,
    MAX_PLAN_SCRIPT_ROWS,
};

pub(super) async fn post_set_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SetScriptAgentPlanBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let _ = matches!(body.agent_type, ScriptAgentKind::ScriptAgent);
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.data.script.len() > MAX_PLAN_SCRIPT_ROWS {
        return Err(ApiError::BadRequest(format!(
            "data.script must have at most {MAX_PLAN_SCRIPT_ROWS} rows"
        )));
    }
    let pool = state.require_pool()?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE numeric_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.project_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let plan_json = json!({
        "storySkeleton": body.data.story_skeleton,
        "adaptationStrategy": body.data.adaptation_strategy,
    });

    sqlx::query(
        r#"
        INSERT INTO app_script_agent_plan (owner_user_id, project_id, agent_key, plan_data)
        VALUES ($1, $2, 'scriptAgent', $3::jsonb)
        ON CONFLICT (owner_user_id, project_id, agent_key)
        DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(project_uuid)
    .bind(plan_json.clone())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in &body.data.script {
        let name = trim_opt(&row.name).ok_or_else(|| {
            ApiError::BadRequest("each data.script row must have a non-empty name".into())
        })?;
        let n_updated = sqlx::query(
            r#"
            UPDATE app_script AS s
            SET content = $1, updated_at = NOW()
            FROM (
              SELECT id FROM app_script
              WHERE project_id = $2 AND name = $3
              ORDER BY numeric_id ASC
              LIMIT 1
            ) AS pick
            WHERE s.id = pick.id
            "#,
        )
        .bind(row.content.trim())
        .bind(project_uuid)
        .bind(&name)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .rows_affected();
        if n_updated == 0 {
            let next_numeric_id: i32 = sqlx::query_scalar(
                r#"
                SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_script
                "#,
            )
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let now_ms = chrono::Utc::now().timestamp_millis();
            sqlx::query(
                r#"
                INSERT INTO app_script (
                  project_id, numeric_id, name, content, extract_state, create_time_ms, metadata
                )
                VALUES ($1, $2, $3, $4, NULL, $5, '{}'::jsonb)
                "#,
            )
            .bind(project_uuid)
            .bind(next_numeric_id)
            .bind(&name)
            .bind(row.content.trim())
            .bind(now_ms)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                if is_unique_violation(&e) {
                    ApiError::Conflict(
                        "script name already exists for this project (concurrent insert)".into(),
                    )
                } else {
                    ApiError::DatabaseError(e.to_string())
                }
            })?;
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let ok = CodeDataEnvelope {
        code: 200,
        data: Value::Null,
        message: "成功",
    };
    Ok(JsonResponse(serde_json::to_value(ok).map_err(|e| {
        ApiError::DatabaseError(format!("serialize set-plan-data: {e}"))
    })?))
}
