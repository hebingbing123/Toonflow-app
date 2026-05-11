//! Outbound HTTP POST with exponential backoff retries + job lifecycle hooks.

use std::time::Duration;

use chrono::SecondsFormat;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use super::sign_toonflow;

/// Max HTTP attempts per logical delivery (initial try + retries). Matches WH2.4.
const MAX_DELIVERY_ATTEMPTS: u32 = 3;

const PER_ATTEMPT_TIMEOUT: Duration = Duration::from_secs(15);

#[inline]
pub(crate) fn webhook_matches_workspace(
    webhook_workspace_id: Option<Uuid>,
    job_workspace_id: Option<Uuid>,
) -> bool {
    match webhook_workspace_id {
        None => true,
        Some(ws) => job_workspace_id == Some(ws),
    }
}

/// `event_types` is the JSON array from `app_outbound_webhook.event_types`. Empty array = all platform types.
pub(crate) fn webhook_subscribes_event(event_types: &[String], event_type: &str) -> bool {
    if event_types.is_empty() {
        return true;
    }
    event_types.iter().any(|t| t == event_type)
}

pub(crate) struct DeliveryAttemptOutcome {
    pub delivered: bool,
    pub http_status: Option<u16>,
    pub error: Option<String>,
}

#[allow(clippy::too_many_arguments)]
pub(crate) async fn persist_delivery_attempt(
    pool: &PgPool,
    webhook_id: Uuid,
    owner_user_id: Uuid,
    event_type: &str,
    payload: &Value,
    status: &str,
    http_status: Option<i32>,
    error: Option<&str>,
    retry_count: i32,
    delivered_at: Option<chrono::DateTime<chrono::Utc>>,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO public.app_outbound_webhook_delivery (
            webhook_id, owner_user_id, event_type, payload, status, http_status, error, retry_count, delivered_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        "#,
    )
    .bind(webhook_id)
    .bind(owner_user_id)
    .bind(event_type)
    .bind(payload)
    .bind(status)
    .bind(http_status)
    .bind(error)
    .bind(retry_count)
    .bind(delivered_at)
    .execute(pool)
    .await?;
    Ok(())
}

/// POST signed JSON to the subscriber URL, retry on transport / non-success HTTP, persist one audit row.
#[allow(clippy::too_many_arguments, unreachable_code)]
pub(crate) async fn deliver_outbound_event(
    http: &reqwest::Client,
    pool: &PgPool,
    webhook_id: Uuid,
    owner_user_id: Uuid,
    url: &str,
    secret: &str,
    event_type: &str,
    payload: &Value,
) -> Result<DeliveryAttemptOutcome, sqlx::Error> {
    let body_bytes = match serde_json::to_vec(payload) {
        Ok(b) => b,
        Err(e) => {
            persist_delivery_attempt(
                pool,
                webhook_id,
                owner_user_id,
                event_type,
                payload,
                "failed",
                None,
                Some(&e.to_string()),
                0,
                None,
            )
            .await?;
            return Ok(DeliveryAttemptOutcome {
                delivered: false,
                http_status: None,
                error: Some(e.to_string()),
            });
        }
    };

    let secret_bytes = secret.as_bytes();

    for attempt in 0..MAX_DELIVERY_ATTEMPTS {
        if attempt > 0 {
            let backoff_secs = 1u64 << (attempt - 1);
            tokio::time::sleep(Duration::from_secs(backoff_secs)).await;
        }

        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let signature = sign_toonflow(secret_bytes, ts, &body_bytes);

        let send_res = http
            .post(url)
            .timeout(PER_ATTEMPT_TIMEOUT)
            .header("Content-Type", "application/json")
            .header("X-Toonflow-Timestamp", ts.to_string())
            .header("X-Toonflow-Signature", signature)
            .header("X-Toonflow-Event-Type", event_type)
            .body(body_bytes.clone())
            .send()
            .await;

        match send_res {
            Ok(resp) => {
                let code = resp.status().as_u16();
                if resp.status().is_success() {
                    let retry_count = attempt as i32;
                    persist_delivery_attempt(
                        pool,
                        webhook_id,
                        owner_user_id,
                        event_type,
                        payload,
                        "success",
                        Some(code as i32),
                        None,
                        retry_count,
                        Some(chrono::Utc::now()),
                    )
                    .await?;
                    return Ok(DeliveryAttemptOutcome {
                        delivered: true,
                        http_status: Some(code),
                        error: None,
                    });
                }
                let err = Some(format!("HTTP {code}"));
                let terminal = attempt + 1 == MAX_DELIVERY_ATTEMPTS;
                if terminal {
                    persist_delivery_attempt(
                        pool,
                        webhook_id,
                        owner_user_id,
                        event_type,
                        payload,
                        "failed",
                        Some(code as i32),
                        err.as_deref(),
                        attempt as i32,
                        None,
                    )
                    .await?;
                    return Ok(DeliveryAttemptOutcome {
                        delivered: false,
                        http_status: Some(code),
                        error: err,
                    });
                }
            }
            Err(e) => {
                let err = Some(e.to_string());
                let terminal = attempt + 1 == MAX_DELIVERY_ATTEMPTS;
                if terminal {
                    persist_delivery_attempt(
                        pool,
                        webhook_id,
                        owner_user_id,
                        event_type,
                        payload,
                        "failed",
                        None,
                        err.as_deref(),
                        attempt as i32,
                        None,
                    )
                    .await?;
                    return Ok(DeliveryAttemptOutcome {
                        delivered: false,
                        http_status: None,
                        error: err,
                    });
                }
            }
        }
    }

    unreachable!("delivery loop always returns")
}

/// After terminal job status (`succeeded` → `job.completed`, `failed` → `job.failed`), notify matching outbound hooks.
pub(crate) async fn fire_job_terminal_outbound_webhooks(
    pool: &PgPool,
    http: &reqwest::Client,
    owner_user_id: Uuid,
    job_workspace_id: Option<Uuid>,
    job_json: Value,
    event_type: &str,
) -> Result<(), sqlx::Error> {
    if event_type != "job.completed" && event_type != "job.failed" {
        return Ok(());
    }

    let payload = json!({
        "id": Uuid::new_v4().to_string(),
        "type": event_type,
        "createdAt": chrono::Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true),
        "data": { "job": job_json }
    });

    let rows = sqlx::query_as::<_, (Uuid, String, String, Option<Uuid>, Value)>(
        r#"
        SELECT id, url, secret, workspace_id, event_types
        FROM public.app_outbound_webhook
        WHERE owner_user_id = $1 AND enabled = true
        "#,
    )
    .bind(owner_user_id)
    .fetch_all(pool)
    .await?;

    for (wh_id, url, secret, wh_ws, et_val) in rows {
        if !webhook_matches_workspace(wh_ws, job_workspace_id) {
            continue;
        }
        let event_types: Vec<String> = serde_json::from_value(et_val).unwrap_or_default();
        if !webhook_subscribes_event(&event_types, event_type) {
            continue;
        }
        if let Err(e) = deliver_outbound_event(
            http,
            pool,
            wh_id,
            owner_user_id,
            &url,
            &secret,
            event_type,
            &payload,
        )
        .await
        {
            tracing::warn!(
                error = %e,
                webhook_id = %wh_id,
                event_type,
                "outbound webhook delivery persistence failed"
            );
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn workspace_match_all_jobs_when_hook_unscoped() {
        assert!(webhook_matches_workspace(None, None));
        assert!(webhook_matches_workspace(None, Some(Uuid::new_v4())));
    }

    #[test]
    fn workspace_match_only_same_workspace() {
        let ws = Uuid::new_v4();
        assert!(webhook_matches_workspace(Some(ws), Some(ws)));
        assert!(!webhook_matches_workspace(Some(ws), None));
        assert!(!webhook_matches_workspace(Some(ws), Some(Uuid::new_v4())));
    }

    #[test]
    fn subscribes_empty_means_all() {
        assert!(webhook_subscribes_event(&[], "job.completed"));
    }

    #[test]
    fn subscribes_explicit() {
        let v = vec!["job.failed".to_string()];
        assert!(!webhook_subscribes_event(&v, "job.completed"));
        assert!(webhook_subscribes_event(&v, "job.failed"));
    }
}
