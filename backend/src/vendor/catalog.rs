//! 静态模型/提供商目录（编译时 JSON）。
//!
//! 与遗留 `modelSelect/getModelList` 兼容，无需 Postgres `o_vendorConfig` 即可过滤。

use std::sync::LazyLock;

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct PatchTextModelDefaultBody {
    /// Composite id `{vendor_id}:{model_name}` — must exist in the catalog.
    /// Pass `null` to reset to server default.
    model_id: Option<String>,
}

#[derive(Debug, Deserialize)]
struct CatalogFile {
    vendors: Vec<VendorDef>,
}

#[derive(Debug, Deserialize)]
struct VendorDef {
    id: i32,
    name: String,
    models: Vec<ModelDef>,
}

#[derive(Debug, Deserialize, Clone)]
struct ModelDef {
    name: String,
    model_name: String,
    #[serde(rename = "type")]
    kind: String,
}

static CATALOG: LazyLock<CatalogFile> = LazyLock::new(|| {
    serde_json::from_str(include_str!("../../data/models_catalog.json"))
        .expect("models_catalog.json must be valid JSON")
});

#[derive(Debug, Serialize)]
pub(crate) struct ModelListEntry {
    /// Vendor id (Electron-era `o_vendorConfig.id` analogue).
    id: i32,
    label: String,
    value: String,
    #[serde(rename = "type")]
    kind: String,
    /// Vendor display name.
    name: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct ModelDetailResponse {
    vendor_id: i32,
    vendor_name: String,
    name: String,
    model_name: String,
    #[serde(rename = "type")]
    kind: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ListQuery {
    /// One of `text`, `image`, `video`, `all`. When omitted, treated as `all`.
    /// `all` excludes `video` entries (Electron-era `getModelList` behaviour).
    #[serde(default, rename = "type")]
    filter: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DetailQuery {
    /// Composite id: `{vendor_id}:{model_name}` (e.g. `1:gpt-4o-mini`).
    model_id: String,
}

fn normalize_filter(raw: Option<String>) -> Result<String, ApiError> {
    let s = raw
        .map(|s| s.trim().to_ascii_lowercase())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "all".into());
    match s.as_str() {
        "text" | "image" | "video" | "all" => Ok(s),
        _ => Err(ApiError::BadRequest(
            "query parameter type must be text, image, video, or all".into(),
        )),
    }
}

/// One vendor row for **`GET /api/v1/settings/vendors/summary`** (no API keys; not **`o_vendorConfig`**).
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct VendorCatalogSummary {
    pub(crate) id: i32,
    pub(crate) name: String,
    pub(crate) model_count: usize,
    /// Sorted unique **`type`** values from embedded catalog models.
    pub(crate) model_kinds: Vec<String>,
}

#[derive(Debug, Clone)]
pub(crate) struct VendorCatalogLookup {
    pub(crate) numeric_id: i32,
    pub(crate) name: String,
    pub(crate) slug: String,
}

fn vendor_slug(name: &str) -> String {
    let mut out = String::with_capacity(name.len());
    let mut prev_dash = false;
    for ch in name.chars() {
        let next = if ch.is_ascii_alphanumeric() {
            prev_dash = false;
            ch.to_ascii_lowercase()
        } else {
            if prev_dash {
                continue;
            }
            prev_dash = true;
            '-'
        };
        out.push(next);
    }
    out.trim_matches('-').to_string()
}

pub(crate) fn vendor_catalog_summaries() -> Vec<VendorCatalogSummary> {
    let mut out = Vec::with_capacity(CATALOG.vendors.len());
    for v in &CATALOG.vendors {
        let mut kinds: Vec<String> = v.models.iter().map(|m| m.kind.clone()).collect();
        kinds.sort();
        kinds.dedup();
        out.push(VendorCatalogSummary {
            id: v.id,
            name: v.name.clone(),
            model_count: v.models.len(),
            model_kinds: kinds,
        });
    }
    out
}

pub(crate) fn lookup_vendor_catalog(raw: &str) -> Option<VendorCatalogLookup> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }

    if let Ok(numeric_id) = trimmed.parse::<i32>() {
        if let Some(v) = CATALOG.vendors.iter().find(|v| v.id == numeric_id) {
            return Some(VendorCatalogLookup {
                numeric_id: v.id,
                name: v.name.clone(),
                slug: vendor_slug(&v.name),
            });
        }
    }

    let normalized = vendor_slug(trimmed);
    if normalized.is_empty() {
        return None;
    }

    CATALOG
        .vendors
        .iter()
        .find(|v| vendor_slug(&v.name) == normalized)
        .map(|v| VendorCatalogLookup {
            numeric_id: v.id,
            name: v.name.clone(),
            slug: vendor_slug(&v.name),
        })
}

fn list_filtered(filter: &str) -> Vec<ModelListEntry> {
    let mut out = Vec::new();
    for v in &CATALOG.vendors {
        for m in &v.models {
            let include = match filter {
                "all" => m.kind != "video",
                other => m.kind == other,
            };
            if !include {
                continue;
            }
            out.push(ModelListEntry {
                id: v.id,
                label: m.name.clone(),
                value: m.model_name.clone(),
                kind: m.kind.clone(),
                name: v.name.clone(),
            });
        }
    }
    out
}

fn lookup_detail(model_id: &str) -> Option<ModelDetailResponse> {
    let (vid_str, model_name) = model_id.split_once(':')?;
    let vendor_id: i32 = vid_str.parse().ok()?;
    let v = CATALOG.vendors.iter().find(|x| x.id == vendor_id)?;
    let m = v.models.iter().find(|x| x.model_name == model_name)?;
    Some(ModelDetailResponse {
        vendor_id: v.id,
        vendor_name: v.name.clone(),
        name: m.name.clone(),
        model_name: m.model_name.clone(),
        kind: m.kind.clone(),
    })
}

/// First **`type: text`** model in [`CATALOG`] walk order (vendor id ascending, model order as in JSON).
fn first_text_model_composite_id() -> String {
    for v in &CATALOG.vendors {
        for m in &v.models {
            if m.kind == "text" {
                return format!("{}:{}", v.id, m.model_name);
            }
        }
    }
    "1:gpt-4o-mini".into()
}

/// Default text model id for **`GET /api/v1/models/text-default`**. Override with **`TOONFLOW_DEFAULT_TEXT_MODEL_ID`**
/// (must match a catalog entry for **`GET /api/v1/models/detail`**).
fn default_text_model_composite_id() -> String {
    if let Ok(raw) = std::env::var("TOONFLOW_DEFAULT_TEXT_MODEL_ID") {
        let id = raw.trim();
        if !id.is_empty() && lookup_detail(id).is_some() {
            return id.to_string();
        }
    }
    first_text_model_composite_id()
}

#[derive(Debug, Serialize)]
pub(crate) struct TextModelDefaultResponse {
    /// Historical **`POST /api/setting/getTextModel`** returned this string as envelope **`data`** (stub).
    stub_placeholder: &'static str,
    /// Composite id for **`GET /api/v1/models/detail?model_id=`**.
    default_model_id: String,
}

#[utoipa::path(
    get,
    path = "/api/v1/models/text-default",
    operation_id = "getTextModelDefaultV1",
    tag = "models",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn text_model_default(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<TextModelDefaultResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Try to load per-user preference from DB.
    let user_pref: Option<String> = if let Some(pool) = state.pool.as_ref() {
        sqlx::query_scalar(
            r#"SELECT preferred_text_model_id FROM app_user_profile WHERE user_id = $1"#,
        )
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .flatten()
    } else {
        None
    };

    // Validate the stored preference is still in the catalog; fall back to server default if not.
    let default_model_id = user_pref
        .as_deref()
        .filter(|id| lookup_detail(id).is_some())
        .map(str::to_string)
        .unwrap_or_else(default_text_model_composite_id);

    Ok(Json(TextModelDefaultResponse {
        stub_placeholder: "123",
        default_model_id,
    }))
}

#[utoipa::path(
    patch,
    path = "/api/v1/models/text-default",
    operation_id = "patchTextModelDefaultV1",
    tag = "models",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_text_model_default(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PatchTextModelDefaultBody>,
) -> Result<Json<TextModelDefaultResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Validate model_id BEFORE touching the pool so bad requests get 400 even without DB.
    if let Some(ref id) = body.model_id {
        let id = id.trim();
        if id.is_empty() {
            return Err(ApiError::BadRequest(
                "model_id must be non-empty or null to reset".into(),
            ));
        }
        if lookup_detail(id).is_none() {
            return Err(ApiError::BadRequest(format!(
                "model_id '{id}' not found in catalog; use GET /api/v1/models/detail to verify"
            )));
        }
    }

    let pool = state.require_pool()?;

    let model_id_to_store = body.model_id.as_deref().map(str::trim).map(str::to_string);

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, preferred_text_model_id, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          preferred_text_model_id = EXCLUDED.preferred_text_model_id,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(model_id_to_store.as_deref())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let default_model_id = model_id_to_store
        .as_deref()
        .filter(|id| lookup_detail(id).is_some())
        .map(str::to_string)
        .unwrap_or_else(default_text_model_composite_id);

    Ok(Json(TextModelDefaultResponse {
        stub_placeholder: "123",
        default_model_id,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/models",
    operation_id = "listModelsV1",
    tag = "models",
    params(
        ("type" = Option<String>, Query, description = "Filter: text, image, video, or all (default all)")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_models(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListQuery>,
) -> Result<Json<Vec<ModelListEntry>>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    let filter = normalize_filter(q.filter)?;
    Ok(Json(list_filtered(&filter)))
}

#[utoipa::path(
    get,
    path = "/api/v1/models/detail",
    operation_id = "modelDetailV1",
    tag = "models",
    params(
        ("model_id" = String, Query, description = "Composite id `{vendor_id}:{model_name}`")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn model_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<DetailQuery>,
) -> Result<Json<ModelDetailResponse>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    if q.model_id.trim().is_empty() {
        return Err(ApiError::BadRequest("model_id is required".into()));
    }
    lookup_detail(q.model_id.trim())
        .map(Json)
        .ok_or(ApiError::NotFound)
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/models", get(list_models))
        .route(
            "/api/v1/models/text-default",
            get(text_model_default).patch(patch_text_model_default),
        )
        .route("/api/v1/models/detail", get(model_detail))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_excludes_video() {
        let n = list_filtered("all")
            .iter()
            .filter(|e| e.kind == "video")
            .count();
        assert_eq!(n, 0);
    }

    #[test]
    fn detail_round_trip() {
        let d = lookup_detail("1:gpt-4o-mini").expect("detail");
        assert_eq!(d.model_name, "gpt-4o-mini");
        assert_eq!(d.kind, "text");
    }

    #[test]
    fn first_text_model_is_gpt4o_mini() {
        assert_eq!(super::first_text_model_composite_id(), "1:gpt-4o-mini");
    }

    #[test]
    fn vendor_catalog_summaries_non_empty() {
        let s = super::vendor_catalog_summaries();
        assert!(!s.is_empty());
        let openai = s.iter().find(|v| v.id == 1).expect("vendor 1");
        assert!(!openai.name.is_empty());
        assert!(openai.model_count > 0);
        assert!(!openai.model_kinds.is_empty());
    }

    #[test]
    fn patch_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchTextModelDefaultBody>(r#"{"model_id":"1:x","extra":1}"#)
                .unwrap_err();
        assert!(
            err.to_string().contains("unknown field"),
            "expected unknown field error, got: {err}"
        );
    }

    #[test]
    fn patch_body_accepts_null_model_id() {
        let b: PatchTextModelDefaultBody =
            serde_json::from_str(r#"{"model_id":null}"#).expect("parse");
        assert!(b.model_id.is_none());
    }

    #[test]
    fn patch_body_accepts_valid_model_id() {
        let b: PatchTextModelDefaultBody =
            serde_json::from_str(r#"{"model_id":"1:gpt-4o-mini"}"#).expect("parse");
        assert_eq!(b.model_id.as_deref(), Some("1:gpt-4o-mini"));
    }
}
