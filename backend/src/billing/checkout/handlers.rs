//! HTTP handlers for self-serve billing checkout.

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use utoipa::IntoParams;
use uuid::Uuid;

use super::alipay::{self, AlipayConfig};
use super::bitpay::BitpayConfig;
use super::catalog::{catalog, find_plan, purchasable_tiers};
use super::complete::complete_checkout_session;
use super::session::{
    find_by_provider_trade_no, get_session_for_user, insert_session, CheckoutSessionRow,
    NewCheckoutSession,
};
use super::stripe_checkout::StripeConfig;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize, IntoParams)]
pub struct PlansQuery {
    #[serde(default = "default_currency")]
    pub currency: String,
}

fn default_currency() -> String {
    "CNY".into()
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct BillingPlanPublic {
    pub plan_tier: String,
    pub display_name: String,
    pub description: String,
    pub currency: String,
    pub amount_cents: i64,
    pub price_label: String,
    pub period_days: u32,
    pub providers: Vec<String>,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct BillingPlansResponse {
    pub plans: Vec<BillingPlanPublic>,
    pub disclaimer: String,
}

#[utoipa::path(
    get,
    path = "/api/v1/billing/plans",
    operation_id = "getBillingPlansV1",
    tag = "billing",
    params(PlansQuery),
    responses(
        (status = 200, description = "OK", body = BillingPlansResponse),
    )
)]
pub async fn get_billing_plans(Query(q): Query<PlansQuery>) -> Json<BillingPlansResponse> {
    let currency = q.currency.to_ascii_uppercase();
    let cat = catalog();
    let mut plans = Vec::new();
    for entry in purchasable_tiers() {
        let Some(price) = entry.prices.get(&currency) else {
            continue;
        };
        let mut providers = Vec::new();
        if entry.alipay.is_some() {
            providers.push("alipay".into());
        }
        if entry.stripe.as_ref().is_some_and(|s| {
            (!s.price_id_cny.is_empty() && currency == "CNY")
                || (!s.price_id_usd.is_empty() && currency == "USD")
        }) {
            providers.push("stripe".into());
        }
        if entry.bitpay.as_ref().map(|b| b.enabled).unwrap_or(false) {
            providers.push("bitpay".into());
        }
        let display_name = if currency == "CNY" {
            entry.display_name_zh.clone()
        } else {
            entry.display_name_en.clone()
        };
        let description = if currency == "CNY" {
            entry.description_zh.clone()
        } else {
            entry.description_en.clone()
        };
        plans.push(BillingPlanPublic {
            plan_tier: entry.plan_tier.clone(),
            display_name,
            description,
            currency: currency.clone(),
            amount_cents: price.amount_cents,
            price_label: price.label.clone(),
            period_days: cat.period_days,
            providers,
        });
    }
    Json(BillingPlansResponse {
        plans,
        disclaimer: "Self-serve checkout; enterprise tier requires sales contact.".into(),
    })
}

#[derive(Debug, Deserialize, utoipa::ToSchema)]
pub struct CheckoutRequest {
    pub plan_tier: String,
    pub provider: String,
    #[serde(default = "default_currency")]
    pub currency: String,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct CheckoutResponse {
    pub session_id: String,
    pub status: String,
    pub pay_url: String,
    pub provider: String,
    pub plan_tier: String,
    pub amount_cents: i64,
    pub currency: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/billing/checkout",
    operation_id = "postBillingCheckoutV1",
    tag = "billing",
    request_body = CheckoutRequest,
    responses(
        (status = 200, description = "OK", body = CheckoutResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Plan not found", body = crate::error::ErrorBody),
        (status = 501, description = "Provider not configured", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub async fn post_billing_checkout(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CheckoutRequest>,
) -> Result<Json<CheckoutResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let plan = find_plan(&body.plan_tier).ok_or(ApiError::NotFound)?;
    let currency = body.currency.to_ascii_uppercase();
    let price = plan.prices.get(&currency).ok_or(ApiError::NotFound)?;
    let provider = body.provider.trim().to_ascii_lowercase();

    match provider.as_str() {
        "alipay" => checkout_alipay(pool, uid, plan, &currency, price.amount_cents).await,
        "stripe" => {
            let cfg = StripeConfig::from_env().ok_or_else(|| {
                ApiError::NotImplemented("Stripe checkout is not configured".into())
            })?;
            let (session_id, pay_url) = super::stripe_checkout::create_checkout(
                &cfg,
                pool,
                uid,
                &plan.plan_tier,
                &currency,
            )
            .await?;
            Ok(Json(CheckoutResponse {
                session_id: session_id.to_string(),
                status: "pending".into(),
                pay_url,
                provider: "stripe".into(),
                plan_tier: plan.plan_tier.clone(),
                amount_cents: price.amount_cents,
                currency,
            }))
        }
        "bitpay" => {
            let cfg = BitpayConfig::from_env().ok_or_else(|| {
                ApiError::NotImplemented("BitPay checkout is not configured".into())
            })?;
            let (session_id, pay_url) =
                super::bitpay::create_invoice(&cfg, pool, uid, &plan.plan_tier, &currency).await?;
            Ok(Json(CheckoutResponse {
                session_id: session_id.to_string(),
                status: "pending".into(),
                pay_url,
                provider: "bitpay".into(),
                plan_tier: plan.plan_tier.clone(),
                amount_cents: price.amount_cents,
                currency,
            }))
        }
        _ => Err(ApiError::BadRequest(format!(
            "unsupported provider: {}",
            body.provider
        ))),
    }
}

async fn checkout_alipay(
    pool: &sqlx::PgPool,
    uid: Uuid,
    plan: &super::catalog::PlanCatalogEntry,
    currency: &str,
    amount_cents: i64,
) -> Result<Json<CheckoutResponse>, ApiError> {
    let out_trade_no = format!("of-alipay-{}", Uuid::new_v4());
    let row = insert_session(
        pool,
        NewCheckoutSession {
            user_id: uid,
            plan_tier: &plan.plan_tier,
            provider: "alipay",
            currency,
            amount_cents,
            period_days: catalog().period_days as i32,
            provider_trade_no: &out_trade_no,
            pay_url: None,
            provider_session_id: None,
            ttl_hours: 2,
        },
    )
    .await?;

    let pay_url = if let Some(cfg) = AlipayConfig::from_env() {
        let subject = format!("OpenFlow {}", plan.display_name_zh);
        let session_id_str = row.id.to_string();
        let passback = urlencoding::encode(&session_id_str);
        alipay::build_page_pay_url(
            &cfg,
            &out_trade_no,
            &subject,
            &alipay::cents_to_yuan(amount_cents),
            &passback,
        )?
    } else if alipay::mock_checkout_enabled() {
        mock_pay_url(pool, row.id).await?
    } else {
        return Err(ApiError::NotImplemented(
            "Alipay is not configured; set ALIPAY_* or BILLING_CHECKOUT_MOCK=1".into(),
        ));
    };

    sqlx::query(
        r#"UPDATE app_billing_checkout_session SET pay_url = $2, updated_at = NOW() WHERE id = $1"#,
    )
    .bind(row.id)
    .bind(&pay_url)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(CheckoutResponse {
        session_id: row.id.to_string(),
        status: row.status,
        pay_url,
        provider: "alipay".into(),
        plan_tier: plan.plan_tier.clone(),
        amount_cents,
        currency: currency.to_string(),
    }))
}

async fn mock_pay_url(_pool: &sqlx::PgPool, session_id: Uuid) -> Result<String, ApiError> {
    let base = std::env::var("PUBLIC_API_BASE_URL")
        .or_else(|_| std::env::var("API_BASE_URL"))
        .unwrap_or_else(|_| "http://127.0.0.1:3000".into());
    Ok(format!(
        "{base}/api/v1/billing/checkout/{session_id}/mock-pay"
    ))
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct CheckoutSessionResponse {
    pub session_id: String,
    pub status: String,
    pub plan_tier: String,
    pub provider: String,
    pub amount_cents: i64,
    pub currency: String,
    pub paid_at: Option<String>,
    pub expires_at: String,
}

fn session_to_response(row: &CheckoutSessionRow) -> CheckoutSessionResponse {
    CheckoutSessionResponse {
        session_id: row.id.to_string(),
        status: row.status.clone(),
        plan_tier: row.plan_tier.clone(),
        provider: row.provider.clone(),
        amount_cents: row.amount_cents,
        currency: row.currency.clone(),
        paid_at: row.paid_at.map(|t| t.to_rfc3339()),
        expires_at: row.expires_at.to_rfc3339(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/billing/checkout/{session_id}",
    operation_id = "getBillingCheckoutSessionV1",
    tag = "billing",
    params(("session_id" = String, Path, description = "Checkout session UUID")),
    responses(
        (status = 200, description = "OK", body = CheckoutSessionResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub async fn get_checkout_session(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(session_id): Path<String>,
) -> Result<Json<CheckoutSessionResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let sid = Uuid::parse_str(session_id.trim())
        .map_err(|_| ApiError::BadRequest("invalid session_id".into()))?;
    let row = get_session_for_user(pool, sid, uid)
        .await?
        .ok_or(ApiError::NotFound)?;
    Ok(Json(session_to_response(&row)))
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct BillingPortalResponse {
    pub url: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/billing/portal",
    operation_id = "postBillingPortalV1",
    tag = "billing",
    responses(
        (status = 200, description = "OK", body = BillingPortalResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "No billing customer", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub async fn post_billing_portal(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<BillingPortalResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let cfg = StripeConfig::from_env()
        .ok_or_else(|| ApiError::NotImplemented("Stripe portal is not configured".into()))?;
    let url = super::stripe_checkout::create_portal(&cfg, pool, uid).await?;
    Ok(Json(BillingPortalResponse { url }))
}

/// Dev/sandbox: complete a pending checkout without real payment.
pub async fn get_mock_pay(
    State(state): State<AppState>,
    Path(session_id): Path<Uuid>,
) -> Result<impl IntoResponse, ApiError> {
    if !alipay::mock_checkout_enabled() {
        return Err(ApiError::Forbidden("mock checkout disabled".into()));
    }
    let pool = state.require_pool()?;
    let session = super::session::find_by_id(pool, session_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    let event_id = format!("mock-pay-{}", session_id);
    complete_checkout_session(
        pool,
        &session,
        &event_id,
        json!({ "trade_status": "TRADE_SUCCESS" }),
    )
    .await?;
    Ok(Json(json!({ "ok": true, "session_id": session_id })))
}

pub async fn post_alipay_notify(
    State(state): State<AppState>,
    body: String,
) -> Result<impl IntoResponse, ApiError> {
    let cfg = AlipayConfig::from_env().ok_or(ApiError::WebhookNotConfigured)?;
    let params = alipay::parse_form_body(&body);
    alipay::verify_notify(&params, &cfg.alipay_public_key_pem)?;

    let trade_status = params.get("trade_status").map(String::as_str).unwrap_or("");
    if trade_status != "TRADE_SUCCESS" && trade_status != "TRADE_FINISHED" {
        return Ok("success".into_response());
    }

    let out_trade_no = params
        .get("out_trade_no")
        .ok_or(ApiError::BadRequest("missing out_trade_no".into()))?;
    let pool = state.require_pool()?;
    let session = find_by_provider_trade_no(pool, "alipay", out_trade_no)
        .await?
        .ok_or(ApiError::NotFound)?;

    let notify_id = params
        .get("notify_id")
        .cloned()
        .unwrap_or_else(|| format!("alipay-{out_trade_no}"));
    let mut extra = json!({
        "trade_status": trade_status,
        "provider": "alipay",
    });
    if let Some(obj) = extra.as_object_mut() {
        for (k, v) in &params {
            if k.starts_with("buyer_") || k == "gmt_payment" {
                obj.insert(k.clone(), json!(v));
            }
        }
    }
    complete_checkout_session(pool, &session, &notify_id, extra).await?;
    Ok("success".into_response())
}

pub async fn post_bitpay_notify(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> Result<impl IntoResponse, ApiError> {
    let cfg = BitpayConfig::from_env().ok_or(ApiError::WebhookNotConfigured)?;
    let sig = headers
        .get("X-Signature")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    super::bitpay::verify_webhook_signature(&cfg.api_token, &body, sig)?;
    let v: serde_json::Value = serde_json::from_slice(&body)
        .map_err(|_| ApiError::BadRequest("invalid bitpay webhook json".into()))?;
    let event_name = v
        .get("event")
        .and_then(|e| e.get("name"))
        .and_then(|n| n.as_str());
    if event_name != Some("invoice_completed") {
        return Ok(Json(json!({ "received": true })));
    }
    let invoice_id = v.pointer("/data/id").and_then(|x| x.as_str()).unwrap_or("");
    let pos_data = v
        .pointer("/data/posData")
        .and_then(|x| x.as_str())
        .unwrap_or("");
    let pool = state.require_pool()?;
    let session = if let Some(sid) = super::bitpay::parse_pos_data(pos_data) {
        super::session::find_by_id(pool, sid).await?
    } else {
        None
    };
    let session = if let Some(s) = session {
        Some(s)
    } else if !invoice_id.is_empty() {
        sqlx::query_as::<_, CheckoutSessionRow>(
            r#"
            SELECT id, user_id, plan_tier, provider, currency, amount_cents, status,
              provider_trade_no, provider_session_id, pay_url, period_days,
              expires_at, paid_at
            FROM app_billing_checkout_session
            WHERE provider = 'bitpay' AND provider_session_id = $1
            "#,
        )
        .bind(invoice_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        None
    };
    let session = session.ok_or(ApiError::NotFound)?;
    let event_id = format!("bitpay-{invoice_id}");
    complete_checkout_session(pool, &session, &event_id, json!({ "provider": "bitpay" })).await?;
    Ok(Json(json!({ "received": true })))
}

pub async fn post_stripe_checkout_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> Result<Json<serde_json::Value>, ApiError> {
    if headers.contains_key("stripe-signature") {
        let secret = crate::billing::verify::billing_secret()?;
        crate::billing::verify::verify_signature(&secret, body.as_ref(), &headers)?;
    }
    let mut v: serde_json::Value = serde_json::from_slice(&body)
        .map_err(|_| ApiError::BadRequest("body must be valid JSON".into()))?;
    super::stripe_checkout::enrich_stripe_webhook_payload(&mut v);

    let event_type = v.pointer("/type").and_then(|t| t.as_str()).unwrap_or("");
    if event_type == "checkout.session.completed" {
        let pool = state.require_pool()?;
        if let Some(ref_id) = v
            .pointer("/data/object/client_reference_id")
            .and_then(|x| x.as_str())
        {
            if let Ok(sid) = Uuid::parse_str(ref_id) {
                if let Some(session) = super::session::find_by_id(pool, sid).await? {
                    let stripe_id = v
                        .pointer("/data/object/id")
                        .and_then(|x| x.as_str())
                        .unwrap_or(ref_id);
                    complete_checkout_session(
                        pool,
                        &session,
                        &format!("stripe-{stripe_id}"),
                        v.clone(),
                    )
                    .await?;
                }
            }
        }
    }

    let pool = state.require_pool()?;
    let (duplicate, _id, profile_updated, _peid, informational) =
        crate::billing::ingest::ingest_webhook(pool, &v).await?;
    Ok(Json(json!({
        "received": true,
        "duplicate": duplicate,
        "profile_updated": profile_updated,
        "informational_event": informational,
    })))
}
