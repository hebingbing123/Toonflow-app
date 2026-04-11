use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::{IntoResponse, Response},
    Json as JsonResponse,
};
use serde::Deserialize;
use serde_json::{json, Map, Value};
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
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

#[derive(Debug, FromRow)]
struct OwnedProductionScope {
    project_id: uuid::Uuid,
    script_id: uuid::Uuid,
    script_content: Option<String>,
}

#[derive(Debug, FromRow)]
struct ProductionAssetFlowRow {
    legacy_id: i32,
    name: String,
    asset_type: String,
    description: Option<String>,
    metadata: Value,
    history_images: Value,
}

#[derive(Debug, FromRow)]
struct ProductionStoryboardFlowRow {
    legacy_id: i32,
    prompt: Option<String>,
    file_path: Option<String>,
    duration: Option<String>,
    state: Option<String>,
    reason: Option<String>,
    video_desc: Option<String>,
    should_generate_image: Option<i32>,
    flow_id: Option<i32>,
    sb_index: Option<i32>,
}

pub(crate) async fn resolve_owned_production_scope(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
) -> Result<(uuid::Uuid, uuid::Uuid), ApiError> {
    let scope = sqlx::query_as::<_, OwnedProductionScope>(
        r#"
        SELECT
          p.id AS project_id,
          s.id AS script_id,
          s.content AS script_content
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;
    Ok((scope.project_id, scope.script_id))
}

fn json_string(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::to_string)
}

fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

fn history_image_src(metadata: &Value, history_images: &[Value]) -> Option<String> {
    let selected_legacy_image_id = metadata
        .get("imageId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());
    if let Some(selected_id) = selected_legacy_image_id {
        if let Some(src) = history_images.iter().find_map(|img| {
            let img_obj = img.as_object()?;
            if json_i32(img_obj, "legacy_image_id") == Some(selected_id) {
                return json_string(img_obj, "file_path");
            }
            None
        }) {
            return Some(src);
        }
    }
    history_images.iter().find_map(|img| {
        img.as_object()
            .and_then(|obj| json_string(obj, "file_path"))
    })
}

fn build_production_asset_item(
    row: &ProductionAssetFlowRow,
    child_rows: &[&ProductionAssetFlowRow],
) -> Value {
    let history_images = row.history_images.as_array().cloned().unwrap_or_default();
    let src = history_image_src(&row.metadata, &history_images);
    let prompt = row
        .metadata
        .get("prompt")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let flow_id = row
        .metadata
        .get("flowId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());

    let derive = child_rows
        .iter()
        .map(|child| {
            let child_history = child.history_images.as_array().cloned().unwrap_or_default();
            json!({
              "id": child.legacy_id,
              "assetsId": row.legacy_id,
              "name": child.name,
              "type": child.asset_type,
              "prompt": child.metadata.get("prompt").and_then(Value::as_str).unwrap_or_default(),
              "desc": child.description.clone().unwrap_or_default(),
              "src": history_image_src(&child.metadata, &child_history),
              "state": child.metadata.get("state").and_then(Value::as_str).unwrap_or("未生成"),
              "flowId": child.metadata.get("flowId").and_then(Value::as_i64).and_then(|v| i32::try_from(v).ok()),
              "errorReason": child.metadata.get("errorReason").and_then(Value::as_str).unwrap_or_default(),
            })
        })
        .collect::<Vec<_>>();

    json!({
      "id": row.legacy_id,
      "name": row.name,
      "type": row.asset_type,
      "prompt": prompt,
      "desc": row.description.clone().unwrap_or_default(),
      "src": src,
      "flowId": flow_id,
      "derive": derive,
    })
}

async fn load_production_flow_json(
    pool: &sqlx::PgPool,
    project_id: uuid::Uuid,
    script_id: uuid::Uuid,
    script_content: Option<String>,
) -> Result<Value, ApiError> {
    let saved = sqlx::query_scalar::<_, Value>(
        r#"
        SELECT flow_data
        FROM app_production_flow
        WHERE project_id = $1
          AND script_id = $2
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .unwrap_or_else(|| json!({}));

    let rows = sqlx::query_as::<_, ProductionAssetFlowRow>(
        r#"
        SELECT
          a.legacy_id,
          a.name,
          a.asset_type,
          a.description,
          a.metadata,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'file_path', i.file_path,
                  'legacy_image_id', i.legacy_image_id,
                  'sort_index', i.sort_index
                )
                ORDER BY i.sort_index ASC, i.created_at ASC
              )
              FROM app_asset_image i
              WHERE i.asset_id = a.id
                AND i.state = '已完成'
            ),
            '[]'::jsonb
          ) AS history_images
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let root_assets = rows
        .iter()
        .filter(|row| match row.metadata.get("assetsId") {
            None => true,
            Some(v) => v.is_null(),
        })
        .map(|row| {
            let child_rows = rows
                .iter()
                .filter(|child| {
                    child
                        .metadata
                        .get("assetsId")
                        .and_then(Value::as_i64)
                        .and_then(|v| i32::try_from(v).ok())
                        == Some(row.legacy_id)
                })
                .collect::<Vec<_>>();
            build_production_asset_item(row, &child_rows)
        })
        .collect::<Vec<_>>();

    let storyboards = sqlx::query_as::<_, ProductionStoryboardFlowRow>(
        r#"
        SELECT
          legacy_id,
          prompt,
          file_path,
          duration,
          state,
          reason,
          video_desc,
          should_generate_image,
          flow_id,
          sb_index
        FROM app_storyboard
        WHERE script_id = $1
        ORDER BY COALESCE(sb_index, 2147483647), legacy_id
        "#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let saved_obj = saved.as_object().cloned().unwrap_or_default();
    let saved_storyboard_by_id = saved_obj
        .get("storyboard")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|item| {
            let obj = item.as_object()?.clone();
            Some((json_i32(&obj, "id")?, obj))
        })
        .collect::<std::collections::HashMap<_, _>>();

    let storyboard_items = storyboards
        .into_iter()
        .map(|row| {
            let saved_storyboard = saved_storyboard_by_id.get(&row.legacy_id);
            json!({
              "id": row.legacy_id,
              "index": row.sb_index,
              "duration": row.duration.as_deref().and_then(|v| v.parse::<i32>().ok()).unwrap_or(0),
              "prompt": row.prompt.clone().unwrap_or_default(),
              "associateAssetsIds": saved_storyboard
                .and_then(|obj| obj.get("associateAssetsIds"))
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default(),
              "src": row.file_path,
              "state": row.state,
              "videoDesc": row.video_desc,
              "shouldGenerateImage": row.should_generate_image,
              "reason": row.reason.unwrap_or_default(),
              "flowId": row.flow_id,
            })
        })
        .collect::<Vec<_>>();

    let mut merged = saved_obj;
    merged.insert(
        "script".into(),
        Value::String(script_content.unwrap_or_default()),
    );
    merged.insert(
        "scriptPlan".into(),
        merged
            .get("scriptPlan")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("assets".into(), Value::Array(root_assets));
    merged.insert(
        "storyboardTable".into(),
        merged
            .get("storyboardTable")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("storyboard".into(), Value::Array(storyboard_items));
    Ok(Value::Object(merged))
}

pub(crate) async fn load_owned_production_flow_json(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
) -> Result<Value, ApiError> {
    let scope = sqlx::query_as::<_, OwnedProductionScope>(
        r#"
        SELECT
          p.id AS project_id,
          s.id AS script_id,
          s.content AS script_content
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    load_production_flow_json(
        pool,
        scope.project_id,
        scope.script_id,
        scope.script_content,
    )
    .await
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
    let (project_id, script_id) =
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
            for (index, storyboard_legacy_id) in ordered_ids.iter().enumerate() {
                sqlx::query(
                    r#"
                    UPDATE app_storyboard
                    SET sb_index = $3, updated_at = NOW()
                    WHERE script_id = $1
                      AND legacy_id = $2
                    "#,
                )
                .bind(script_id)
                .bind(storyboard_legacy_id)
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
