//! Plan catalog loaded from `backend/data/plan_catalog.json`.

use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Deserialize)]
pub struct PlanCatalogFile {
    #[allow(dead_code)]
    pub version: u32,
    pub period_days: u32,
    pub plans: Vec<PlanCatalogEntry>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PlanCatalogEntry {
    pub plan_tier: String,
    pub display_name_zh: String,
    pub display_name_en: String,
    pub description_zh: String,
    pub description_en: String,
    pub prices: HashMap<String, PriceLabel>,
    pub alipay: Option<AlipaySku>,
    pub stripe: Option<StripeSku>,
    pub bitpay: Option<BitpaySku>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PriceLabel {
    pub amount_cents: i64,
    pub label: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AlipaySku {
    #[allow(dead_code)]
    pub product_code: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct StripeSku {
    #[serde(default)]
    pub price_id_cny: String,
    #[serde(default)]
    pub price_id_usd: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct BitpaySku {
    #[serde(default)]
    pub enabled: bool,
}

static CATALOG: std::sync::OnceLock<PlanCatalogFile> = std::sync::OnceLock::new();

pub fn catalog() -> &'static PlanCatalogFile {
    CATALOG.get_or_init(|| {
        serde_json::from_str(include_str!("../../../data/plan_catalog.json"))
            .expect("plan_catalog.json must parse")
    })
}

pub fn find_plan(plan_tier: &str) -> Option<&'static PlanCatalogEntry> {
    let tier = plan_tier.trim().to_ascii_lowercase();
    catalog()
        .plans
        .iter()
        .find(|p| p.plan_tier.eq_ignore_ascii_case(&tier))
}

pub fn plan_tier_for_stripe_price(price_id: &str) -> Option<&'static str> {
    let price_id = price_id.trim();
    if price_id.is_empty() {
        return None;
    }
    for plan in &catalog().plans {
        if let Some(stripe) = &plan.stripe {
            if stripe.price_id_cny == price_id || stripe.price_id_usd == price_id {
                return Some(plan.plan_tier.as_str());
            }
        }
    }
    None
}

pub fn purchasable_tiers() -> Vec<&'static PlanCatalogEntry> {
    catalog().plans.iter().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_loads_three_tiers() {
        assert_eq!(catalog().plans.len(), 3);
        assert!(find_plan("creator").is_some());
        assert!(find_plan("PRO").is_some());
    }
}
