# Design Document: harness-observability-hardening

## Overview

本功能补齐 Harness 可观测性的两个剩余工作包：

**WP-C 剩余：跨环境告警编排**
- 告警阈值通过环境变量配置（`HARNESS_USER_WASM_ALERT_*`）
- 阈值触发时写入 `app_notification`（复用现有通知中心）
- 可选通过 `HARNESS_ALERT_WEBHOOK_URL` 发送出站 webhook
- 运行手册 `docs/plans/harness-wasm-alert-runbook.md`

**WP-F 剩余：采样率 / PII 白名单**
- `OPENFLOW_OTEL_SAMPLE_RATE` 可配置采样率（prod 非零）
- Span attribute PII 白名单过滤（`[redacted]`）
- 统一 harness session / tool invoke / job 全链路 trace id 透传
- jobs/worker 关联 `job_id` 到 trace

### 设计原则

- **复用优先**：复用 `telemetry.rs`、`observe.rs`、`settings/notifications/storage.rs`，不引入新全局状态
- **最小侵入**：PII_Filter 作为 `tracing-opentelemetry` pipeline 层，不影响控制台日志
- **单文件 ≤800 行**：新增文件按语义拆分（`harness/alert.rs`、`telemetry/pii_filter.rs`）
- **全栈同里程碑**：Flutter 通知中心无需新 API，复用现有 `GET /api/v1/notifications`

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  WP-C：告警编排                                                  │
│                                                                  │
│  harness/observe.rs                                              │
│    harness_user_wasm_signal(...)  ──►  harness/alert.rs          │
│                                         Alert_Evaluator          │
│                                         (rolling window)         │
│                                           │                      │
│                              ┌────────────┴────────────┐        │
│                              ▼                          ▼        │
│                    Notification_Writer          Webhook_Dispatcher│
│                    app_notification             HARNESS_ALERT_   │
│                    (record_notification)        WEBHOOK_URL      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  WP-F：OTel 采样率 + PII 过滤 + Span 约定                        │
│                                                                  │
│  telemetry.rs                                                    │
│    init_tracing_subscriber()                                     │
│      ├── TraceIdRatioBased(OPENFLOW_OTEL_SAMPLE_RATE)            │
│      └── PiiFilterLayer (telemetry/pii_filter.rs)                │
│                                                                  │
│  harness/ws/connection.rs  ──► harness.session span              │
│  harness/ws/tool.rs        ──► harness.tool.invoke span          │
│  harness/wasm_runtime.rs   ──► harness.wasm.invoke span          │
│  harness/ws/agent.rs       ──► harness.agent.run span            │
│  jobs/worker/mod.rs        ──► job.execute span (+ job_id attr)  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components and Interfaces

### 1. `harness/alert.rs`（新增，≤400 行）

告警评估与通知分发的核心模块。

```rust
/// 告警配置，从环境变量解析（启动时一次性读取）
pub struct WasmAlertConfig {
    pub validate_fail_rate_threshold: f64,   // HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE, default 0.1
    pub invoke_fail_rate_threshold: f64,     // HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE, default 0.1
    pub fuel_exhaustion_rate_threshold: f64, // HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE, default 0.2
    pub window_secs: u64,                    // HARNESS_USER_WASM_ALERT_WINDOW_SECS, default 300
    pub min_events: u64,                     // HARNESS_USER_WASM_ALERT_MIN_EVENTS, default 5
    pub webhook_url: Option<String>,         // HARNESS_ALERT_WEBHOOK_URL
    pub ops_user_id: Option<Uuid>,           // HARNESS_ALERT_OPS_USER_ID
}

impl WasmAlertConfig {
    pub fn from_env() -> Self;
}

/// 评估信号聚合结果，触发告警或清除
pub async fn evaluate_and_notify(
    config: &WasmAlertConfig,
    pool: &PgPool,
    http_client: &reqwest::Client,
) -> Result<(), AlertError>;
```

**评估逻辑**：
- 查询 `app_harness_user_wasm_audit` 表，统计最近 `window_secs` 内各 `outcome` 的计数
- 若总事件数 < `min_events`，跳过评估
- 计算各信号失败率，与阈值对比
- 阈值触发 → 调用 `Notification_Writer` + `Webhook_Dispatcher`
- 阈值恢复 → 写入 `harness_wasm_alert_cleared` 通知

**去重逻辑**：
- 查询 `app_notification` 中是否存在未读的 `harness_wasm_alert` 行（同 `signal_name`）
- 存在则 UPDATE `updated_at` + `payload`，不重复 INSERT

### 2. `Notification_Writer`（内嵌于 `harness/alert.rs`）

```rust
async fn write_alert_notification(
    pool: &PgPool,
    signal_name: &str,
    threshold: f64,
    observed_rate: f64,
    config: &WasmAlertConfig,
    cleared: bool,
) -> Result<(), sqlx::Error>;
```

- 复用 `settings/notifications/storage.rs` 中的 `record_notification`
- `notification_type`：`harness_wasm_alert` 或 `harness_wasm_alert_cleared`
- `user_id`：`config.ops_user_id`（可为 NULL）
- `workspace_id`：NULL（workspace-agnostic）
- 写入失败仅 log，不 propagate

### 3. `Webhook_Dispatcher`（内嵌于 `harness/alert.rs`）

```rust
async fn dispatch_webhook(
    client: &reqwest::Client,
    url: &str,
    payload: &AlertWebhookPayload,
);
```

- 非阻塞 `tokio::spawn`，不影响评估延迟
- 失败仅 log `event=harness_alert_webhook_failed`，不重试
- URL 在日志中仅记录 scheme+host

### 4. `telemetry/pii_filter.rs`（新增，≤200 行）

```rust
/// PII 白名单（编译时常量）
pub const PII_ALLOWLIST: &[&str] = &[
    "user_id", "workspace_id", "request_id", "job_id", "wasm_id",
    "signal_name", "tool_name", "event", "outcome", "error_code",
    "kind", "phase", "worker_id",
    // 技术元数据组（不含 PII）
    "http.method", "http.status_code", "http.url", "http.route",
    "db.system", "db.operation", "net.peer.name", "net.peer.port",
    "otel.status_code", "otel.status_description",
    "code.function", "code.namespace", "code.filepath",
];

/// tracing Layer，在 span attribute 写入前过滤非白名单字段
pub struct PiiFilterLayer;

impl<S: Subscriber> Layer<S> for PiiFilterLayer {
    fn on_record(&self, id: &span::Id, values: &Record<'_>, ctx: Context<'_, S>);
}
```

- 非白名单 key → 值替换为 `[redacted]`
- JSON 值 → 替换为 `[redacted:json]`
- 大小写不敏感匹配
- 仅作用于 OTel exporter layer，不影响 `fmt::Layer`（控制台输出）

### 5. `telemetry.rs` 扩展

在 `init_tracing_subscriber` 中：

```rust
// 读取采样率
let sample_rate = parse_sample_rate(); // OPENFLOW_OTEL_SAMPLE_RATE

// 配置 SdkTracerProvider
let sampler = opentelemetry_sdk::trace::Sampler::TraceIdRatioBased(sample_rate);
let provider = SdkTracerProvider::builder()
    .with_sampler(sampler)
    .with_batch_exporter(exporter, runtime::Tokio)
    .build();

// 注册 PiiFilterLayer（仅在 OTel 启用时）
let otel_layer = tracing_opentelemetry::layer()
    .with_tracer(tracer)
    .with_filter(/* PII filter */);
```

```rust
fn parse_sample_rate() -> f64 {
    match std::env::var("OPENFLOW_OTEL_SAMPLE_RATE") {
        Ok(v) => match v.trim().parse::<f64>() {
            Ok(r) if r > 0.0 && r <= 1.0 => r,
            Ok(r) if r <= 0.0 => {
                tracing::warn!(event = "otel_sample_rate_invalid", value = %v);
                0.01 // 最小有效采样率，防止 prod 静默关闭
            }
            _ => {
                tracing::warn!(event = "otel_sample_rate_invalid", value = %v);
                1.0
            }
        },
        Err(_) => 1.0,
    }
}
```

### 6. Span 约定（各文件就地添加 `tracing::instrument` 或手动 span）

| 文件 | Span 名称 | 关键 Attributes |
|------|-----------|----------------|
| `harness/ws/connection.rs` | `harness.session` | `user_id`, `workspace_id` |
| `harness/ws/tool.rs` | `harness.tool.invoke` | `tool_name`, `user_id`, `workspace_id`, `request_id` |
| `harness/wasm_runtime.rs` | `harness.wasm.invoke` | `wasm_id`, `user_id`, `outcome`, `error_code` |
| `harness/ws/agent.rs` | `harness.agent.run` | `user_id` |
| `jobs/worker/mod.rs` | `job.execute` | `job_id`, `kind`, `worker_id`, `user_id`, `phase` |

所有 span 使用 `tracing::info_span!` 宏，通过 `tracing-opentelemetry` 自动关联父子关系。`TraceContext` 结构体（已在 `harness/observe.rs`）透传 W3C `traceparent`。

### 7. `docs/plans/harness-wasm-alert-runbook.md`（新增）

包含：
- 三个告警信号（`invoke_wasm_failed`、`invoke_wasm_timeout`、`object_store_put_fail`）的默认阈值与严重级别
- 每个告警的排查步骤（日志过滤语法、环境变量调整、kill-switch 使用）
- `HARNESS_USER_WASM_DISABLED` 与 `HARNESS_WASM_PROBE_DISABLED` 的效果与回滚
- `app_notification` 查询模板

---

## Data Models

### AlertWebhookPayload

```rust
#[derive(Serialize)]
struct AlertWebhookPayload {
    event: &'static str,          // "harness_wasm_alert" | "harness_wasm_alert_cleared"
    signal_name: String,
    threshold: f64,
    observed_rate: f64,
    window_secs: u64,
    fired_at: chrono::DateTime<Utc>,
    environment: String,          // OTEL_SERVICE_NAME 或 "openflow-server"
}
```

### app_notification 新增 notification_type 值

| notification_type | 触发条件 | payload 字段 |
|---|---|---|
| `harness_wasm_alert` | 阈值触发 | `signal_name`, `threshold`, `observed_rate`, `window_secs`, `min_events` |
| `harness_wasm_alert_cleared` | 阈值恢复 | 同上 + `resolved_at` |

---

## Correctness Properties

### Property 1: 告警阈值配置回落不变量

*For any* 非法或缺失的 `HARNESS_USER_WASM_ALERT_*` 环境变量值，`WasmAlertConfig::from_env()` 返回的配置中对应字段等于默认值，且 `event=harness_alert_config_invalid` 被 log 一次。

**Validates: Requirements 1.6, 1.7**

### Property 2: 采样率边界不变量

*For any* `OPENFLOW_OTEL_SAMPLE_RATE` 输入值 r，解析后的有效采样率 r' 满足：`r' ∈ (0.0, 1.0]`（即永远不为 0，永远不超过 1）。

**Validates: Requirements 5.1, 5.2, 5.3**

### Property 3: PII 过滤白名单不变量

*For any* span attribute key k 和 value v：
- 若 k ∈ PII_Allowlist（大小写不敏感）→ 记录值为 v（不变）
- 若 k ∉ PII_Allowlist → 记录值为 `[redacted]` 或 `[redacted:json]`

**Validates: Requirements 6.1, 6.2, 6.3, 6.5**

### Property 4: 退化率计算一致性（告警评估）

*For any* 事件窗口内的信号计数，`observed_rate = failure_count / total_count`，且 `total_count >= min_events` 时才触发评估。

**Validates: Requirements 1.4, 1.5, 2.1**

### Property 5: Webhook 非阻塞性

*For any* webhook 调用（成功或失败），`evaluate_and_notify` 的总执行时间不因 webhook 响应时间而增加（webhook 在独立 task 中执行）。

**Validates: Requirements 3.6**

---

## Error Handling

| 场景 | 处理策略 |
|---|---|
| `app_notification` 写入失败 | log `event=harness_alert_notification_write_failed`，不 propagate |
| Webhook HTTP 失败或非 2xx | log `event=harness_alert_webhook_failed`（URL 仅 scheme+host），不重试 |
| `OPENFLOW_OTEL_SAMPLE_RATE` 为 0 或负数 | log `event=otel_sample_rate_invalid`，使用 0.01 |
| `OPENFLOW_OTEL_SAMPLE_RATE` 不可解析 | log `event=otel_sample_rate_invalid`，使用 1.0 |
| `HARNESS_ALERT_WEBHOOK_URL` 未配置 | 静默跳过，不 log warning |
| Span attribute 非白名单 key | 值替换为 `[redacted]`，不影响控制台日志 |

---

## Testing Strategy

### 单元测试（`cargo test`）

**`harness/alert.rs` 测试：**
- `WasmAlertConfig::from_env()` 对非法阈值回落默认值
- 告警去重：同 `signal_name` 已有未读通知时不重复 INSERT
- `dispatch_webhook` 失败时不 panic，仅 log

**`telemetry/pii_filter.rs` 测试：**
- `email` key → 值被替换为 `[redacted]`（Requirement 6.7）
- `user_id` key → 值保留不变（Requirement 6.7）
- JSON 值 + 非白名单 key → 替换为 `[redacted:json]`
- 大小写不敏感：`User_Id` 与 `user_id` 均在白名单

**`telemetry.rs` 测试：**
- `parse_sample_rate()` 对 0.0 返回 0.01，对 1.5 返回 1.0，对缺失返回 1.0

**Span 约定测试（Requirement 7.7, 8.6）：**
- `harness.tool.invoke` span 包含正确的父 span ID（来自 `harness.session`）
- `job.execute` span 包含 `job_id` attribute

### 属性测试（proptest）

```rust
// Property 2: 采样率边界不变量
proptest! {
    #[test]
    fn prop_sample_rate_always_in_valid_range(raw in ".*") {
        std::env::set_var("OPENFLOW_OTEL_SAMPLE_RATE", &raw);
        let rate = parse_sample_rate();
        prop_assert!(rate > 0.0 && rate <= 1.0);
    }
}

// Property 3: PII 过滤白名单不变量
proptest! {
    #[test]
    fn prop_pii_filter_allowlist_invariant(
        key in "[a-zA-Z_\\.]{1,30}",
        value in ".*",
    ) {
        let result = apply_pii_filter(&key, &value);
        if PII_ALLOWLIST.iter().any(|k| k.eq_ignore_ascii_case(&key)) {
            prop_assert_eq!(result, value);
        } else {
            prop_assert!(result.starts_with("[redacted"));
        }
    }
}
```
