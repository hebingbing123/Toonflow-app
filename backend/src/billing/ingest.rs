//! Idempotent webhook row insert + optional `app_user_profile` upsert.

use chrono::{DateTime, Utc};
use serde_json::Value;
use uuid::Uuid;

use super::provider_adapter::select_billing_adapter;
use super::provider_rules::{is_informational_event, normalize_webhook, ProviderStatusConfidence};
use crate::error::ApiError;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SubscriptionStatusSource {
    Explicit,
    ProviderDerived,
}

#[derive(Debug, Clone)]
struct ExistingSubscriptionState {
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    subscription_status_updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
struct IncomingSubscriptionState {
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    subscription_status_updated_at: Option<DateTime<Utc>>,
    source: Option<SubscriptionStatusSource>,
    provider_confidence: Option<ProviderStatusConfidence>,
}

#[derive(Debug, Clone)]
struct ResolvedSubscriptionState {
    subscription_status: Option<String>,
    subscription_current_period_end_at: Option<DateTime<Utc>>,
    subscription_status_updated_at: Option<DateTime<Utc>>,
}

fn normalize_subscription_status(raw: &str) -> Option<String> {
    let status = raw.trim().to_ascii_lowercase();
    match status.as_str() {
        "free" | "trialing" | "active" | "past_due" | "unpaid" | "canceled" | "incomplete"
        | "incomplete_expired" => Some(status),
        _ => None,
    }
}

fn parse_subscription_status(v: &Value) -> Option<String> {
    let raw = v.get("subscription_status").and_then(Value::as_str)?;
    normalize_subscription_status(raw)
}

fn parse_subscription_period_end(v: &Value) -> Option<DateTime<Utc>> {
    if let Some(ts) = v
        .get("subscription_current_period_end")
        .and_then(Value::as_i64)
    {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }

    let raw = v
        .get("subscription_current_period_end")
        .and_then(Value::as_str)?;
    DateTime::parse_from_rfc3339(raw.trim())
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

fn parse_subscription_status_updated_at(v: &Value) -> Option<DateTime<Utc>> {
    if let Some(ts) = v
        .get("subscription_status_updated_at")
        .and_then(Value::as_i64)
    {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }

    let raw = v
        .get("subscription_status_updated_at")
        .and_then(Value::as_str)?;
    DateTime::parse_from_rfc3339(raw.trim())
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

fn build_provider_event_id(provider: Option<&str>, raw_id: &str) -> String {
    let id = raw_id.trim();
    let p = provider.unwrap_or("").trim();
    if p.is_empty() {
        id.to_string()
    } else {
        format!("{p}:{id}")
    }
}

fn parse_event_type(v: &Value) -> Option<String> {
    v.get("type")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .or_else(|| {
            v.get("event_type")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|s| !s.is_empty())
        })
        .map(|s| s.chars().take(128).collect())
}

fn parse_event_created_at(v: &Value) -> Option<DateTime<Utc>> {
    if let Some(ts) = v.get("event_created_at").and_then(Value::as_i64) {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    if let Some(s) = v.get("event_created_at").and_then(Value::as_str) {
        if let Ok(dt) = DateTime::parse_from_rfc3339(s.trim()) {
            return Some(dt.with_timezone(&Utc));
        }
    }
    if let Some(ts) = v.get("created").and_then(Value::as_i64) {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    if let Some(ts) = v.get("occurred_at").and_then(Value::as_i64) {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    if let Some(s) = v.get("occurred_at").and_then(Value::as_str) {
        if let Ok(dt) = DateTime::parse_from_rfc3339(s.trim()) {
            return Some(dt.with_timezone(&Utc));
        }
    }
    if let Some(ts) = v.get("notify_time").and_then(Value::as_i64) {
        return DateTime::<Utc>::from_timestamp(ts, 0);
    }
    if let Some(s) = v.get("notify_time").and_then(Value::as_str) {
        if let Ok(dt) = DateTime::parse_from_rfc3339(s.trim()) {
            return Some(dt.with_timezone(&Utc));
        }
    }
    None
}

fn is_terminal_subscription_status(status: &str) -> bool {
    matches!(status, "canceled" | "unpaid" | "incomplete_expired")
}

fn resolve_subscription_state(
    existing: Option<ExistingSubscriptionState>,
    incoming: IncomingSubscriptionState,
) -> ResolvedSubscriptionState {
    let Some(existing) = existing else {
        return ResolvedSubscriptionState {
            subscription_status: incoming.subscription_status,
            subscription_current_period_end_at: incoming.subscription_current_period_end_at,
            subscription_status_updated_at: incoming.subscription_status_updated_at,
        };
    };

    let Some(incoming_status) = incoming.subscription_status.clone() else {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    };

    let Some(incoming_updated_at) = incoming.subscription_status_updated_at else {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    };

    let Some(existing_updated_at) = existing.subscription_status_updated_at else {
        return ResolvedSubscriptionState {
            subscription_status: Some(incoming_status),
            subscription_current_period_end_at: incoming.subscription_current_period_end_at,
            subscription_status_updated_at: Some(incoming_updated_at),
        };
    };

    if incoming_updated_at < existing_updated_at {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    // Guard: provider-derived events should not reopen terminal states without an explicit status payload.
    let terminal_regression = matches!(
        (
            existing.subscription_status.as_deref(),
            incoming.source,
            incoming_status.as_str(),
        ),
        (Some(curr), Some(SubscriptionStatusSource::ProviderDerived), next)
            if is_terminal_subscription_status(curr) && !is_terminal_subscription_status(next)
    );
    if terminal_regression {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    // Guard: when timestamp ties exactly, low-confidence provider fallback events should not
    // churn existing state (e.g. duplicate/reordered "event type only" notifications).
    let low_confidence_tie_override = matches!(
        (
            incoming.source,
            incoming.provider_confidence,
            existing.subscription_status.as_deref(),
            incoming_status.as_str(),
        ),
        (
            Some(SubscriptionStatusSource::ProviderDerived),
            Some(ProviderStatusConfidence::EventFallback),
            Some(curr),
            next
        ) if curr != next && incoming_updated_at == existing_updated_at
    );
    if low_confidence_tie_override {
        return ResolvedSubscriptionState {
            subscription_status: existing.subscription_status,
            subscription_current_period_end_at: existing.subscription_current_period_end_at,
            subscription_status_updated_at: existing.subscription_status_updated_at,
        };
    }

    ResolvedSubscriptionState {
        subscription_status: Some(incoming_status),
        subscription_current_period_end_at: incoming.subscription_current_period_end_at,
        subscription_status_updated_at: Some(incoming_updated_at),
    }
}

/// When `user_id` (UUID) and `plan_tier` (non-empty) are present, upsert profile (first successful webhook only).
pub(crate) async fn apply_plan_from_webhook_payload(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    v: &Value,
) -> Result<bool, sqlx::Error> {
    let Some(uid_str) = v.get("user_id").and_then(Value::as_str) else {
        return Ok(false);
    };
    let Ok(uid) = Uuid::parse_str(uid_str.trim()) else {
        tracing::warn!(user_id = %uid_str, "billing webhook: invalid user_id (skip profile upsert)");
        return Ok(false);
    };
    let Some(tier_raw) = v.get("plan_tier").and_then(Value::as_str) else {
        return Ok(false);
    };
    let tier: String = tier_raw.trim().chars().take(64).collect();
    if tier.is_empty() {
        return Ok(false);
    }

    let adapter = select_billing_adapter(v);
    let currency = adapter.currency;
    let normalized = normalize_webhook(v);
    let provider = normalized.provider;
    let derived = normalized.derived;
    let explicit_status = parse_subscription_status(v);
    let explicit_period_end = parse_subscription_period_end(v);
    let explicit_updated_at = parse_subscription_status_updated_at(v);
    let has_derived_status = derived.subscription_status.is_some();
    let incoming = IncomingSubscriptionState {
        subscription_status: explicit_status.clone().or(derived.subscription_status),
        subscription_current_period_end_at: explicit_period_end
            .or(derived.subscription_current_period_end),
        subscription_status_updated_at: explicit_updated_at
            .or(derived.subscription_status_updated_at),
        source: if explicit_status.is_some() {
            Some(SubscriptionStatusSource::Explicit)
        } else if has_derived_status {
            Some(SubscriptionStatusSource::ProviderDerived)
        } else {
            None
        },
        provider_confidence: derived.status_confidence,
    };

    let existing = sqlx::query_as::<_, (Option<String>, Option<DateTime<Utc>>, Option<DateTime<Utc>>)>(
        r#"
        SELECT subscription_status, subscription_current_period_end_at, subscription_status_updated_at
        FROM app_user_profile
        WHERE user_id = $1
        FOR UPDATE
        "#,
    )
    .bind(uid)
    .fetch_optional(&mut **tx)
    .await?
    .map(
        |(
            subscription_status,
            subscription_current_period_end_at,
            subscription_status_updated_at,
        )| ExistingSubscriptionState {
            subscription_status,
            subscription_current_period_end_at,
            subscription_status_updated_at,
        },
    );

    let resolved = resolve_subscription_state(existing, incoming);

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (
          user_id,
          plan_tier,
          billing_currency,
          billing_provider,
          subscription_status,
          subscription_current_period_end_at,
          subscription_status_updated_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = COALESCE(EXCLUDED.billing_currency, app_user_profile.billing_currency),
          billing_provider = COALESCE(EXCLUDED.billing_provider, app_user_profile.billing_provider),
          subscription_status = EXCLUDED.subscription_status,
          subscription_current_period_end_at = EXCLUDED.subscription_current_period_end_at,
          subscription_status_updated_at = EXCLUDED.subscription_status_updated_at,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(&tier)
    .bind(currency.as_deref())
    .bind(provider.as_deref())
    .bind(resolved.subscription_status.as_deref())
    .bind(resolved.subscription_current_period_end_at)
    .bind(resolved.subscription_status_updated_at)
    .execute(&mut **tx)
    .await?;

    Ok(true)
}

pub(crate) async fn ingest_webhook(
    pool: &sqlx::PgPool,
    v: &Value,
) -> Result<(bool, Option<i64>, bool, String, bool), ApiError> {
    let raw_event_id = v
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| {
            ApiError::BadRequest(
                "JSON body must include a non-empty string id for deduplication".into(),
            )
        })?;

    let normalized = normalize_webhook(v);
    let provider = normalized.provider.clone();
    let provider_event_id = build_provider_event_id(provider.as_deref(), raw_event_id);
    let event_type = parse_event_type(v);
    let event_created_at = parse_event_created_at(v);
    let informational_event = is_informational_event(v);

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let inserted = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO app_billing_webhook_event (
          provider_event_id,
          payload,
          provider,
          raw_event_id,
          event_type,
          event_created_at,
          is_informational_event
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (provider_event_id) DO NOTHING
        RETURNING id
        "#,
    )
    .bind(&provider_event_id)
    .bind(v)
    .bind(provider.as_deref())
    .bind(raw_event_id)
    .bind(event_type.as_deref())
    .bind(event_created_at)
    .bind(informational_event)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row_id) = inserted else {
        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok((true, None, false, provider_event_id, informational_event));
    };

    let profile_updated = apply_plan_from_webhook_payload(&mut tx, v)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((
        false,
        Some(row_id),
        profile_updated,
        provider_event_id,
        informational_event,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::billing::provider_rules;
    use serde_json::json;

    #[test]
    fn parse_subscription_status_accepts_known_values_case_insensitive() {
        let v = json!({ "subscription_status": " AcTive " });
        assert_eq!(parse_subscription_status(&v).as_deref(), Some("active"));
    }

    #[test]
    fn normalize_provider_name_lowercases_and_trims() {
        assert_eq!(
            provider_rules::normalize_provider_name(" Stripe "),
            Some("stripe".to_string())
        );
    }

    #[test]
    fn parse_subscription_status_rejects_unknown_value() {
        let v = json!({ "subscription_status": "paused" });
        assert!(parse_subscription_status(&v).is_none());
    }

    #[test]
    fn build_provider_event_id_namespaces_when_provider_present() {
        assert_eq!(
            build_provider_event_id(Some("stripe"), "evt_1"),
            "stripe:evt_1".to_string()
        );
    }

    #[test]
    fn build_provider_event_id_keeps_raw_when_provider_missing() {
        assert_eq!(build_provider_event_id(None, "evt_1"), "evt_1".to_string());
    }

    #[test]
    fn parse_event_type_uses_event_type_fallback_when_type_missing() {
        let v = json!({ "event_type": "invoice.paid" });
        assert_eq!(parse_event_type(&v).as_deref(), Some("invoice.paid"));
    }

    #[test]
    fn parse_event_created_at_prefers_event_created_at_rfc3339() {
        let v = json!({
            "event_created_at": "2026-04-08T10:11:12Z",
            "created": 1_700_000_000_i64
        });
        let got = parse_event_created_at(&v).expect("event_created_at should parse");
        assert_eq!(got.to_rfc3339(), "2026-04-08T10:11:12+00:00");
    }

    #[test]
    fn parse_event_created_at_accepts_event_created_at_unix_timestamp() {
        let v = json!({ "event_created_at": 1_800_000_001_i64 });
        let got = parse_event_created_at(&v).expect("event_created_at unix should parse");
        assert_eq!(got.timestamp(), 1_800_000_001_i64);
    }

    #[test]
    fn resolve_subscription_state_rejects_stale_event() {
        let existing = ExistingSubscriptionState {
            subscription_status: Some("active".into()),
            subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
        };
        let incoming = IncomingSubscriptionState {
            subscription_status: Some("canceled".into()),
            subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_050_000, 0),
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_050_000, 0),
            source: Some(SubscriptionStatusSource::ProviderDerived),
            provider_confidence: Some(ProviderStatusConfidence::DirectField),
        };
        let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
        assert_eq!(resolved.subscription_status, existing.subscription_status);
        assert_eq!(
            resolved.subscription_status_updated_at,
            existing.subscription_status_updated_at
        );
    }

    #[test]
    fn resolve_subscription_state_blocks_provider_terminal_regression() {
        let existing = ExistingSubscriptionState {
            subscription_status: Some("canceled".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
        };
        let incoming = IncomingSubscriptionState {
            subscription_status: Some("active".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_200_000, 0),
            source: Some(SubscriptionStatusSource::ProviderDerived),
            provider_confidence: Some(ProviderStatusConfidence::DirectField),
        };
        let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
        assert_eq!(resolved.subscription_status, existing.subscription_status);
    }

    #[test]
    fn resolve_subscription_state_allows_explicit_transition_from_terminal() {
        let existing = ExistingSubscriptionState {
            subscription_status: Some("canceled".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_100_000, 0),
        };
        let incoming = IncomingSubscriptionState {
            subscription_status: Some("active".into()),
            subscription_current_period_end_at: DateTime::<Utc>::from_timestamp(1_700_300_000, 0),
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_300_000, 0),
            source: Some(SubscriptionStatusSource::Explicit),
            provider_confidence: None,
        };
        let resolved = resolve_subscription_state(Some(existing), incoming);
        assert_eq!(resolved.subscription_status.as_deref(), Some("active"));
    }

    #[test]
    fn resolve_subscription_state_ignores_provider_event_fallback_on_equal_timestamp() {
        let existing = ExistingSubscriptionState {
            subscription_status: Some("active".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_400_000, 0),
        };
        let incoming = IncomingSubscriptionState {
            subscription_status: Some("past_due".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_400_000, 0),
            source: Some(SubscriptionStatusSource::ProviderDerived),
            provider_confidence: Some(ProviderStatusConfidence::EventFallback),
        };
        let resolved = resolve_subscription_state(Some(existing.clone()), incoming);
        assert_eq!(resolved.subscription_status, existing.subscription_status);
    }

    #[test]
    fn resolve_subscription_state_accepts_provider_direct_field_on_equal_timestamp() {
        let existing = ExistingSubscriptionState {
            subscription_status: Some("active".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_500_000, 0),
        };
        let incoming = IncomingSubscriptionState {
            subscription_status: Some("past_due".into()),
            subscription_current_period_end_at: None,
            subscription_status_updated_at: DateTime::<Utc>::from_timestamp(1_700_500_000, 0),
            source: Some(SubscriptionStatusSource::ProviderDerived),
            provider_confidence: Some(ProviderStatusConfidence::DirectField),
        };
        let resolved = resolve_subscription_state(Some(existing), incoming);
        assert_eq!(resolved.subscription_status.as_deref(), Some("past_due"));
    }

    #[test]
    fn derive_from_provider_stripe_status_field() {
        let v = json!({
            "billing_provider": "stripe",
            "data": { "object": { "status": "past_due" } }
        });
        assert_eq!(
            provider_rules::derive_from_provider(&v)
                .subscription_status
                .as_deref(),
            Some("past_due")
        );
    }

    #[test]
    fn derive_from_provider_stripe_event_type_fallback() {
        let v = json!({
            "billing_provider": "stripe",
            "type": "customer.subscription.deleted"
        });
        assert_eq!(
            provider_rules::derive_from_provider(&v)
                .subscription_status
                .as_deref(),
            Some("canceled")
        );
    }

    #[test]
    fn explicit_subscription_status_takes_precedence_over_provider_mapping() {
        let v = json!({
            "subscription_status": "active",
            "billing_provider": "stripe",
            "type": "customer.subscription.deleted"
        });
        let got = parse_subscription_status(&v)
            .or(provider_rules::derive_from_provider(&v).subscription_status);
        assert_eq!(got.as_deref(), Some("active"));
    }

    #[test]
    fn derive_from_provider_ignores_non_stripe() {
        let v = json!({
            "billing_provider": "alipay",
            "type": "customer.subscription.deleted",
            "data": { "object": { "status": "canceled" } }
        });
        assert!(provider_rules::derive_from_provider(&v)
            .subscription_status
            .is_none());
    }

    #[test]
    fn derive_from_provider_alipay_trade_status() {
        let v = json!({
            "billing_provider": "alipay",
            "trade_status": "TRADE_SUCCESS"
        });
        assert_eq!(
            provider_rules::derive_from_provider(&v)
                .subscription_status
                .as_deref(),
            Some("active")
        );
    }

    #[test]
    fn derive_from_provider_alipay_event_type_fallback() {
        let v = json!({
            "billing_provider": "alipay",
            "type": "trade.closed"
        });
        assert_eq!(
            provider_rules::derive_from_provider(&v)
                .subscription_status
                .as_deref(),
            Some("canceled")
        );
    }

    #[test]
    fn derive_from_provider_alipay_notify_time_as_rfc3339() {
        let v = json!({
            "billing_provider": "alipay",
            "notify_time": "2026-04-06T10:20:30Z"
        });
        let got = provider_rules::derive_from_provider(&v)
            .subscription_status_updated_at
            .expect("notify_time should parse");
        assert_eq!(got.to_rfc3339(), "2026-04-06T10:20:30+00:00");
    }

    #[test]
    fn parse_subscription_period_end_accepts_unix_timestamp() {
        let v = json!({ "subscription_current_period_end": 1_700_000_000_i64 });
        let got = parse_subscription_period_end(&v).expect("timestamp should parse");
        assert_eq!(got.timestamp(), 1_700_000_000_i64);
    }

    #[test]
    fn parse_subscription_period_end_accepts_rfc3339() {
        let v = json!({ "subscription_current_period_end": "2026-04-06T12:34:56Z" });
        let got = parse_subscription_period_end(&v).expect("rfc3339 should parse");
        assert_eq!(got.to_rfc3339(), "2026-04-06T12:34:56+00:00");
    }

    #[test]
    fn derive_from_provider_period_end_from_stripe() {
        let v = json!({
            "billing_provider": "stripe",
            "data": { "object": { "current_period_end": 1_700_000_001_i64 } }
        });
        let got = provider_rules::derive_from_provider(&v)
            .subscription_current_period_end
            .expect("timestamp should parse");
        assert_eq!(got.timestamp(), 1_700_000_001_i64);
    }

    #[test]
    fn parse_subscription_status_updated_at_accepts_unix_timestamp() {
        let v = json!({ "subscription_status_updated_at": 1_700_123_456_i64 });
        let got = parse_subscription_status_updated_at(&v).expect("timestamp should parse");
        assert_eq!(got.timestamp(), 1_700_123_456_i64);
    }

    #[test]
    fn parse_subscription_status_updated_at_accepts_rfc3339() {
        let v = json!({ "subscription_status_updated_at": "2026-04-06T20:30:40Z" });
        let got = parse_subscription_status_updated_at(&v).expect("rfc3339 should parse");
        assert_eq!(got.to_rfc3339(), "2026-04-06T20:30:40+00:00");
    }

    #[test]
    fn derive_from_provider_status_updated_at_from_stripe_created() {
        let v = json!({
            "billing_provider": "stripe",
            "created": 1_700_888_777_i64
        });
        let got = provider_rules::derive_from_provider(&v)
            .subscription_status_updated_at
            .expect("created should parse as updated_at");
        assert_eq!(got.timestamp(), 1_700_888_777_i64);
    }

    #[test]
    fn parse_event_created_at_accepts_paddle_occurred_at_rfc3339() {
        let v = json!({
            "billing_provider": "paddle",
            "occurred_at": "2026-04-07T08:09:10Z"
        });
        let got = parse_event_created_at(&v).expect("occurred_at should parse");
        assert_eq!(got.to_rfc3339(), "2026-04-07T08:09:10+00:00");
    }

    #[test]
    fn derive_from_provider_uses_currency_adapter_when_provider_missing() {
        let v = json!({
            "billing_currency": "USD",
            "type": "invoice.payment_succeeded"
        });
        assert_eq!(
            provider_rules::derive_from_provider(&v)
                .subscription_status
                .as_deref(),
            Some("active")
        );
    }
}
