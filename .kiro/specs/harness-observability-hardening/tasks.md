# Implementation Plan: harness-observability-hardening

## Overview

本实现计划分两个工作包交付：

- **WP-C 剩余**：告警阈值配置、`app_notification` 写入、出站 Webhook、运行手册
- **WP-F 剩余**：可配置 OTel 采样率、PII 脱敏白名单、统一 span/baggage 约定、jobs/worker `job_id` 关联 trace

全栈同里程碑交付，遵循 `full-stack-delivery-covenant.md`。

---

## Tasks

- [x] 1. WP-C：告警配置与评估核心
  - [x] 1.1 新增 `backend/src/harness/alert.rs`（≤400 行）
    - 定义 `WasmAlertConfig` 结构体，实现 `from_env()` 读取 `HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE`（default 0.1）、`HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE`（default 0.1）、`HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE`（default 0.2）、`HARNESS_USER_WASM_ALERT_WINDOW_SECS`（default 300）、`HARNESS_USER_WASM_ALERT_MIN_EVENTS`（default 5）、`HARNESS_ALERT_WEBHOOK_URL`、`HARNESS_ALERT_OPS_USER_ID`
    - 非法值 log `event=harness_alert_config_invalid` 并回落默认值
    - 启动时 log `event=harness_alert_config_resolved` 含所有解析值
    - 实现 `evaluate_and_notify(config, pool, http_client)` 异步函数：查询 `app_harness_user_wasm_audit` 最近 `window_secs` 内各 outcome 计数，计算失败率，与阈值对比
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x]* 1.2 为 `WasmAlertConfig::from_env()` 编写属性测试（Property 1）
    - **Property 1: 告警阈值配置回落不变量**
    - 随机非法阈值字符串，验证解析结果等于默认值
    - **Validates: Requirements 1.6, 1.7**

  - [x]* 1.3 为 `evaluate_and_notify` 编写单元测试
    - 事件数 < `min_events` 时不触发告警
    - 失败率超阈值时触发告警
    - 失败率恢复时写入 `harness_wasm_alert_cleared`
    - _Requirements: 1.5, 2.1, 2.4_

- [x] 2. WP-C：通知写入与去重
  - [x] 2.1 在 `harness/alert.rs` 中实现 `write_alert_notification`
    - 复用 `settings/notifications/storage.rs` 的 `record_notification`
    - `notification_type`：`harness_wasm_alert` 或 `harness_wasm_alert_cleared`
    - `user_id`：`config.ops_user_id`（可 NULL），`workspace_id`：NULL
    - `payload` 含 `signal_name`、`threshold`、`observed_rate`、`window_secs`、`min_events`（cleared 时加 `resolved_at`）
    - 写入失败仅 log `event=harness_alert_notification_write_failed`，不 propagate
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 2.2 实现告警去重逻辑
    - 写入前查询 `app_notification` 中是否存在未读的 `harness_wasm_alert`（同 `signal_name`）
    - 存在则 UPDATE `updated_at` + `payload`，不重复 INSERT
    - _Requirements: 2.7_

- [x] 3. WP-C：出站 Webhook
  - [x] 3.1 在 `harness/alert.rs` 中实现 `dispatch_webhook`
    - `tokio::spawn` 非阻塞执行，不影响评估延迟
    - POST JSON body：`event`、`signal_name`、`threshold`、`observed_rate`、`window_secs`、`fired_at`（ISO 8601 UTC）、`environment`（`OTEL_SERVICE_NAME` 或 `openflow-server`）
    - `Content-Type: application/json`
    - 失败或非 2xx → log `event=harness_alert_webhook_failed`（URL 仅 scheme+host），不重试
    - `HARNESS_ALERT_WEBHOOK_URL` 未配置时静默跳过
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 4. WP-C：运行手册
  - [x] 4.1 新增 `docs/plans/harness-wasm-alert-runbook.md`
    - 三个告警信号（`invoke_wasm_failed`、`invoke_wasm_timeout`、`object_store_put_fail`）的默认阈值、评估窗口、严重级别
    - 每个告警的排查步骤：日志过滤语法、环境变量调整、kill-switch 使用
    - `HARNESS_USER_WASM_DISABLED` 与 `HARNESS_WASM_PROBE_DISABLED` 的效果与回滚
    - `app_notification` 查询模板（`harness_wasm_alert`、`harness_wasm_alert_cleared`）
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 5. Checkpoint — WP-C 验证
  - 确保 `cargo test` 通过，运行 `yarn refactor:agent`，ask the user if questions arise.

- [x] 6. WP-F：可配置 OTel 采样率
  - [x] 6.1 在 `backend/src/telemetry.rs` 中实现 `parse_sample_rate()`
    - 读取 `OPENFLOW_OTEL_SAMPLE_RATE`，解析为 f64
    - 缺失或不可解析 → 默认 1.0
    - 值 ≤ 0.0 → log `event=otel_sample_rate_invalid`，使用 0.01（防止 prod 静默关闭）
    - 值 > 1.0 → log `event=otel_sample_rate_invalid`，使用 1.0
    - `OPENFLOW_OTEL_EXPORT_ENABLED` 为 false 时忽略该变量
    - _Requirements: 5.1, 5.2, 5.3, 5.6_

  - [x] 6.2 在 `init_tracing_subscriber` 中配置 `TraceIdRatioBased` sampler
    - `SdkTracerProvider::builder().with_sampler(Sampler::TraceIdRatioBased(rate))`
    - 启动时 log `event=otel_sample_rate_resolved` 含解析值
    - _Requirements: 5.4, 5.5_

  - [x]* 6.3 为 `parse_sample_rate()` 编写属性测试（Property 2）
    - **Property 2: 采样率边界不变量**
    - 随机输入，验证解析结果 r' 满足 `r' ∈ (0.0, 1.0]`
    - **Validates: Requirements 5.1, 5.2, 5.3**

- [x] 7. WP-F：PII 脱敏与 Span Attribute 白名单
  - [x] 7.1 新增 `backend/src/telemetry/pii_filter.rs`（≤200 行）
    - 定义 `PII_ALLOWLIST: &[&str]`（含业务字段 + 技术元数据组，见 design.md）
    - 实现 `apply_pii_filter(key: &str, value: &str) -> String`：非白名单 key → `[redacted]`，JSON 值 → `[redacted:json]`，大小写不敏感匹配
    - 实现 `PiiFilterLayer`（`tracing::Layer`），在 `on_record` 中过滤非白名单 attribute
    - 仅作用于 OTel exporter layer，不影响 `fmt::Layer`（控制台输出）
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 7.2 在 `telemetry.rs` 中注册 `PiiFilterLayer`
    - OTel 启用时将 `PiiFilterLayer` 加入 `tracing-opentelemetry` pipeline
    - _Requirements: 6.6_

  - [x]* 7.3 为 `PiiFilterLayer` 编写单元测试（Requirement 6.7）
    - `email` key → 值被替换为 `[redacted]`
    - `user_id` key → 值保留不变
    - JSON 值 + 非白名单 key → 替换为 `[redacted:json]`
    - 大小写不敏感：`User_Id` 与 `user_id` 均在白名单
    - _Requirements: 6.7_

  - [x]* 7.4 为 `apply_pii_filter` 编写属性测试（Property 3）
    - **Property 3: PII 过滤白名单不变量**
    - 随机 key/value，验证白名单内 key 值不变，白名单外 key 值被替换
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.5**

- [x] 8. WP-F：统一 Span 约定
  - [x] 8.1 在 `harness/ws/connection.rs` 中添加 `harness.session` span
    - `tracing::info_span!("harness.session", user_id = %user_id, workspace_id = %workspace_id)`
    - _Requirements: 7.1_

  - [x] 8.2 在 `harness/ws/tool.rs` 中添加 `harness.tool.invoke` span
    - `tracing::info_span!("harness.tool.invoke", tool_name = %tool_name, user_id = %user_id, workspace_id = %workspace_id, request_id = %request_id)`
    - _Requirements: 7.2_

  - [x] 8.3 在 `harness/wasm_runtime.rs` 中添加 `harness.wasm.invoke` span
    - `tracing::info_span!("harness.wasm.invoke", wasm_id = %wasm_id, user_id = %user_id)`
    - 执行完成后记录 `outcome` 和 `error_code`（如适用）
    - _Requirements: 7.3_

  - [x] 8.4 在 `harness/ws/agent.rs` 中添加 `harness.agent.run` span
    - `tracing::info_span!("harness.agent.run", user_id = %user_id)`
    - _Requirements: 7.5_

  - [x]* 8.5 为 span 父子关系编写单元测试（Requirement 7.7）
    - 验证 `harness.tool.invoke` span 包含正确的父 span ID（来自 `harness.session`）
    - _Requirements: 7.7_

- [x] 9. WP-F：jobs/worker 关联 job_id 到 Trace
  - [x] 9.1 在 `jobs/worker/mod.rs` 中添加 `job.execute` span
    - `tracing::info_span!("job.execute", job_id = %job.id, kind = %job.kind, worker_id = %worker_id, user_id = %job.user_id)`
    - 在现有 `log_generation_job_phase` 调用旁添加 span instrumentation，不替换现有 `tracing::info!`
    - job 完成时记录 `phase`（`succeeded`/`failed`/`cancelled`）
    - 若 job payload 含 `client_request_id`，添加为 span attribute
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x]* 9.2 为 `job.execute` span 编写单元测试（Requirement 8.6）
    - 验证 span 包含 `job_id` attribute，值等于传入的 UUID
    - _Requirements: 8.6_

- [x] 10. 更新 README 与 Flutter 通知中心兼容性
  - [x] 10.1 在 `backend/README.md` 中补充新增环境变量说明
    - `HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE`、`HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE`、`HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE`、`HARNESS_USER_WASM_ALERT_WINDOW_SECS`、`HARNESS_USER_WASM_ALERT_MIN_EVENTS`
    - `HARNESS_ALERT_WEBHOOK_URL`、`HARNESS_ALERT_OPS_USER_ID`
    - `OPENFLOW_OTEL_SAMPLE_RATE`
    - _Requirements: 9.1_

  - [x] 10.2 验证 Flutter 通知中心对 `harness_wasm_alert` 类型的优雅处理
    - 确认 `rust_api` notification 模型的 unknown-type 处理不 crash
    - 无需新 API endpoint，复用现有 `GET /api/v1/notifications`
    - _Requirements: 9.2, 9.3_

- [x] 11. Final Checkpoint — 全量验证
  - 运行 `yarn refactor:agent --full`，确保 `cargo test` 全绿、`flutter analyze` 无错误，ask the user if questions arise.

---

## Notes

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 交付
- 属性测试使用 `proptest`，每个属性最少 100 次迭代
- 每个属性测试注释格式：`// Feature: harness-observability-hardening, Property N: <property_text>`
- `harness/alert.rs` 中的 `evaluate_and_notify` 应由调用方（如定时任务或 observe 挂钩）驱动，不在本 spec 内新增定时器基础设施
- PII_Filter 仅作用于 OTel exporter layer，控制台日志不受影响
- 所有新增文件控制在 800 行以内

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3"] },
    { "id": 3, "tasks": ["2.1"] },
    { "id": 4, "tasks": ["2.2"] },
    { "id": 5, "tasks": ["3.1"] },
    { "id": 6, "tasks": ["4.1"] },
    { "id": 7, "tasks": ["5"] },
    { "id": 8, "tasks": ["6.1"] },
    { "id": 9, "tasks": ["6.2"] },
    { "id": 10, "tasks": ["6.3"] },
    { "id": 11, "tasks": ["7.1"] },
    { "id": 12, "tasks": ["7.2"] },
    { "id": 13, "tasks": ["7.3"] },
    { "id": 14, "tasks": ["7.4"] },
    { "id": 15, "tasks": ["8.1"] },
    { "id": 16, "tasks": ["8.2"] },
    { "id": 17, "tasks": ["8.3"] },
    { "id": 18, "tasks": ["8.4"] },
    { "id": 19, "tasks": ["8.5"] },
    { "id": 20, "tasks": ["9.1"] },
    { "id": 21, "tasks": ["9.2"] },
    { "id": 22, "tasks": ["10.1"] },
    { "id": 23, "tasks": ["10.2"] },
    { "id": 24, "tasks": ["11"] }
  ]
}
```
