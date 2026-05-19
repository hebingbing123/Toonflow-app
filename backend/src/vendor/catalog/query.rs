//! 目录过滤、查找与默认模型解析。

use crate::error::ApiError;

use super::data::CATALOG;
use super::pricing::{lookup_pricing, ModelPricingPublic};
use super::types::{
    ModelDetailResponse, ModelListEntry, VendorCatalogLookup, VendorCatalogSummary,
};

fn attach_pricing(model_id: &str, include: bool) -> (Option<String>, Option<ModelPricingPublic>) {
    if !include {
        return (None, None);
    }
    let mid = model_id.to_string();
    let pricing = lookup_pricing(&mid).map(|d| ModelPricingPublic::from_def(&mid, d));
    (Some(mid), pricing)
}

pub(super) fn normalize_filter(raw: Option<String>) -> Result<String, ApiError> {
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

pub(super) fn list_filtered(filter: &str, include_pricing: bool) -> Vec<ModelListEntry> {
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
            let composite = format!("{}:{}", v.id, m.model_name);
            let (model_id, pricing) = attach_pricing(&composite, include_pricing);
            out.push(ModelListEntry {
                id: v.id,
                label: m.name.clone(),
                value: m.model_name.clone(),
                kind: m.kind.clone(),
                name: v.name.clone(),
                model_id,
                pricing,
            });
        }
    }
    out
}

pub(super) fn lookup_detail(model_id: &str, include_pricing: bool) -> Option<ModelDetailResponse> {
    let (vid_str, model_name) = model_id.split_once(':')?;
    let vendor_id: i32 = vid_str.parse().ok()?;
    let v = CATALOG.vendors.iter().find(|x| x.id == vendor_id)?;
    let m = v.models.iter().find(|x| x.model_name == model_name)?;
    let composite = format!("{}:{}", v.id, m.model_name);
    let (_, pricing) = attach_pricing(&composite, include_pricing);
    Some(ModelDetailResponse {
        vendor_id: v.id,
        vendor_name: v.name.clone(),
        name: m.name.clone(),
        model_name: m.model_name.clone(),
        kind: m.kind.clone(),
        model_id: composite,
        pricing,
    })
}

/// First **`type: text`** model in [`CATALOG`] walk order (vendor id ascending, model order as in JSON).
pub(super) fn first_text_model_composite_id() -> String {
    for v in &CATALOG.vendors {
        for m in &v.models {
            if m.kind == "text" {
                return format!("{}:{}", v.id, m.model_name);
            }
        }
    }
    "1:gpt-4o-mini".into()
}

/// Default text model id for **`GET /api/v1/models/text-default`**. Override with **`OPENFLOW_DEFAULT_TEXT_MODEL_ID`**
/// (must match a catalog entry for **`GET /api/v1/models/detail`**).
pub(super) fn default_text_model_composite_id() -> String {
    if let Ok(raw) = std::env::var("OPENFLOW_DEFAULT_TEXT_MODEL_ID") {
        let id = raw.trim();
        if !id.is_empty() && lookup_detail(id, false).is_some() {
            return id.to_string();
        }
    }
    first_text_model_composite_id()
}
