//! 用户提示词模板（与遗留 SQLite `o_prompt` 和 `/api/setting/promptManage/getPrompt` / `updatePrompt` 兼容）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
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
        .route(
            "/api/v1/prompts/{legacy_id}",
            get(get_prompt).patch(patch_prompt),
        )
}

fn slot_by_legacy_id(id: i32) -> Option<&'static DefaultSlot> {
    DEFAULT_SLOTS.iter().find(|s| s.legacy_id == id)
}

fn merge_slot(def: &'static DefaultSlot, row: Option<&UserPromptRow>) -> PromptTemplateJson {
    let name = row
        .and_then(|r| r.name.as_deref())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(def.name)
        .to_string();
    let prompt_type = row.map(|r| r.kind.as_str()).unwrap_or(def.kind).to_string();
    let data = row.map(|r| r.body.as_str()).unwrap_or(def.body).to_string();
    PromptTemplateJson {
        id: def.legacy_id,
        name,
        prompt_type,
        data,
    }
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
        out.push(merge_slot(def, merged));
    }

    Ok(Json(out))
}

async fn get_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(legacy_id): Path<i32>,
) -> Result<Json<PromptTemplateJson>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let def = slot_by_legacy_id(legacy_id).ok_or(ApiError::NotFound)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row: Option<UserPromptRow> = sqlx::query_as(
        r#"
        SELECT legacy_id, name, kind, body
        FROM app_user_prompt
        WHERE owner_user_id = $1 AND legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(merge_slot(def, row.as_ref())))
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_prompt_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<PatchPromptBody>(r#"{"data":"x","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn patch_prompt_body_accepts_valid() {
        let b: PatchPromptBody = serde_json::from_str(r#"{"data":"test prompt"}"#).unwrap();
        assert_eq!(b.data, "test prompt");
    }

    #[test]
    fn default_slots_have_unique_legacy_ids() {
        let mut ids: Vec<i32> = DEFAULT_SLOTS.iter().map(|s| s.legacy_id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), DEFAULT_SLOTS.len());
    }

    #[test]
    fn slot_by_legacy_id_finds_existing() {
        assert!(slot_by_legacy_id(1).is_some());
        assert!(slot_by_legacy_id(2).is_some());
        assert!(slot_by_legacy_id(3).is_some());
    }

    #[test]
    fn slot_by_legacy_id_returns_none_for_invalid() {
        assert!(slot_by_legacy_id(999).is_none());
    }

    #[test]
    fn merge_slot_uses_defaults_when_no_row() {
        let def = &DEFAULT_SLOTS[0];
        let merged = merge_slot(def, None);
        assert_eq!(merged.id, def.legacy_id);
        assert_eq!(merged.name, def.name);
        assert_eq!(merged.prompt_type, def.kind);
        assert_eq!(merged.data, def.body);
    }

    #[test]
    fn merge_slot_uses_row_values_when_present() {
        let def = &DEFAULT_SLOTS[0];
        let row = UserPromptRow {
            legacy_id: def.legacy_id,
            name: Some("Custom Name".to_string()),
            kind: "customKind".to_string(),
            body: "custom body".to_string(),
        };
        let merged = merge_slot(def, Some(&row));
        assert_eq!(merged.id, def.legacy_id);
        assert_eq!(merged.name, "Custom Name");
        assert_eq!(merged.prompt_type, "customKind");
        assert_eq!(merged.data, "custom body");
    }

    #[test]
    fn merge_slot_uses_default_name_when_row_name_empty() {
        let def = &DEFAULT_SLOTS[0];
        let row = UserPromptRow {
            legacy_id: def.legacy_id,
            name: Some("   ".to_string()),
            kind: "customKind".to_string(),
            body: "custom body".to_string(),
        };
        let merged = merge_slot(def, Some(&row));
        assert_eq!(merged.name, def.name);
    }
}
