use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::{json, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{CodeDataEnvelope, UpdateScriptAgentDataBody};

pub(super) async fn post_update_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateScriptAgentDataBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }
    let pool = state.require_pool()?;

    let payload = json!({
        "storySkeleton": body.data.story_skeleton,
        "adaptationStrategy": body.data.adaptation_strategy,
        "script": body.data.script.iter().map(|r| json!({
            "id": r.id,
            "content": r.content,
        })).collect::<Vec<_>>(),
    });

    let n = sqlx::query(
        r#"
        UPDATE app_script_agent_plan
        SET plan_data = $1::jsonb, updated_at = NOW()
        WHERE id = $2 AND owner_user_id = $3
        "#,
    )
    .bind(payload)
    .bind(body.id)
    .bind(uid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .rows_affected();
    if n == 0 {
        return Err(ApiError::NotFound);
    }

    let ok = CodeDataEnvelope {
        code: 200,
        data: Value::String("更新成功".to_owned()),
        message: "成功",
    };
    Ok(JsonResponse(serde_json::to_value(ok).map_err(|e| {
        ApiError::DatabaseError(format!("serialize update-data: {e}"))
    })?))
}
