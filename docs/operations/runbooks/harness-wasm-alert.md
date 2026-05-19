# Harness user WASM alert runbook

On-call guide for **`harness_user_wasm_signal`** / **`app_harness_user_wasm_audit`** threshold alerts (WP-C).

## Alert signals

| Signal | Default threshold env | Default rate | Window | Severity |
|--------|----------------------|--------------|--------|----------|
| `invoke_wasm_failed` | `HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE` | **0.1** (10%) | **300s** (`HARNESS_USER_WASM_ALERT_WINDOW_SECS`) | **High** |
| `invoke_wasm_timeout` | `HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE` | **0.2** (20%) | **300s** | **Critical** |
| `object_store_put_fail` | `HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE` | **0.1** (10%) | **300s** | **High** |

Minimum events before evaluation: **`HARNESS_USER_WASM_ALERT_MIN_EVENTS`** (default **5**).

Notification types in **`app_notification`**:

- **`harness_wasm_alert`** — threshold breached
- **`harness_wasm_alert_cleared`** — rate below threshold for one full window

Optional outbound webhook: **`HARNESS_ALERT_WEBHOOK_URL`**. Ops user for in-app notifications: **`HARNESS_ALERT_OPS_USER_ID`** (UUID; if unset, sentinel nil UUID).

## Log query templates

Adapt field names to your log platform (Loki / Datadog / CloudWatch Logs Insights).

### 5-minute window TopN (generic)

```text
event="harness_user_wasm_signal"
| stats count() as signal_count by signal_name, error_code
| sort signal_count desc
| limit 20
```

### Deduplicated by request_id

```text
event="harness_user_wasm_signal"
| stats dc(request_id) as uniq_requests by signal_name, error_code
| sort uniq_requests desc
| limit 20
```

### Audit table (Postgres)

```sql
SELECT signal_name, outcome, COUNT(*)
FROM app_harness_user_wasm_audit
WHERE created_at >= NOW() - INTERVAL '5 minutes'
GROUP BY 1, 2
ORDER BY 3 DESC;
```

## Response procedures

### `invoke_wasm_failed` (High)

1. Filter logs: `event=harness_user_wasm_signal signal_name=invoke_wasm_failed outcome=fail`.
2. Check recent deploys / bad WASM uploads (`wasm_failed` error_code).
3. If isolated user: revoke via `DELETE /api/v1/harness/user-wasm/{id}`.
4. If widespread: consider **`HARNESS_USER_WASM_DISABLED=1`** (see kill-switches below).
5. Escalate if failure rate stays above threshold for **2 consecutive windows** or affects production attach flows.

### `invoke_wasm_timeout` (Critical)

1. Filter: `signal_name=invoke_wasm_timeout` or `error_code=wasm_timeout`.
2. Review **`HARNESS_USER_WASM_FUEL_LIMIT`** and **`HARNESS_USER_WASM_INVOKE_TIMEOUT_MS`**.
3. Check worker CPU / isolate pool saturation (`event=harness_isolate_invoke`).
4. Temporarily tighten fuel/timeout or disable user WASM if SLA impact.
5. Escalate immediately if timeouts correlate with object-store fallback storms.

### `object_store_put_fail` (High)

1. Filter: `signal_name=object_store_put_fail`.
2. Verify object-store env vars (`HARNESS_USER_WASM_OBJECT_STORE_*`) — partial config triggers **`object_store_misconfigured`**.
3. Confirm S3/MinIO health; inspect **`database_error`** vs **`object_store_put_failed`** codes.
4. Persist path falls back to Postgres inline bytes; monitor DB size if prolonged.
5. Escalate if put failures block new uploads in multiple workspaces.

## Kill-switches

| Variable | Effect | Rollback |
|----------|--------|----------|
| **`HARNESS_USER_WASM_DISABLED=1`** | Blocks **user-uploaded** WASM (`wasm.user.probe`, REST persist). Built-in **`wasm.probe`** unaffected. | Set to **`0`** / unset; restart process. |
| **`HARNESS_WASM_PROBE_DISABLED=1`** | Blocks built-in **`wasm.probe`** only. | Unset; restart. |

After enabling a kill-switch, confirm alert rates drop within one evaluation window (**`HARNESS_USER_WASM_ALERT_WINDOW_SECS`**).

## Tuning thresholds

Increase rates (less sensitive):

```bash
export HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE=0.2
export HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE=0.35
export HARNESS_USER_WASM_ALERT_MIN_EVENTS=10
```

Decrease window (faster detection):

```bash
export HARNESS_USER_WASM_ALERT_WINDOW_SECS=120
```

Restart **`openflow-server`** after env changes; confirm `event=harness_alert_config_resolved` in startup logs.

## Notification audit queries

```sql
-- Active alerts
SELECT id, title, message, payload, created_at, updated_at
FROM app_notification
WHERE notification_type = 'harness_wasm_alert'
  AND read_at IS NULL
ORDER BY updated_at DESC;

-- Recently cleared
SELECT id, payload->>'signal_name' AS signal_name, payload->>'resolved_at' AS resolved_at, created_at
FROM app_notification
WHERE notification_type = 'harness_wasm_alert_cleared'
ORDER BY created_at DESC
LIMIT 50;
```

Users with **`HARNESS_ALERT_OPS_USER_ID`** see alerts via existing **`GET /api/v1/notifications`** (no new API).
