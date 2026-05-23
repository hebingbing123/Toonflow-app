//! 插入幂等性 Webhook 行并在一个事务中运行配置文件更新。

use serde_json::Value;

use crate::billing::provider_rules::is_informational_event;
use crate::error::{bad_request_i18n, ApiError};

use super::apply_plan::apply_plan_from_webhook_payload;
use super::event_parse::{
    build_provider_event_id, parse_event_created_at, parse_event_type, parse_raw_event_id,
};

pub async fn ingest_webhook(
    pool: &sqlx::PgPool,
    v: &Value,
) -> Result<(bool, Option<i64>, bool, String, bool), ApiError> {
    let enriched = if v.get("type").and_then(Value::as_str).is_some() {
        let mut cloned = v.clone();
        crate::billing::checkout::stripe_checkout::enrich_stripe_webhook_payload(&mut cloned);
        Some(cloned)
    } else {
        None
    };
    let v = enriched.as_ref().unwrap_or(v);

    let raw_event_id = parse_raw_event_id(v).ok_or_else(|| {
        bad_request_i18n(
            "JSON body must include a non-empty id (or event_id/eventId/notify_id/notifyId) for deduplication",
            "JSON body 必须包含非空 id（或 event_id/eventId/notify_id/notifyId）以便去重",
        )
    })?;

    let normalized = crate::billing::provider_rules::normalize_webhook(v);
    let provider = normalized.provider.clone();
    let provider_event_id = build_provider_event_id(provider.as_deref(), &raw_event_id);
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
    .bind(&raw_event_id)
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
