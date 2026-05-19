//! Harness user WASM alert evaluation, notification writes, and outbound webhooks (WP-C).

use chrono::{DateTime, Utc};
use reqwest::Client;
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use std::sync::OnceLock;
use uuid::Uuid;

use crate::settings::notifications::{record_notification, NotificationRecordPayload};
use crate::state::AppState;
use std::sync::Arc;
use std::time::Duration;

const DEFAULT_VALIDATE_FAIL_RATE: f64 = 0.1;
const DEFAULT_INVOKE_FAIL_RATE: f64 = 0.1;
const DEFAULT_FUEL_EXHAUSTION_RATE: f64 = 0.2;
const DEFAULT_WINDOW_SECS: u64 = 300;
const DEFAULT_MIN_EVENTS: u64 = 5;

static CONFIG_LOGGED: OnceLock<()> = OnceLock::new();

/// Resolved alert thresholds and dispatch targets (read from environment at startup).
#[derive(Debug, Clone)]
pub struct WasmAlertConfig {
    pub validate_fail_rate_threshold: f64,
    pub invoke_fail_rate_threshold: f64,
    pub fuel_exhaustion_rate_threshold: f64,
    pub window_secs: u64,
    pub min_events: u64,
    pub webhook_url: Option<String>,
    pub ops_user_id: Option<Uuid>,
}

#[derive(Debug)]
pub enum AlertError {
    Database(sqlx::Error),
}

impl std::fmt::Display for AlertError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Database(e) => write!(f, "database error: {e}"),
        }
    }
}

impl std::error::Error for AlertError {}

impl From<sqlx::Error> for AlertError {
    fn from(value: sqlx::Error) -> Self {
        Self::Database(value)
    }
}

#[derive(Debug, Clone, Copy)]
struct SignalSpec {
    name: &'static str,
    threshold: fn(&WasmAlertConfig) -> f64,
    metric: AlertMetric,
}

#[derive(Debug, Clone, Copy)]
enum AlertMetric {
    /// Denominator: all `event = invoke` rows; numerator: rows with this `signal_name`.
    InvokeFailures { failure_signal: &'static str },
    /// `event = validate` success/fail ratio.
    ValidateOutcomes,
    /// Denominator: `event = persist`; numerator: `signal_name = object_store_put_fail`.
    ObjectStorePutFails,
}

const SIGNALS: &[SignalSpec] = &[
    SignalSpec {
        name: "invoke_wasm_failed",
        threshold: |c| c.invoke_fail_rate_threshold,
        metric: AlertMetric::InvokeFailures {
            failure_signal: "invoke_wasm_failed",
        },
    },
    SignalSpec {
        name: "invoke_wasm_timeout",
        threshold: |c| c.fuel_exhaustion_rate_threshold,
        metric: AlertMetric::InvokeFailures {
            failure_signal: "invoke_wasm_timeout",
        },
    },
    SignalSpec {
        name: "object_store_put_fail",
        threshold: |c| c.validate_fail_rate_threshold,
        metric: AlertMetric::ObjectStorePutFails,
    },
    SignalSpec {
        name: "validate",
        threshold: |c| c.validate_fail_rate_threshold,
        metric: AlertMetric::ValidateOutcomes,
    },
];

impl WasmAlertConfig {
    pub fn from_env() -> Self {
        let cfg = Self {
            validate_fail_rate_threshold: parse_rate_threshold(
                "HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE",
                DEFAULT_VALIDATE_FAIL_RATE,
            ),
            invoke_fail_rate_threshold: parse_rate_threshold(
                "HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE",
                DEFAULT_INVOKE_FAIL_RATE,
            ),
            fuel_exhaustion_rate_threshold: parse_rate_threshold(
                "HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE",
                DEFAULT_FUEL_EXHAUSTION_RATE,
            ),
            window_secs: parse_positive_u64(
                "HARNESS_USER_WASM_ALERT_WINDOW_SECS",
                DEFAULT_WINDOW_SECS,
            ),
            min_events: parse_positive_u64(
                "HARNESS_USER_WASM_ALERT_MIN_EVENTS",
                DEFAULT_MIN_EVENTS,
            ),
            webhook_url: std::env::var("HARNESS_ALERT_WEBHOOK_URL")
                .ok()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty()),
            ops_user_id: std::env::var("HARNESS_ALERT_OPS_USER_ID")
                .ok()
                .and_then(|s| Uuid::parse_str(s.trim()).ok()),
        };
        cfg.log_resolved_once();
        cfg
    }

    pub fn log_resolved_once(&self) {
        CONFIG_LOGGED.get_or_init(|| {
            tracing::info!(
                event = "harness_alert_config_resolved",
                validate_fail_rate_threshold = self.validate_fail_rate_threshold,
                invoke_fail_rate_threshold = self.invoke_fail_rate_threshold,
                fuel_exhaustion_rate_threshold = self.fuel_exhaustion_rate_threshold,
                window_secs = self.window_secs,
                min_events = self.min_events,
                webhook_configured = self.webhook_url.is_some(),
                ops_user_id = ?self.ops_user_id,
                "harness wasm alert config resolved"
            );
        });
    }

    fn notification_user_id(&self) -> Uuid {
        self.ops_user_id.unwrap_or(Uuid::nil())
    }
}

fn parse_rate_threshold(name: &str, default: f64) -> f64 {
    match std::env::var(name) {
        Ok(raw) => match raw.trim().parse::<f64>() {
            Ok(v) if (0.0..=1.0).contains(&v) => v,
            _ => {
                tracing::warn!(
                    event = "harness_alert_config_invalid",
                    env_var = name,
                    value = %raw.trim(),
                    "invalid rate threshold; using default"
                );
                default
            }
        },
        Err(_) => default,
    }
}

fn parse_positive_u64(name: &str, default: u64) -> u64 {
    match std::env::var(name) {
        Ok(raw) => match raw.trim().parse::<u64>() {
            Ok(v) if v > 0 => v,
            _ => {
                tracing::warn!(
                    event = "harness_alert_config_invalid",
                    env_var = name,
                    value = %raw.trim(),
                    "invalid positive integer; using default"
                );
                default
            }
        },
        Err(_) => default,
    }
}

#[derive(Debug, Clone)]
struct SignalCounts {
    total: i64,
    failures: i64,
}

impl SignalCounts {
    fn observed_rate(&self) -> f64 {
        if self.total <= 0 {
            return 0.0;
        }
        self.failures as f64 / self.total as f64
    }
}

async fn fetch_signal_counts(
    pool: &PgPool,
    window_secs: u64,
    spec: &SignalSpec,
) -> Result<SignalCounts, sqlx::Error> {
    let row: (i64, i64) = match spec.metric {
        AlertMetric::InvokeFailures { failure_signal } => {
            sqlx::query_as(
                r#"
            SELECT
              COUNT(*)::bigint AS total,
              COUNT(*) FILTER (WHERE signal_name = $2)::bigint AS failures
            FROM public.app_harness_user_wasm_audit
            WHERE created_at >= NOW() - ($1::bigint * INTERVAL '1 second')
              AND event = 'invoke'
            "#,
            )
            .bind(window_secs as i64)
            .bind(failure_signal)
            .fetch_one(pool)
            .await?
        }
        AlertMetric::ValidateOutcomes => {
            sqlx::query_as(
                r#"
            SELECT
              COUNT(*)::bigint AS total,
              COUNT(*) FILTER (WHERE outcome = 'fail')::bigint AS failures
            FROM public.app_harness_user_wasm_audit
            WHERE created_at >= NOW() - ($1::bigint * INTERVAL '1 second')
              AND event = 'validate'
            "#,
            )
            .bind(window_secs as i64)
            .fetch_one(pool)
            .await?
        }
        AlertMetric::ObjectStorePutFails => {
            sqlx::query_as(
                r#"
            SELECT
              COUNT(*) FILTER (WHERE event = 'persist')::bigint AS total,
              COUNT(*) FILTER (WHERE signal_name = 'object_store_put_fail')::bigint AS failures
            FROM public.app_harness_user_wasm_audit
            WHERE created_at >= NOW() - ($1::bigint * INTERVAL '1 second')
              AND (event = 'persist' OR signal_name = 'object_store_put_fail')
            "#,
            )
            .bind(window_secs as i64)
            .fetch_one(pool)
            .await?
        }
    };
    Ok(SignalCounts {
        total: row.0,
        failures: row.1,
    })
}

async fn find_active_alert_id(
    pool: &PgPool,
    ops_user_id: Uuid,
    signal_name: &str,
) -> Result<Option<i64>, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT id
        FROM public.app_notification
        WHERE notification_type = 'harness_wasm_alert'
          AND read_at IS NULL
          AND user_id = $1
          AND payload->>'signal_name' = $2
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(ops_user_id)
    .bind(signal_name)
    .fetch_optional(pool)
    .await
}

fn alert_payload(
    signal_name: &str,
    threshold: f64,
    observed_rate: f64,
    config: &WasmAlertConfig,
    resolved_at: Option<DateTime<Utc>>,
) -> serde_json::Value {
    let mut payload = json!({
        "signal_name": signal_name,
        "threshold": threshold,
        "observed_rate": observed_rate,
        "window_secs": config.window_secs,
        "min_events": config.min_events,
    });
    if let Some(at) = resolved_at {
        payload["resolved_at"] = json!(at.to_rfc3339());
    }
    payload
}

async fn write_alert_notification(
    pool: &PgPool,
    config: &WasmAlertConfig,
    signal_name: &str,
    threshold: f64,
    observed_rate: f64,
    cleared: bool,
) {
    let notification_type = if cleared {
        "harness_wasm_alert_cleared"
    } else {
        "harness_wasm_alert"
    };
    let resolved_at = cleared.then(Utc::now);
    let payload = alert_payload(signal_name, threshold, observed_rate, config, resolved_at);
    let title = if cleared {
        format!("Harness WASM alert cleared: {signal_name}")
    } else {
        format!("Harness WASM alert: {signal_name}")
    };
    let message = if cleared {
        format!(
            "Observed rate {observed_rate:.3} dropped below threshold {threshold:.3} (window {}s)",
            config.window_secs
        )
    } else {
        format!(
            "Observed rate {observed_rate:.3} exceeded threshold {threshold:.3} (window {}s, min events {})",
            config.window_secs, config.min_events
        )
    };

    if !cleared {
        if let Ok(Some(existing_id)) =
            find_active_alert_id(pool, config.notification_user_id(), signal_name).await
        {
            let update = sqlx::query(
                r#"
                UPDATE public.app_notification
                SET title = $1,
                    message = $2,
                    payload = $3,
                    updated_at = NOW()
                WHERE id = $4
                "#,
            )
            .bind(&title)
            .bind(&message)
            .bind(payload)
            .bind(existing_id)
            .execute(pool)
            .await;

            if let Err(e) = update {
                tracing::error!(
                    event = "harness_alert_notification_write_failed",
                    signal_name,
                    error = %e,
                    "failed to update deduplicated harness alert notification"
                );
            }
            return;
        }
    }

    let entry = NotificationRecordPayload {
        user_id: config.notification_user_id(),
        workspace_id: None,
        project_id: None,
        project_numeric_id: None,
        job_id: None,
        notification_type: notification_type.to_string(),
        title,
        message,
        link_path: None,
        payload,
        file_path: None,
        changed_at: resolved_at,
    };

    if let Err(e) = record_notification(pool, None, entry).await {
        tracing::error!(
            event = "harness_alert_notification_write_failed",
            signal_name,
            error = ?e,
            "failed to write harness alert notification"
        );
    }
}

#[derive(Serialize)]
struct AlertWebhookPayload {
    event: &'static str,
    signal_name: String,
    threshold: f64,
    observed_rate: f64,
    window_secs: u64,
    fired_at: DateTime<Utc>,
    environment: String,
}

fn otel_environment_name() -> String {
    std::env::var("OTEL_SERVICE_NAME")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "openflow-server".to_string())
}

fn redact_webhook_url_for_log(url: &str) -> String {
    url::Url::parse(url)
        .map(|u| {
            let scheme = u.scheme();
            if let Some(host) = u.host_str() {
                format!("{scheme}://{host}")
            } else {
                scheme.to_string()
            }
        })
        .unwrap_or_else(|_| "<invalid-url>".to_string())
}

pub fn dispatch_webhook(
    client: Client,
    url: String,
    event: &'static str,
    signal_name: &str,
    threshold: f64,
    observed_rate: f64,
    window_secs: u64,
) {
    let payload = AlertWebhookPayload {
        event,
        signal_name: signal_name.to_string(),
        threshold,
        observed_rate,
        window_secs,
        fired_at: Utc::now(),
        environment: otel_environment_name(),
    };
    tokio::spawn(async move {
        let result = client
            .post(&url)
            .header("Content-Type", "application/json")
            .json(&payload)
            .timeout(std::time::Duration::from_secs(5))
            .send()
            .await;

        match result {
            Ok(resp) if resp.status().is_success() => {}
            Ok(resp) => {
                tracing::warn!(
                    event = "harness_alert_webhook_failed",
                    status_code = resp.status().as_u16(),
                    url = %redact_webhook_url_for_log(&url),
                    "harness alert webhook returned non-2xx"
                );
            }
            Err(e) => {
                tracing::warn!(
                    event = "harness_alert_webhook_failed",
                    url = %redact_webhook_url_for_log(&url),
                    error = %e,
                    "harness alert webhook request failed"
                );
            }
        }
    });
}

/// Evaluate rolling-window signal rates, write notifications, and optionally fire webhooks.
pub async fn evaluate_and_notify(
    config: &WasmAlertConfig,
    pool: &PgPool,
    http_client: &Client,
) -> Result<(), AlertError> {
    for spec in SIGNALS {
        let counts = fetch_signal_counts(pool, config.window_secs, spec).await?;
        if (counts.total as u64) < config.min_events {
            continue;
        }

        let threshold = (spec.threshold)(config);
        let observed_rate = counts.observed_rate();
        let breached = observed_rate >= threshold;
        let has_active = find_active_alert_id(pool, config.notification_user_id(), spec.name)
            .await?
            .is_some();

        if breached {
            write_alert_notification(pool, config, spec.name, threshold, observed_rate, false)
                .await;
            if let Some(url) = config.webhook_url.clone() {
                dispatch_webhook(
                    http_client.clone(),
                    url,
                    "harness_wasm_alert",
                    spec.name,
                    threshold,
                    observed_rate,
                    config.window_secs,
                );
            }
        } else if has_active {
            write_alert_notification(pool, config, spec.name, threshold, observed_rate, true).await;
            if let Some(url) = config.webhook_url.clone() {
                dispatch_webhook(
                    http_client.clone(),
                    url,
                    "harness_wasm_alert_cleared",
                    spec.name,
                    threshold,
                    observed_rate,
                    config.window_secs,
                );
            }
        }
    }
    Ok(())
}

/// Interval in seconds for background [`evaluate_and_notify`] (`0` = disabled). Default **60**.
pub fn harness_alert_eval_interval_secs() -> u64 {
    std::env::var("HARNESS_USER_WASM_ALERT_EVAL_INTERVAL_SECS")
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(60)
}

/// Spawn a periodic harness WASM alert evaluator (uses [`AppState::pool`] and HTTP client).
pub fn spawn_harness_alert_eval_task(state: AppState, config: Arc<WasmAlertConfig>) {
    let Some(pool) = state.pool.clone() else {
        return;
    };
    let interval_secs = harness_alert_eval_interval_secs();
    if interval_secs == 0 {
        tracing::info!(
            "harness WASM alert evaluation disabled (HARNESS_USER_WASM_ALERT_EVAL_INTERVAL_SECS=0)"
        );
        return;
    }
    let http = state.http_client.clone();
    tokio::spawn(async move {
        let mut ticker = tokio::time::interval(Duration::from_secs(interval_secs));
        loop {
            ticker.tick().await;
            if let Err(e) = evaluate_and_notify(&config, &pool, &http).await {
                tracing::warn!(
                    error = %e,
                    "harness WASM alert evaluate_and_notify failed"
                );
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;
    use std::sync::Mutex;

    static ENV_MUTEX: Mutex<()> = Mutex::new(());

    fn clear_alert_env() {
        for key in [
            "HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE",
            "HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE",
            "HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE",
            "HARNESS_USER_WASM_ALERT_WINDOW_SECS",
            "HARNESS_USER_WASM_ALERT_MIN_EVENTS",
            "HARNESS_ALERT_WEBHOOK_URL",
            "HARNESS_ALERT_OPS_USER_ID",
        ] {
            std::env::remove_var(key);
        }
    }

    // Feature: harness-observability-hardening, Property 1: 告警阈值配置回落不变量
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(100))]
        #[test]
        fn prop_alert_rate_threshold_invalid_falls_back(raw in "-?[0-9]*\\.?[0-9]*[a-zA-Z]*") {
            let _g = ENV_MUTEX.lock().expect("lock");
            clear_alert_env();
            std::env::set_var("HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE", &raw);
            let cfg = WasmAlertConfig::from_env();
            prop_assert!((0.0..=1.0).contains(&cfg.validate_fail_rate_threshold));
            if raw.trim().parse::<f64>().ok().filter(|v| (0.0..=1.0).contains(v)).is_none() {
                prop_assert_eq!(cfg.validate_fail_rate_threshold, DEFAULT_VALIDATE_FAIL_RATE);
            }
        }
    }

    #[test]
    fn window_and_min_events_invalid_fall_back() {
        let _g = ENV_MUTEX.lock().expect("lock");
        clear_alert_env();
        std::env::set_var("HARNESS_USER_WASM_ALERT_WINDOW_SECS", "0");
        std::env::set_var("HARNESS_USER_WASM_ALERT_MIN_EVENTS", "-3");
        let cfg = WasmAlertConfig::from_env();
        assert_eq!(cfg.window_secs, DEFAULT_WINDOW_SECS);
        assert_eq!(cfg.min_events, DEFAULT_MIN_EVENTS);
        clear_alert_env();
    }

    #[test]
    fn observed_rate_is_failures_over_total() {
        let counts = SignalCounts {
            total: 10,
            failures: 3,
        };
        assert!((counts.observed_rate() - 0.3).abs() < f64::EPSILON);
    }

    /// Feature: harness-observability-hardening, Task 1.3 — `evaluate_and_notify` respects `min_events`
    /// and fires when failure rate exceeds threshold.
    #[tokio::test]
    async fn evaluate_invokes_respects_min_events_and_threshold() {
        let url = match std::env::var("DATABASE_URL") {
            Ok(u) if !u.trim().is_empty() => u,
            _ => {
                eprintln!("DATABASE_URL not set; skipping evaluate_and_notify integration test");
                return;
            }
        };
        let Ok(pool) = sqlx::postgres::PgPoolOptions::new()
            .max_connections(1)
            .connect(&url)
            .await
        else {
            eprintln!("DATABASE_URL connect failed; skipping evaluate_and_notify integration test");
            return;
        };
        let audit_tbl: Option<String> =
            sqlx::query_scalar("SELECT to_regclass('public.app_harness_user_wasm_audit')::text")
                .fetch_one(&pool)
                .await
                .unwrap_or(None);
        let notif_tbl: Option<String> =
            sqlx::query_scalar("SELECT to_regclass('public.app_notification')::text")
                .fetch_one(&pool)
                .await
                .unwrap_or(None);
        if audit_tbl.is_none()
            || audit_tbl.as_deref() == Some("")
            || notif_tbl.is_none()
            || notif_tbl.as_deref() == Some("")
        {
            eprintln!("required tables missing; skipping evaluate_and_notify integration test");
            return;
        }

        let test_uid = Uuid::new_v4();
        {
            let _g = ENV_MUTEX.lock().expect("lock");
            clear_alert_env();
            std::env::set_var("HARNESS_ALERT_OPS_USER_ID", test_uid.to_string());
            std::env::set_var("HARNESS_USER_WASM_ALERT_MIN_EVENTS", "5");
            std::env::set_var("HARNESS_USER_WASM_ALERT_WINDOW_SECS", "300");
            std::env::set_var("HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE", "0.1");
        }
        let cfg = WasmAlertConfig::from_env();
        let client = reqwest::Client::new();

        sqlx::query("DELETE FROM public.app_harness_user_wasm_audit WHERE user_id = $1")
            .bind(test_uid)
            .execute(&pool)
            .await
            .ok();
        sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
            .bind(test_uid)
            .execute(&pool)
            .await
            .ok();

        for _ in 0..3 {
            sqlx::query(
                r#"INSERT INTO public.app_harness_user_wasm_audit
                (event, user_id, outcome, signal_name)
                VALUES ('invoke', $1, 'fail', 'invoke_wasm_failed')"#,
            )
            .bind(test_uid)
            .execute(&pool)
            .await
            .expect("insert audit");
        }
        evaluate_and_notify(&cfg, &pool, &client)
            .await
            .expect("evaluate");
        let low: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_notification WHERE user_id = $1 AND notification_type = 'harness_wasm_alert'",
        )
        .bind(test_uid)
        .fetch_one(&pool)
        .await
        .unwrap_or(0);
        assert_eq!(low, 0, "below min_events must not alert");

        for _ in 0..4 {
            sqlx::query(
                r#"INSERT INTO public.app_harness_user_wasm_audit
                (event, user_id, outcome, signal_name)
                VALUES ('invoke', $1, 'success', NULL)"#,
            )
            .bind(test_uid)
            .execute(&pool)
            .await
            .expect("insert success invoke audit");
        }
        for _ in 0..3 {
            sqlx::query(
                r#"INSERT INTO public.app_harness_user_wasm_audit
                (event, user_id, outcome, signal_name)
                VALUES ('invoke', $1, 'fail', 'invoke_wasm_failed')"#,
            )
            .bind(test_uid)
            .execute(&pool)
            .await
            .expect("insert fail invoke audit");
        }
        evaluate_and_notify(&cfg, &pool, &client)
            .await
            .expect("evaluate 2");
        let high: i64 = sqlx::query_scalar(
            "SELECT COUNT(*)::bigint FROM public.app_notification WHERE user_id = $1 AND notification_type = 'harness_wasm_alert'",
        )
        .bind(test_uid)
        .fetch_one(&pool)
        .await
        .unwrap_or(0);
        assert!(high >= 1, "expected harness_wasm_alert notification");

        sqlx::query("DELETE FROM public.app_harness_user_wasm_audit WHERE user_id = $1")
            .bind(test_uid)
            .execute(&pool)
            .await
            .ok();
        sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
            .bind(test_uid)
            .execute(&pool)
            .await
            .ok();

        let _g = ENV_MUTEX.lock().expect("lock");
        clear_alert_env();
    }
}
