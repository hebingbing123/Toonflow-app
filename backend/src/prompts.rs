//! User prompt templates (parity with legacy SQLite **`o_prompt`** and **`/api/setting/promptManage/getPrompt`** / **`updatePrompt`**).

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::{get, patch},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Clone, Copy)]
struct DefaultSlot {
    legacy_id: i32,
    name: &'static str,
    kind: &'static str,
    body: &'static str,
}

const DEFAULT_SLOTS: [DefaultSlot; 3] = [
    DefaultSlot {
        legacy_id: 1,
        name: "事件提取",
        kind: "eventExtraction",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/eventExtraction.txt"
        )),
    },
    DefaultSlot {
        legacy_id: 2,
        name: "剧本资产提取",
        kind: "scriptAssetExtraction",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/scriptAssetExtraction.txt"
        )),
    },
    DefaultSlot {
        legacy_id: 3,
        name: "视频提示词生成",
        kind: "videoPromptGeneration",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/videoPromptGeneration.txt"
        )),
    },
];

#[derive(Debug, FromRow)]
struct UserPromptRow {
    legacy_id: i32,
    name: Option<String>,
    kind: String,
    body: String,
}

/// JSON shape aligned with legacy **`getPrompt`** rows (`id`, `name`, `type`, `data`).
#[derive(Debug, Serialize)]
pub struct PromptTemplateJson {
    pub id: i32,
    pub name: String,
    #[serde(rename = "type")]
    pub prompt_type: String,
    pub data: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PatchPromptBody {
    pub data: String,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/prompts", get(list_prompts))
        .route("/api/v1/prompts/{legacy_id}", patch(patch_prompt))
}

fn slot_by_legacy_id(id: i32) -> Option<&'static DefaultSlot> {
    DEFAULT_SLOTS.iter().find(|s| s.legacy_id == id)
}

async fn list_prompts(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<PromptTemplateJson>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<UserPromptRow> = sqlx::query_as(
        r#"
        SELECT legacy_id, name, kind, body
        FROM app_user_prompt
        WHERE owner_user_id = $1
        ORDER BY legacy_id
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(DEFAULT_SLOTS.len());
    for def in &DEFAULT_SLOTS {
        let merged = rows.iter().find(|r| r.legacy_id == def.legacy_id);
        let name = merged
            .and_then(|r| r.name.as_deref())
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(def.name)
            .to_string();
        let prompt_type = merged
            .map(|r| r.kind.as_str())
            .unwrap_or(def.kind)
            .to_string();
        let data = merged
            .map(|r| r.body.as_str())
            .unwrap_or(def.body)
            .to_string();
        out.push(PromptTemplateJson {
            id: def.legacy_id,
            name,
            prompt_type,
            data,
        });
    }

    Ok(Json(out))
}

async fn patch_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(legacy_id): Path<i32>,
    Json(body): Json<PatchPromptBody>,
) -> Result<Json<PromptTemplateJson>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let def = slot_by_legacy_id(legacy_id).ok_or(ApiError::NotFound)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    sqlx::query(
        r#"
        INSERT INTO app_user_prompt (owner_user_id, legacy_id, name, kind, body, updated_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        ON CONFLICT (owner_user_id, legacy_id) DO UPDATE SET
          body = EXCLUDED.body,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(def.legacy_id)
    .bind(def.name)
    .bind(def.kind)
    .bind(&body.data)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(PromptTemplateJson {
        id: def.legacy_id,
        name: def.name.to_string(),
        prompt_type: def.kind.to_string(),
        data: body.data,
    }))
}
