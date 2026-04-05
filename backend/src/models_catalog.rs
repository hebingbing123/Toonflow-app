//! Static model/vendor catalog (compile-time JSON). Parity with legacy `modelSelect/getModelList`
//! filtering without Postgres `o_vendorConfig`.

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
    serde_json::from_str(include_str!("../data/models_catalog.json"))
        .expect("models_catalog.json must be valid JSON")
});

#[derive(Debug, Serialize)]
struct ModelListEntry {
    /// Vendor id (legacy `o_vendorConfig.id` analogue).
    id: i32,
    label: String,
    value: String,
    #[serde(rename = "type")]
    kind: String,
    /// Vendor display name.
    name: String,
}

#[derive(Debug, Serialize)]
struct ModelDetailResponse {
    vendor_id: i32,
    vendor_name: String,
    name: String,
    model_name: String,
    #[serde(rename = "type")]
    kind: String,
}

#[derive(Debug, Deserialize)]
struct ListQuery {
    /// One of `text`, `image`, `video`, `all`. When omitted, treated as `all`.
    /// `all` excludes `video` entries (legacy `getModelList` behaviour).
    #[serde(default, rename = "type")]
    filter: Option<String>,
}

#[derive(Debug, Deserialize)]
struct DetailQuery {
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
struct TextModelDefaultResponse {
    /// Legacy **`POST /api/setting/getTextModel`** returned this string as envelope **`data`** (stub).
    legacy_placeholder: &'static str,
    /// Composite id for **`GET /api/v1/models/detail?model_id=`**.
    default_model_id: String,
}

async fn text_model_default(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<TextModelDefaultResponse>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    Ok(Json(TextModelDefaultResponse {
        legacy_placeholder: "123",
        default_model_id: default_text_model_composite_id(),
    }))
}

async fn list_models(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListQuery>,
) -> Result<Json<Vec<ModelListEntry>>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    let filter = normalize_filter(q.filter)?;
    Ok(Json(list_filtered(&filter)))
}

async fn model_detail(
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
        .route("/api/v1/models/text-default", get(text_model_default))
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
}
