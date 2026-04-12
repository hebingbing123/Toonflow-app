//! 制作流程 JSON 加载与项目/剧本归属解析。
//!
//! 供 **`/api/v1/production/get-flow-data`** 与 Harness 工具共用，与 **`production`** 路由模块解耦（共享领域逻辑而非 HTTP 树）。
//!
//! **归属**：剧本级 UUID 解析使用 [`crate::scope::owned_script_scope`]；本模块再读取 `app_script.content` 等制作流所需字段。

use serde_json::{json, Map, Value};
use sqlx::FromRow;
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope::ScopeError;

#[derive(Debug, FromRow)]
struct ScriptContentRow {
    script_content: Option<String>,
}

#[derive(Debug, FromRow)]
struct ProductionAssetFlowRow {
    #[sqlx(rename = "numeric_id")]
    numeric_id: i32,
    name: String,
    asset_type: String,
    description: Option<String>,
    metadata: Value,
    history_images: Value,
}

#[derive(Debug, FromRow)]
struct ProductionStoryboardFlowRow {
    #[sqlx(rename = "numeric_id")]
    numeric_id: i32,
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

/// Resolve caller-owned project + script UUIDs from stable integer ids (Electron-era keys).
pub(crate) async fn resolve_owned_production_scope(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(Uuid, Uuid, Option<String>), ApiError> {
    let scope = crate::scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
        .await
        .map_err(|e| match e {
            ScopeError::NotFound => ApiError::NotFound,
            ScopeError::Database(msg) => ApiError::DatabaseError(msg),
        })?;

    let row: ScriptContentRow = sqlx::query_as(
        r#"
        SELECT content AS script_content
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(scope.script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((scope.project_id, scope.script_id, row.script_content))
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
    let selected_numeric_image_id = metadata
        .get("imageId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());
    if let Some(selected_id) = selected_numeric_image_id {
        if let Some(src) = history_images.iter().find_map(|img| {
            let img_obj = img.as_object()?;
            if json_i32(img_obj, "numeric_image_id") == Some(selected_id) {
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
              "id": child.numeric_id,
              "assetsId": row.numeric_id,
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
      "id": row.numeric_id,
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
    project_id: Uuid,
    script_id: Uuid,
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
          a.numeric_id,
          a.name,
          a.asset_type,
          a.description,
          a.metadata,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'file_path', i.file_path,
                  'numeric_image_id', i.numeric_image_id,
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
        ORDER BY a.numeric_id ASC
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
                        == Some(row.numeric_id)
                })
                .collect::<Vec<_>>();
            build_production_asset_item(row, &child_rows)
        })
        .collect::<Vec<_>>();

    let storyboards = sqlx::query_as::<_, ProductionStoryboardFlowRow>(
        r#"
        SELECT
          numeric_id,
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
        ORDER BY COALESCE(sb_index, 2147483647), numeric_id
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
            let saved_storyboard = saved_storyboard_by_id.get(&row.numeric_id);
            json!({
              "id": row.numeric_id,
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
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Value, ApiError> {
    let (project_id, script_id, script_content) =
        resolve_owned_production_scope(pool, uid, project_numeric_id, script_numeric_id).await?;
    load_production_flow_json(pool, project_id, script_id, script_content).await
}
