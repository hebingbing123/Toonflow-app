//! Stripe Checkout Session + Customer Portal.

use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use super::catalog::{find_plan, plan_tier_for_stripe_price};
use super::session::{
    insert_session, set_billing_customer_id, set_provider_session_id, NewCheckoutSession,
};
use crate::error::ApiError;

pub struct StripeConfig {
    pub secret_key: String,
    pub success_url: String,
    pub cancel_url: String,
}

impl StripeConfig {
    pub fn from_env() -> Option<Self> {
        let secret_key = std::env::var("STRIPE_SECRET_KEY").ok()?;
        if secret_key.trim().is_empty() {
            return None;
        }
        Some(Self {
            secret_key,
            success_url: std::env::var("STRIPE_CHECKOUT_SUCCESS_URL")
                .unwrap_or_else(|_| "https://openflow.local/billing/success".into()),
            cancel_url: std::env::var("STRIPE_CHECKOUT_CANCEL_URL")
                .unwrap_or_else(|_| "https://openflow.local/billing/cancel".into()),
        })
    }
}

#[derive(Debug, Deserialize)]
struct StripeCheckoutSessionResponse {
    id: String,
    url: Option<String>,
    customer: Option<String>,
}

pub async fn create_checkout(
    cfg: &StripeConfig,
    pool: &sqlx::PgPool,
    user_id: Uuid,
    plan_tier: &str,
    currency: &str,
) -> Result<(Uuid, String), ApiError> {
    let plan = find_plan(plan_tier).ok_or(ApiError::NotFound)?;
    let stripe = plan.stripe.as_ref().ok_or(ApiError::NotFound)?;
    let price_id = match currency.to_ascii_uppercase().as_str() {
        "USD" => stripe.price_id_usd.as_str(),
        _ => stripe.price_id_cny.as_str(),
    };
    if price_id.trim().is_empty() {
        return Err(ApiError::NotImplemented(
            "Stripe price_id not configured for this plan".into(),
        ));
    }
    let price = plan
        .prices
        .get(&currency.to_ascii_uppercase())
        .or_else(|| plan.prices.get("CNY"))
        .ok_or(ApiError::NotFound)?;
    let out_trade_no = format!("of-stripe-{}", Uuid::new_v4());
    let currency_upper = currency.to_ascii_uppercase();
    let row = insert_session(
        pool,
        NewCheckoutSession {
            user_id,
            plan_tier: &plan.plan_tier,
            provider: "stripe",
            currency: &currency_upper,
            amount_cents: price.amount_cents,
            period_days: super::catalog::catalog().period_days as i32,
            provider_trade_no: &out_trade_no,
            pay_url: None,
            provider_session_id: None,
            ttl_hours: 24,
        },
    )
    .await?;

    let client = reqwest::Client::new();
    let form = [
        ("mode", "subscription"),
        ("client_reference_id", &row.id.to_string()),
        ("success_url", &cfg.success_url),
        ("cancel_url", &cfg.cancel_url),
        ("line_items[0][price]", price_id),
        ("line_items[0][quantity]", "1"),
        ("metadata[checkout_session_id]", &row.id.to_string()),
        ("metadata[plan_tier]", &plan.plan_tier),
        ("metadata[user_id]", &user_id.to_string()),
    ];
    let resp = client
        .post("https://api.stripe.com/v1/checkout/sessions")
        .basic_auth(&cfg.secret_key, Some(""))
        .form(&form)
        .send()
        .await
        .map_err(|e| {
            tracing::error!(error = %e, "stripe checkout request failed");
            ApiError::Internal
        })?;
    if !resp.status().is_success() {
        let body = resp.text().await.unwrap_or_default();
        tracing::error!(body = %body, "stripe checkout error response");
        return Err(ApiError::Internal);
    }
    let session: StripeCheckoutSessionResponse = resp.json().await.map_err(|e| {
        tracing::error!(error = %e, "stripe checkout json parse failed");
        ApiError::Internal
    })?;
    let pay_url = session.url.ok_or(ApiError::Internal)?;
    set_provider_session_id(pool, row.id, &session.id, Some(&pay_url)).await?;
    if let Some(cus) = session.customer.as_deref() {
        let _ = set_billing_customer_id(pool, user_id, "stripe", cus).await;
    }
    Ok((row.id, pay_url))
}

pub async fn create_portal(
    cfg: &StripeConfig,
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<String, ApiError> {
    let customer_id: Option<String> = sqlx::query_scalar(
        r#"SELECT billing_customer_id FROM app_user_profile WHERE user_id = $1"#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();
    let customer_id = customer_id
        .filter(|s| !s.is_empty())
        .ok_or(ApiError::NotFound)?;

    let return_url =
        std::env::var("STRIPE_PORTAL_RETURN_URL").unwrap_or_else(|_| cfg.success_url.clone());
    let client = reqwest::Client::new();
    let form = [
        ("customer", customer_id.as_str()),
        ("return_url", return_url.as_str()),
    ];
    let resp = client
        .post("https://api.stripe.com/v1/billing_portal/sessions")
        .basic_auth(&cfg.secret_key, Some(""))
        .form(&form)
        .send()
        .await
        .map_err(|e| {
            tracing::error!(error = %e, "stripe portal request failed");
            ApiError::Internal
        })?;
    if !resp.status().is_success() {
        let body = resp.text().await.unwrap_or_default();
        tracing::error!(body = %body, "stripe portal error response");
        return Err(ApiError::Internal);
    }
    #[derive(Deserialize)]
    struct PortalResp {
        url: String,
    }
    let portal: PortalResp = resp.json().await.map_err(|e| {
        tracing::error!(error = %e, "stripe portal json parse failed");
        ApiError::Internal
    })?;
    Ok(portal.url)
}

pub fn enrich_stripe_webhook_payload(v: &mut serde_json::Value) {
    if v.get("plan_tier")
        .and_then(serde_json::Value::as_str)
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false)
    {
        return;
    }
    let price_id = v
        .pointer("/data/object/lines/data/0/price/id")
        .or_else(|| v.pointer("/data/object/items/data/0/price/id"))
        .or_else(|| v.pointer("/data/object/plan/id"))
        .and_then(serde_json::Value::as_str);
    if let Some(price_id) = price_id {
        if let Some(tier) = plan_tier_for_stripe_price(price_id) {
            if let Some(obj) = v.as_object_mut() {
                obj.insert("plan_tier".to_string(), json!(tier));
            }
        }
    }
    let user_id = v
        .pointer("/data/object/metadata/user_id")
        .and_then(serde_json::Value::as_str)
        .map(str::to_string);
    let client_ref = v
        .pointer("/data/object/client_reference_id")
        .and_then(serde_json::Value::as_str)
        .map(str::to_string);
    if v.get("user_id")
        .and_then(serde_json::Value::as_str)
        .map(|s| s.is_empty())
        .unwrap_or(true)
    {
        if let Some(obj) = v.as_object_mut() {
            if let Some(uid) = user_id {
                obj.insert("user_id".to_string(), json!(uid));
            } else if let Some(ref_id) = client_ref {
                obj.insert("checkout_session_id".to_string(), json!(ref_id));
            }
        }
    }
}
