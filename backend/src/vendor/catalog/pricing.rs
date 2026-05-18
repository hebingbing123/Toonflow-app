//! Static model pricing (`model_pricing.json`) — estimates and enriched catalog fields.

use std::collections::HashMap;
use std::sync::LazyLock;

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use super::query::lookup_detail;
use crate::error::ApiError;

#[derive(Debug, Deserialize)]
pub(in crate::vendor::catalog) struct PricingFile {
    pub(in crate::vendor::catalog) disclaimer: String,
    pub(in crate::vendor::catalog) task_defaults: HashMap<String, TaskDefaultDef>,
    pub(in crate::vendor::catalog) models: HashMap<String, ModelPricingDef>,
}

#[derive(Debug, Deserialize)]
pub(in crate::vendor::catalog) struct TaskDefaultDef {
    pub(in crate::vendor::catalog) default_quantity: u32,
    #[allow(dead_code)]
    pub(in crate::vendor::catalog) default_unit: String,
    #[serde(default)]
    pub(in crate::vendor::catalog) jobs_per_submit: u32,
}

#[derive(Debug, Deserialize, Clone)]
pub(crate) struct ModelPricingDef {
    pub(crate) pricing_unit: String,
    pub(crate) credits_per_unit: u64,
    pub(crate) cny_cents_per_unit: u64,
    pub(crate) tier: String,
    pub(crate) value_tier: String,
    pub(crate) best_for: String,
}

pub(in crate::vendor::catalog) static PRICING: LazyLock<PricingFile> = LazyLock::new(|| {
    serde_json::from_str(include_str!("../../../data/model_pricing.json"))
        .expect("model_pricing.json must be valid JSON")
});

/// Public pricing slice attached to model list/detail when `include_pricing=true`.
#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct ModelPricingPublic {
    pub model_id: String,
    pub pricing_unit: String,
    pub credits_per_unit: u64,
    pub cny_cents_per_unit: u64,
    pub tier: String,
    pub value_tier: String,
    pub best_for: String,
    pub disclaimer: String,
}

impl ModelPricingPublic {
    pub fn from_def(model_id: &str, def: &ModelPricingDef) -> Self {
        Self {
            model_id: model_id.to_string(),
            pricing_unit: def.pricing_unit.clone(),
            credits_per_unit: def.credits_per_unit,
            cny_cents_per_unit: def.cny_cents_per_unit,
            tier: def.tier.clone(),
            value_tier: def.value_tier.clone(),
            best_for: def.best_for.clone(),
            disclaimer: PRICING.disclaimer.clone(),
        }
    }
}

pub fn lookup_pricing(model_id: &str) -> Option<&ModelPricingDef> {
    PRICING.models.get(model_id.trim())
}

pub fn pricing_disclaimer() -> &'static str {
    &PRICING.disclaimer
}

pub fn compute_line_cost(def: &ModelPricingDef, quantity: u64) -> (u64, u64) {
    let q = quantity.max(1);
    (
        def.credits_per_unit.saturating_mul(q),
        def.cny_cents_per_unit.saturating_mul(q),
    )
}

/// Estimate token-block cost from total tokens (best-effort for `app_llm_usage_log`).
pub fn estimate_cost_cents_for_tokens(model_name: &str, total_tokens: i64) -> Option<i32> {
    let composite = find_composite_id_by_model_name(model_name)?;
    let def = lookup_pricing(&composite)?;
    if def.pricing_unit != "per_1k_tokens" {
        return None;
    }
    let blocks = (total_tokens.max(0) as u64).div_ceil(1000);
    let (_, cny) = compute_line_cost(def, blocks.max(1));
    i32::try_from(cny.min(i64::from(i32::MAX) as u64)).ok()
}

pub(crate) fn composite_id_for_model_name(model_name: &str) -> Option<String> {
    find_composite_id_by_model_name(model_name)
}

fn find_composite_id_by_model_name(model_name: &str) -> Option<String> {
    use super::data::CATALOG;
    let name = model_name.trim();
    for v in &CATALOG.vendors {
        for m in &v.models {
            if m.model_name == name {
                return Some(format!("{}:{}", v.id, m.model_name));
            }
        }
    }
    None
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
pub struct BillingEstimateRequest {
    pub model_id: String,
    pub task_kind: String,
    #[serde(default = "default_quantity_one")]
    pub quantity: u32,
}

fn default_quantity_one() -> u32 {
    1
}

#[derive(Debug, Serialize, ToSchema)]
pub struct BillingEstimateResponse {
    pub model_id: String,
    pub task_kind: String,
    pub quantity: u32,
    pub pricing_unit: String,
    pub credits: u64,
    pub cny_cents: u64,
    pub quota_impact_jobs: u32,
    pub warnings: Vec<String>,
    /// When true, user BYOK credential is active — platform estimate is reference only.
    #[serde(default)]
    pub platform_billing_exempt: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jobs_today: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub daily_job_quota: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub quota_remaining: Option<i64>,
    /// Projected daily quota usage % after this submit (`jobs_today + quota_impact` / quota).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub quota_usage_percent_after: Option<f64>,
}

pub fn build_estimate(body: &BillingEstimateRequest) -> Result<BillingEstimateResponse, ApiError> {
    let model_id = body.model_id.trim();
    if model_id.is_empty() {
        return Err(ApiError::BadRequest("model_id is required".into()));
    }
    if lookup_detail(model_id, false).is_none() {
        return Err(ApiError::NotFound);
    }
    let pricing = lookup_pricing(model_id)
        .ok_or_else(|| ApiError::BadRequest(format!("no pricing for model_id {}", model_id)))?;

    let task_kind = body.task_kind.trim();
    if task_kind.is_empty() {
        return Err(ApiError::BadRequest("task_kind is required".into()));
    }

    let task_def = PRICING.task_defaults.get(task_kind);
    let quantity = if body.quantity == 0 {
        task_def.map(|t| t.default_quantity).unwrap_or(1)
    } else {
        body.quantity
    };
    let qty_u64 = u64::from(quantity);
    let (credits, cny_cents) = compute_line_cost(pricing, qty_u64);
    let quota_impact_jobs = task_def.map(|t| t.jobs_per_submit).unwrap_or(1);

    let mut warnings = vec!["estimate_only".to_string(), PRICING.disclaimer.clone()];
    if quota_impact_jobs > 0 {
        warnings.push("counts_toward_daily_job_quota".to_string());
    }

    Ok(BillingEstimateResponse {
        model_id: model_id.to_string(),
        task_kind: task_kind.to_string(),
        quantity,
        pricing_unit: pricing.pricing_unit.clone(),
        credits,
        cny_cents,
        quota_impact_jobs,
        warnings,
        platform_billing_exempt: false,
        jobs_today: None,
        daily_job_quota: None,
        quota_remaining: None,
        quota_usage_percent_after: None,
    })
}

/// Vendor id prefix from composite model id (`{vendor_id}:{model_name}`).
pub fn vendor_id_from_model_id(model_id: &str) -> Option<String> {
    let (vid, _) = model_id.split_once(':')?;
    if vid.trim().is_empty() {
        return None;
    }
    Some(vid.to_string())
}

/// Build billing metadata for `app_usage_event` from a generation job payload.
pub fn billing_meta_from_job_payload(
    payload: &serde_json::Value,
    task_kind_hint: &str,
) -> crate::metering::usage::JobUsageBillingMeta {
    use crate::metering::usage::JobUsageBillingMeta;

    let model_name = payload
        .get("model")
        .or_else(|| payload.get("model_name"))
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let model_id = payload
        .get("model_id")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| model_name.and_then(composite_id_for_model_name));

    let quantity = payload
        .get("duration")
        .or_else(|| payload.get("quantity"))
        .and_then(|v| v.as_u64())
        .map(|n| n.max(1) as u32)
        .or_else(|| {
            PRICING
                .task_defaults
                .get(task_kind_hint)
                .map(|t| t.default_quantity)
        })
        .unwrap_or(1);

    let credits_charged = model_id
        .as_ref()
        .and_then(|id| lookup_pricing(id))
        .map(|p| compute_line_cost(p, u64::from(quantity)).0);

    JobUsageBillingMeta {
        model_id,
        credits_charged,
    }
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ModelSpendRow {
    pub model_name: String,
    pub model_id: Option<String>,
    pub total_tokens: i64,
    pub estimated_cost_cents: i64,
    pub call_count: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avg_quality_score: Option<f64>,
    pub value_tier: Option<String>,
    pub sample_sufficient: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token_efficiency_roi_band: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token_efficiency_sample_count: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct BillingSpendSummaryResponse {
    pub days: u32,
    pub disclaimer: String,
    pub rows: Vec<ModelSpendRow>,
}
