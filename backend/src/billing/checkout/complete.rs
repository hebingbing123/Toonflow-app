//! Mark checkout paid and apply plan via existing webhook ingest.

use chrono::{Duration, Utc};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use super::session::{mark_paid, CheckoutSessionRow};
use crate::billing::ingest::ingest_webhook;
use crate::error::ApiError;

pub async fn complete_checkout_session(
    pool: &PgPool,
    session: &CheckoutSessionRow,
    provider_event_id: &str,
    extra: Value,
) -> Result<(bool, bool), ApiError> {
    if session.status == "paid" {
        return Ok((true, false));
    }
    if session.status != "pending" {
        return Err(ApiError::Conflict("checkout session is not pending".into()));
    }

    let period_end = Utc::now() + Duration::days(session.period_days as i64);
    let mut payload = json!({
        "id": provider_event_id,
        "provider": session.provider,
        "user_id": session.user_id.to_string(),
        "plan_tier": session.plan_tier,
        "subscription_status": "active",
        "subscription_current_period_end_at": period_end.to_rfc3339(),
        "subscription_status_updated_at": Utc::now().to_rfc3339(),
        "checkout_session_id": session.id.to_string(),
        "currency": session.currency,
        "amount_cents": session.amount_cents,
    });
    if let Some(obj) = payload.as_object_mut() {
        if let Some(extra_obj) = extra.as_object() {
            for (k, v) in extra_obj {
                obj.insert(k.clone(), v.clone());
            }
        }
    }

    let _marked = mark_paid(pool, session.id).await?;
    let (duplicate, _row_id, profile_updated, _peid, _info) =
        ingest_webhook(pool, &payload).await?;

    Ok((duplicate, profile_updated))
}

#[allow(dead_code)]
pub async fn complete_by_session_id(
    pool: &PgPool,
    session_id: Uuid,
    provider_event_id: &str,
    extra: Value,
) -> Result<(bool, bool), ApiError> {
    let session = super::session::find_by_id(pool, session_id)
        .await?
        .ok_or(ApiError::NotFound)?;
    complete_checkout_session(pool, &session, provider_event_id, extra).await
}
