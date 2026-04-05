//! Idempotent webhook row insert + optional `app_user_profile` upsert.

use serde_json::Value;
use uuid::Uuid;

use crate::error::ApiError;

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

    let currency = v
        .get("billing_currency")
        .and_then(Value::as_str)
        .map(|s| s.trim().chars().take(16).collect::<String>())
        .filter(|s| !s.is_empty());
    let provider = v
        .get("billing_provider")
        .and_then(Value::as_str)
        .map(|s| s.trim().chars().take(64).collect::<String>())
        .filter(|s| !s.is_empty());

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, plan_tier, billing_currency, billing_provider, updated_at)
        VALUES ($1, $2, $3, $4, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          plan_tier = EXCLUDED.plan_tier,
          billing_currency = COALESCE(EXCLUDED.billing_currency, app_user_profile.billing_currency),
          billing_provider = COALESCE(EXCLUDED.billing_provider, app_user_profile.billing_provider),
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(&tier)
    .bind(currency.as_deref())
    .bind(provider.as_deref())
    .execute(&mut **tx)
    .await?;

    Ok(true)
}

pub(crate) async fn ingest_webhook(
    pool: &sqlx::PgPool,
    v: &Value,
) -> Result<Option<(i64, bool)>, ApiError> {
    let provider_event_id = v
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| {
            ApiError::BadRequest(
                "JSON body must include a non-empty string id for deduplication".into(),
            )
        })?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let inserted = sqlx::query_scalar::<_, i64>(
        r#"
        INSERT INTO app_billing_webhook_event (provider_event_id, payload)
        VALUES ($1, $2)
        ON CONFLICT (provider_event_id) DO NOTHING
        RETURNING id
        "#,
    )
    .bind(provider_event_id)
    .bind(v)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row_id) = inserted else {
        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok(None);
    };

    let profile_updated = apply_plan_from_webhook_payload(&mut tx, v)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Some((row_id, profile_updated)))
}
