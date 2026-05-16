# Requirements Document

## Introduction

本 spec 覆盖 **harness-observability-hardening** 功能，对应路线图 `roadmap-backend-harness.md` 中 **WP-C 剩余**（跨环境告警编排与自动化）与 **WP-F 剩余**（采样率 / PII 白名单）两个工作包。

当前已落地的基础设施：
- 用户上传 WASM 全链路（`validate_user_wasm_upload`、REST CRUD、WS `wasm.user.probe`、fuel/超时保护、`HARNESS_USER_WASM_DISABLED`、审计表 `app_harness_user_wasm_audit`、`harness_user_wasm_signal` 告警信号）
- OTel gRPC traces（`TOONFLOW_OTEL_EXPORT_ENABLED`、`OTEL_EXPORTER_OTLP_*`、`telemetry::init_tracing_subscriber`、单测）

本 spec 在上述基础上补齐：
1. **WP-C 剩余**：告警阈值配置、通知写入 `app_notification`、出站 webhook、运行手册
2. **WP-F 剩余**：可配置采样率、PII 脱敏与字段白名单、统一 span/baggage 约定、jobs/worker 关联 `job_id` 到 trace

---

## Glossary

- **Alert_Evaluator**：后台定期评估 `harness_user_wasm_signal` 信号聚合结果并触发告警的组件（复用现有 `observe.rs` 信号路径）。
- **Notification_Writer**：将告警写入 `app_notification` 表的 Rust 模块（复用 `settings/notifications/storage.rs` 中的 `record_notification`）。
- **Webhook_Dispatcher**：向 `HARNESS_ALERT_WEBHOOK_URL` 发送出站 HTTP POST 的组件。
- **Telemetry_Module**：`backend/src/telemetry.rs` 及其初始化逻辑。
- **Span_Propagator**：负责在 harness session / tool invoke / job 之间透传 W3C `traceparent` 的机制（基于现有 `observe::TraceContext`）。
- **PII_Filter**：在 span attribute 写入前过滤敏感字段的组件。
- **Sampler**：根据 `TOONFLOW_OTEL_SAMPLE_RATE` 决定是否导出当前 span 的采样逻辑。
- **Runbook**：`docs/plans/harness-wasm-alert-runbook.md`，描述各告警级别响应步骤的运维文档。
- **app_notification**：现有通知中心数据库表，字段含 `user_id`、`workspace_id`、`notification_type`、`title`、`message`、`payload`、`read_at` 等。
- **harness_user_wasm_signal**：现有结构化日志事件，字段含 `signal_name`、`user_id`、`workspace_id`、`request_id`、`wasm_id`、`outcome`、`error_code`。
- **HARNESS_ALERT_WEBHOOK_URL**：可选环境变量，配置后 Alert_Evaluator 在阈值触发时向该 URL 发送出站 webhook。
- **TOONFLOW_OTEL_SAMPLE_RATE**：0.0–1.0 浮点数，控制 OTel span 采样率；prod 环境须非零，staging 可设 1.0。
- **PII_Allowlist**：span attribute 白名单，仅白名单内字段可落入 trace；`user_id` 在白名单内，其余 PII 字段默认不落 trace。

---

## Requirements

### Requirement 1：告警阈值配置

**User Story：** As an operator, I want to configure alert thresholds via environment variables, so that I can tune sensitivity per environment without code changes.

#### Acceptance Criteria

1. THE Alert_Evaluator SHALL read `HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE` as a float in [0.0, 1.0] representing the validate-failure-rate threshold (default 0.1).
2. THE Alert_Evaluator SHALL read `HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE` as a float in [0.0, 1.0] representing the invoke-failure-rate threshold (default 0.1).
3. THE Alert_Evaluator SHALL read `HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE` as a float in [0.0, 1.0] representing the fuel-exhaustion-rate threshold (default 0.2).
4. THE Alert_Evaluator SHALL read `HARNESS_USER_WASM_ALERT_WINDOW_SECS` as a positive integer representing the rolling evaluation window in seconds (default 300).
5. THE Alert_Evaluator SHALL read `HARNESS_USER_WASM_ALERT_MIN_EVENTS` as a positive integer representing the minimum event count required before threshold evaluation fires (default 5).
6. IF any of the three threshold environment variables contains a value outside [0.0, 1.0] or is unparseable, THEN THE Alert_Evaluator SHALL log a structured warning with `event=harness_alert_config_invalid` and fall back to the default value.
7. IF `HARNESS_USER_WASM_ALERT_WINDOW_SECS` or `HARNESS_USER_WASM_ALERT_MIN_EVENTS` contains a non-positive or unparseable value, THEN THE Alert_Evaluator SHALL log a structured warning with `event=harness_alert_config_invalid` and fall back to the default value.
8. THE Alert_Evaluator SHALL expose the resolved threshold configuration at startup via a structured log event `event=harness_alert_config_resolved` containing all five resolved values.

---

### Requirement 2：告警通知写入 app_notification

**User Story：** As an operator, I want alert threshold breaches to appear in the notification center, so that I can track harness health without querying logs directly.

#### Acceptance Criteria

1. WHEN the Alert_Evaluator determines that a threshold is breached within the evaluation window, THE Notification_Writer SHALL insert a row into `app_notification` with `notification_type = 'harness_wasm_alert'`.
2. THE Notification_Writer SHALL populate the `app_notification` row with `title` describing the signal name and threshold, `message` containing the observed rate and window, and `payload` containing `signal_name`, `threshold`, `observed_rate`, `window_secs`, and `min_events`.
3. THE Notification_Writer SHALL set `user_id` on the `app_notification` row to the system operator sentinel value (NULL or a configured ops user UUID via `HARNESS_ALERT_OPS_USER_ID`) and `workspace_id` to NULL when the alert is workspace-agnostic.
4. WHEN a threshold breach is resolved (observed rate drops below threshold for one full window), THE Notification_Writer SHALL insert a row with `notification_type = 'harness_wasm_alert_cleared'` containing the same `payload` fields plus `resolved_at`.
5. IF the `app_notification` insert fails, THEN THE Notification_Writer SHALL log a structured error with `event=harness_alert_notification_write_failed` and SHALL NOT propagate the error to the main harness execution path.
6. THE Notification_Writer SHALL reuse the existing `record_notification` function from `settings/notifications/storage.rs` rather than issuing raw SQL.
7. WHILE the Alert_Evaluator is running, THE Notification_Writer SHALL deduplicate active alerts: if an unresolved `harness_wasm_alert` row already exists for the same `signal_name`, THE Notification_Writer SHALL update the existing row's `updated_at` and `payload` rather than inserting a duplicate.

---

### Requirement 3：出站 Webhook 通知

**User Story：** As an operator, I want threshold breaches to optionally trigger an outbound webhook, so that I can integrate with external alerting systems (PagerDuty, Slack, etc.).

#### Acceptance Criteria

1. WHERE `HARNESS_ALERT_WEBHOOK_URL` is configured, WHEN a threshold breach is detected, THE Webhook_Dispatcher SHALL send an HTTP POST to the configured URL within 5 seconds of detection.
2. THE Webhook_Dispatcher SHALL include a JSON body with fields: `event` (`harness_wasm_alert` or `harness_wasm_alert_cleared`), `signal_name`, `threshold`, `observed_rate`, `window_secs`, `fired_at` (ISO 8601 UTC), and `environment` (value of `OTEL_SERVICE_NAME` or `toonflow-server`).
3. THE Webhook_Dispatcher SHALL set the `Content-Type: application/json` header on all outbound webhook requests.
4. IF the outbound webhook HTTP request fails or returns a non-2xx status, THEN THE Webhook_Dispatcher SHALL log a structured warning with `event=harness_alert_webhook_failed`, `status_code`, and `url` (redacted to scheme+host only), and SHALL NOT retry automatically in the same evaluation cycle.
5. IF `HARNESS_ALERT_WEBHOOK_URL` is not configured, THEN THE Webhook_Dispatcher SHALL skip the outbound call silently without logging a warning.
6. THE Webhook_Dispatcher SHALL complete the outbound call in a non-blocking async task so that alert evaluation latency is not affected by webhook response time.

---

### Requirement 4：运行手册（Runbook）

**User Story：** As an on-call engineer, I want a runbook describing response steps for each alert level, so that I can resolve harness incidents consistently.

#### Acceptance Criteria

1. THE system SHALL provide a runbook file at `docs/plans/harness-wasm-alert-runbook.md`.
2. THE Runbook SHALL document the three alert signal names (`invoke_wasm_failed`, `invoke_wasm_timeout`, `object_store_put_fail`) with their default thresholds, evaluation window, and severity level.
3. THE Runbook SHALL provide step-by-step response procedures for each alert level: investigation queries (log filter syntax), mitigation actions (environment variable adjustments, kill-switch usage), and escalation criteria.
4. THE Runbook SHALL document the `HARNESS_USER_WASM_DISABLED` kill-switch and the `HARNESS_WASM_PROBE_DISABLED` kill-switch with their effect and rollback procedure.
5. THE Runbook SHALL include the log query templates from `harness-user-wasm-threat-model.md` (5-minute window TopN and deduplicated request count variants) adapted for the three primary signals.
6. THE Runbook SHALL document the `app_notification` notification types (`harness_wasm_alert`, `harness_wasm_alert_cleared`) and how to query them for audit purposes.

---

### Requirement 5：可配置 OTel 采样率

**User Story：** As an operator, I want to configure the OTel trace sampling rate per environment, so that I can reduce trace volume in production while keeping full fidelity in staging.

#### Acceptance Criteria

1. THE Telemetry_Module SHALL read `TOONFLOW_OTEL_SAMPLE_RATE` as a float in (0.0, 1.0] when `TOONFLOW_OTEL_EXPORT_ENABLED` is truthy.
2. IF `TOONFLOW_OTEL_SAMPLE_RATE` is absent or unparseable, THEN THE Telemetry_Module SHALL default to 1.0 (sample all spans).
3. IF `TOONFLOW_OTEL_SAMPLE_RATE` is set to 0.0 or a negative value, THEN THE Telemetry_Module SHALL log a structured warning with `event=otel_sample_rate_invalid` and use 0.01 as the minimum effective rate to prevent silent trace blackout in production.
4. WHEN `TOONFLOW_OTEL_EXPORT_ENABLED` is truthy, THE Telemetry_Module SHALL configure the OTel SDK `SdkTracerProvider` with a `TraceIdRatioBased` sampler using the resolved sample rate.
5. THE Telemetry_Module SHALL log the resolved sample rate at startup via `event=otel_sample_rate_resolved` when OTel export is enabled.
6. WHEN `TOONFLOW_OTEL_EXPORT_ENABLED` is falsy, THE Telemetry_Module SHALL ignore `TOONFLOW_OTEL_SAMPLE_RATE` entirely.

---

### Requirement 6：PII 脱敏与 Span Attribute 白名单

**User Story：** As a privacy officer, I want sensitive PII fields to be excluded from OTel traces by default, so that trace data does not contain personal information beyond what is explicitly allowed.

#### Acceptance Criteria

1. THE PII_Filter SHALL define a compile-time allowlist of span attribute keys that may be recorded in traces; the allowlist SHALL include `user_id`, `workspace_id`, `request_id`, `job_id`, `wasm_id`, `signal_name`, `tool_name`, `event`, `outcome`, `error_code`, `kind`, `phase`, `worker_id`.
2. WHEN a span attribute key is not in the PII_Allowlist, THE PII_Filter SHALL replace the attribute value with the literal string `[redacted]` before the attribute is recorded.
3. THE PII_Filter SHALL treat attribute keys case-insensitively when matching against the allowlist.
4. THE PII_Filter SHALL NOT redact attribute keys whose names contain only non-PII technical metadata (e.g., `http.method`, `http.status_code`, `db.system`, `net.peer.name`, `otel.status_code`); these SHALL be added to the allowlist as a separate technical-metadata group.
5. IF a span attribute value is a structured JSON string, THEN THE PII_Filter SHALL redact the entire value as `[redacted:json]` unless the key is in the allowlist.
6. THE PII_Filter SHALL be applied as a layer in the `tracing-opentelemetry` pipeline so that console log output is NOT affected by PII filtering.
7. THE system SHALL provide a unit test verifying that a span attribute with key `email` is redacted and a span attribute with key `user_id` is preserved.

---

### Requirement 7：统一 Tracing Span 与 Baggage 约定

**User Story：** As an SRE, I want harness session, tool invoke, and job operations to carry a consistent trace context, so that I can correlate all events in a single request across the full call chain.

#### Acceptance Criteria

1. WHEN a harness WebSocket session is established via `agent.script.attach` or `agent.production.attach`, THE Span_Propagator SHALL create a root span named `harness.session` with attributes `user_id` and `workspace_id`.
2. WHEN `harness.tool.invoke` is dispatched, THE Span_Propagator SHALL create a child span named `harness.tool.invoke` under the active session span, with attributes `tool_name`, `user_id`, `workspace_id`, and `request_id`.
3. WHEN `wasm.user.probe` is executed, THE Span_Propagator SHALL create a child span named `harness.wasm.invoke` under the active tool invoke span, with attributes `wasm_id`, `user_id`, `outcome`, and `error_code` (if applicable).
4. THE Span_Propagator SHALL propagate the W3C `traceparent` header value through the `TraceContext` struct defined in `harness/observe.rs` so that downstream components can join the same trace.
5. WHEN a harness agent run (`harness.agent.run`) is dispatched, THE Span_Propagator SHALL create a child span named `harness.agent.run` under the session span, with attribute `user_id`.
6. THE Span_Propagator SHALL use the existing `tracing` crate span macros (`tracing::info_span!`, `tracing::instrument`) rather than introducing new global state or new crate dependencies.
7. THE system SHALL provide a unit test verifying that a `harness.tool.invoke` span records the correct parent span ID from an enclosing `harness.session` span.

---

### Requirement 8：jobs/worker 关联 job_id 到 Trace

**User Story：** As an SRE, I want generation job worker spans to carry the job_id, so that I can correlate job execution traces with job queue records.

#### Acceptance Criteria

1. WHEN the jobs/worker claims a row from `app_generation_job`, THE Span_Propagator SHALL create a span named `job.execute` with attributes `job_id`, `kind`, `worker_id`, and `user_id`.
2. THE Span_Propagator SHALL set `job_id` as a span attribute on the `job.execute` span using the UUID string representation of `app_generation_job.id`.
3. WHEN the job completes (success, failure, or cancellation), THE Span_Propagator SHALL record the final `phase` value (`succeeded`, `failed`, `cancelled`) as a span attribute before closing the `job.execute` span.
4. IF `client_request_id` is present in the job payload, THEN THE Span_Propagator SHALL also set it as a span attribute `client_request_id` on the `job.execute` span to enable HTTP-to-job trace correlation.
5. THE Span_Propagator SHALL reuse the existing `log_generation_job_phase` structured log event in `jobs/worker/mod.rs` by adding span instrumentation alongside the existing `tracing::info!` calls, without replacing them.
6. THE system SHALL provide a unit test verifying that a `job.execute` span contains a `job_id` attribute matching the UUID passed to the worker function.

---

### Requirement 9：全栈交付约定合规

**User Story：** As a tech lead, I want all observability changes to comply with the full-stack delivery covenant, so that backend and frontend remain in sync within the same milestone.

#### Acceptance Criteria

1. THE system SHALL ensure that any new environment variables introduced by this spec (`HARNESS_USER_WASM_ALERT_*`, `HARNESS_ALERT_WEBHOOK_URL`, `HARNESS_ALERT_OPS_USER_ID`, `TOONFLOW_OTEL_SAMPLE_RATE`) are documented in `backend/README.md` under the relevant sections.
2. THE system SHALL ensure that the `harness_wasm_alert` and `harness_wasm_alert_cleared` notification types are visible in the existing Flutter notification center UI without requiring a new API endpoint (they use the existing `GET /api/v1/notifications` path).
3. WHERE the alert notification introduces a new `notification_type` value, THE system SHALL ensure the Flutter `rust_api` notification model handles the new type without crashing (graceful unknown-type handling).
4. THE system SHALL ensure that no single modified source file exceeds 800 lines after changes are applied.
5. THE system SHALL ensure that `yarn refactor:agent --full` passes without errors after all changes in this spec are applied.
6. THE system SHALL NOT introduce new global mutable state; all new configuration SHALL be read from environment variables at startup or per-evaluation-cycle.
