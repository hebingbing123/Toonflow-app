use serde_json::{json, Value};
use sqlx::FromRow;
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, FromRow)]
pub(super) struct ScriptContentRow {
    pub(super) script_content: Option<String>,
}

#[derive(Debug, FromRow)]
pub(super) struct ProductionAssetFlowRow {
    #[sqlx(rename = "numeric_id")]
    pub(super) numeric_id: i32,
    pub(super) name: String,
    pub(super) asset_type: String,
    pub(super) description: Option<String>,
    pub(super) metadata: Value,
    pub(super) history_images: Value,
}

#[derive(Debug, FromRow)]
pub(super) struct ProductionStoryboardFlowRow {
    #[sqlx(rename = "numeric_id")]
    pub(super) numeric_id: i32,
    pub(super) prompt: Option<String>,
    pub(super) file_path: Option<String>,
    pub(super) duration: Option<String>,
    pub(super) state: Option<String>,
    pub(super) reason: Option<String>,
    pub(super) video_desc: Option<String>,
    pub(super) should_generate_image: Option<i32>,
    pub(super) flow_id: Option<i32>,
    pub(super) sb_index: Option<i32>,
}

pub(super) async fn fetch_script_content(
    pool: &sqlx::PgPool,
    script_id: Uuid,
) -> Result<Option<String>, ApiError> {
    let row: ScriptContentRow = sqlx::query_as(
        r#"
        SELECT content AS script_content
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.script_content)
}

pub(super) async fn fetch_saved_flow(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    script_id: Uuid,
) -> Result<(Value, Option<String>), ApiError> {
    let row = sqlx::query_as::<_, (Value, Option<String>)>(
        r#"
        SELECT flow_data, updated_at::text
        FROM app_production_flow
        WHERE project_id = $1
          AND script_id = $2
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.unwrap_or_else(|| (json!({}), None)))
}

pub(super) async fn fetch_asset_rows(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    script_id: Uuid,
) -> Result<Vec<ProductionAssetFlowRow>, ApiError> {
    sqlx::query_as::<_, ProductionAssetFlowRow>(
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn fetch_storyboard_rows(
    pool: &sqlx::PgPool,
    script_id: Uuid,
) -> Result<Vec<ProductionStoryboardFlowRow>, ApiError> {
    sqlx::query_as::<_, ProductionStoryboardFlowRow>(
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}
