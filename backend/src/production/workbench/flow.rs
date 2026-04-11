//! 制作流程管理模块。
//!
//! 加载和保存制作流程 JSON 数据。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
    Json as JsonResponse,
};
use serde::Deserialize;
use serde_json::{Map, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::production_flow::{load_owned_production_flow_json, resolve_owned_production_scope};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct GetFlowDataBody {
    project_id: i32,
    episodes_id: i32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct SaveFlowDataBody {
    project_id: i32,
    episodes_id: i32,
    data: Value,
}

fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

pub(crate) async fn post_get_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetFlowDataBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.episodes_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and episodesId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let flow =
        load_owned_production_flow_json(pool, uid, body.project_id, body.episodes_id).await?;
    Ok(JsonResponse(flow))
}

pub(crate) async fn post_save_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveFlowDataBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.episodes_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and episodesId must be positive integers".into(),
        ));
    }
    if body.data.as_object().is_none() {
        return Err(ApiError::BadRequest("data must be a JSON object".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let (project_id, script_id, _) =
        resolve_owned_production_scope(pool, uid, body.project_id, body.episodes_id).await?;

    if let Some(storyboards) = body.data.get("storyboard").and_then(Value::as_array) {
        let ordered_ids = storyboards
            .iter()
            .map(|item| {
                item.as_object()
                    .and_then(|obj| json_i32(obj, "id"))
                    .filter(|id| *id > 0)
            })
            .collect::<Option<Vec<_>>>();

        if let Some(ordered_ids) = ordered_ids {
            for (index, storyboard_numeric_id) in ordered_ids.iter().enumerate() {
                sqlx::query(
                    r#"
                    UPDATE app_storyboard
                    SET sb_index = $3, updated_at = NOW()
                    WHERE script_id = $1
                      AND numeric_id = $2
                    "#,
                )
                .bind(script_id)
                .bind(storyboard_numeric_id)
                .bind(index as i32)
                .execute(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            }
        }
    }

    sqlx::query(
        r#"
        INSERT INTO app_production_flow (project_id, script_id, flow_data)
        VALUES ($1, $2, $3)
        ON CONFLICT (project_id, script_id) DO UPDATE
        SET flow_data = EXCLUDED.flow_data,
            updated_at = NOW()
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .bind(&body.data)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(axum::http::StatusCode::OK.into_response())
}

#[cfg(test)]
mod tests {
    use super::{GetFlowDataBody, SaveFlowDataBody};

    #[test]
    fn get_flow_data_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<GetFlowDataBody>(r#"{"projectId":1,"episodesId":5,"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn get_flow_data_body_accepts_valid() {
        let b: GetFlowDataBody = serde_json::from_str(r#"{"projectId":1,"episodesId":5}"#).unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.episodes_id, 5);
    }

    #[test]
    fn save_flow_data_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<SaveFlowDataBody>(
            r#"{"projectId":1,"episodesId":5,"data":{},"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn save_flow_data_body_accepts_valid() {
        let b: SaveFlowDataBody =
            serde_json::from_str(r#"{"projectId":1,"episodesId":5,"data":{"key":"value"}}"#)
                .unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.episodes_id, 5);
        assert!(b.data.is_object());
    }
}
