//! BitPay invoice creation (fixed-period authorization, non-recurring MVP).

use serde::Deserialize;
use uuid::Uuid;

use super::catalog::find_plan;
use super::session::{insert_session, set_provider_session_id, NewCheckoutSession};
use crate::error::ApiError;

pub struct BitpayConfig {
    pub api_token: String,
    pub notification_url: String,
    pub sandbox: bool,
}

impl BitpayConfig {
    pub fn from_env() -> Option<Self> {
        let api_token = std::env::var("BITPAY_API_TOKEN").ok()?;
        if api_token.trim().is_empty() {
            return None;
        }
        let notification_url = std::env::var("BITPAY_NOTIFICATION_URL").ok()?;
        let sandbox = std::env::var("BITPAY_SANDBOX")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);
        Some(Self {
            api_token,
            notification_url,
            sandbox,
        })
    }

    fn base_url(&self) -> &'static str {
        if self.sandbox {
            "https://test.bitpay.com"
        } else {
            "https://bitpay.com"
        }
    }
}

#[derive(Debug, Deserialize)]
struct BitpayInvoiceResponse {
    data: BitpayInvoiceData,
}

#[derive(Debug, Deserialize)]
struct BitpayInvoiceData {
    id: String,
    url: String,
}

pub async fn create_invoice(
    cfg: &BitpayConfig,
    pool: &sqlx::PgPool,
    user_id: Uuid,
    plan_tier: &str,
    _currency: &str,
) -> Result<(Uuid, String), ApiError> {
    let plan = find_plan(plan_tier).ok_or(ApiError::NotFound)?;
    if !plan.bitpay.as_ref().map(|b| b.enabled).unwrap_or(false) {
        return Err(ApiError::NotFound);
    }
    let price = plan.prices.get("USD").ok_or(ApiError::NotFound)?;
    let amount = format!("{:.2}", price.amount_cents as f64 / 100.0);
    let out_trade_no = format!("of-bitpay-{}", Uuid::new_v4());
    let row = insert_session(
        pool,
        NewCheckoutSession {
            user_id,
            plan_tier: &plan.plan_tier,
            provider: "bitpay",
            currency: "USD",
            amount_cents: price.amount_cents,
            period_days: super::catalog::catalog().period_days as i32,
            provider_trade_no: &out_trade_no,
            pay_url: None,
            provider_session_id: None,
            ttl_hours: 24,
        },
    )
    .await?;

    let body = serde_json::json!({
        "price": amount,
        "currency": "USD",
        "notificationURL": cfg.notification_url,
        "redirectURL": std::env::var("BITPAY_REDIRECT_URL").unwrap_or_default(),
        "posData": format!("checkout_session_id={}", row.id),
        "extendedNotifications": true,
        "metadata": {
            "user_id": user_id.to_string(),
            "plan_tier": plan.plan_tier,
            "checkout_session_id": row.id.to_string(),
        }
    });

    let client = reqwest::Client::new();
    let resp = client
        .post(format!("{}/invoices", cfg.base_url()))
        .header("X-Accept-Version", "2.0.0")
        .bearer_auth(&cfg.api_token)
        .json(&body)
        .send()
        .await
        .map_err(|e| {
            tracing::error!(error = %e, "bitpay invoice request failed");
            ApiError::Internal
        })?;
    if !resp.status().is_success() {
        let text = resp.text().await.unwrap_or_default();
        tracing::error!(body = %text, "bitpay invoice error response");
        return Err(ApiError::Internal);
    }
    let inv: BitpayInvoiceResponse = resp.json().await.map_err(|e| {
        tracing::error!(error = %e, "bitpay invoice json parse failed");
        ApiError::Internal
    })?;
    set_provider_session_id(pool, row.id, &inv.data.id, Some(&inv.data.url)).await?;
    Ok((row.id, inv.data.url))
}

pub fn parse_pos_data(pos_data: &str) -> Option<Uuid> {
    for part in pos_data.split('&') {
        if let Some((k, v)) = part.split_once('=') {
            if k == "checkout_session_id" {
                return Uuid::parse_str(v.trim()).ok();
            }
        }
        if part.starts_with("checkout_session_id=") {
            let v = part.trim_start_matches("checkout_session_id=");
            return Uuid::parse_str(v.trim()).ok();
        }
    }
    None
}
