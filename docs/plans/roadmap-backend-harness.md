# 路线图：Rust 后端领域 + Harness

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`rust-backend-mvp`、`harness-rust-core`。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| PG + SQLx、核心 REST 竖切 | `baseline_done` | `rust-backend-mvp` YAML completed |
| Harness WS：tools / agent / 权限 / observe 挂钩 | `baseline_done` | `harness-rust-core` YAML completed |
| 契约烟雾与部分 PG 合约测试 | `baseline_done` | 见 `backend/src/app/contract_smoke_tests`、`pg_contract_tests` |

## 下一阶段（母文档已写明「仍缺」）

### rust-backend-mvp 加深

| 内容 | 状态 | 备注 |
|------|------|------|
| 更广端到端契约矩阵（关键用户路径） | `done` | PG：`project_dashboard_surface_roundtrip`（`#[ignore]`）等；见 WP-A |
| `video_count` 等与统计语义彻底对齐产品 | `done` | **`app_video`** 终态计数 + 契约；见 WP-B / `bd6a4b5a` |

### harness-rust-core 加深

| 内容 | 状态 | 备注 |
|------|------|------|
| 用户上传 WASM 策略（配额、签名、审计） | `in_progress` | **薄切片**：`wasm_runtime::validate_user_wasm_upload` + **`HARNESS_USER_WASM_MAX_BYTES`** + **`POST /api/v1/harness/user-wasm/validate`**（JWT）+ Postgres Stub **`POST/GET /api/v1/harness/user-wasm`**（`app_harness_user_wasm`；列表不返回 `wasm_bytes`）+ 单测 / 冒烟；**吊销** / 对象存储 / WS 执行仍为 **`next`**；威胁模型见 [`harness-user-wasm-threat-model.md`](./harness-user-wasm-threat-model.md) |
| 隔离执行：指标 + 子进程池（idle 复用、`HARNESS_ISOLATE_*`、`/ready`） | `shipped` | **`9388ec3a`**（指标）、**`3b326f26`**（默认池 + 集成测）；与 `HARNESS_ISOLATE_MAX_CONCURRENT` 一致 |
| 进程池启动预热（prefork） | `shipped` | **`HARNESS_ISOLATE_PREFORK`**（上限同并发槽；**`HARNESS_ISOLATE_POOL`** 关闭时不预热）；**`main`** 监听前 **`warm_isolate_pool_prefork`**；README + 集成测 |
| 进程池扩展回收 / 老化（TTL、轮换） | `shipped` | **`HARNESS_ISOLATE_POOL_IDLE_TTL_SECS`** / **`HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS`** + `total_pool_evictions`；idle 归还与 acquire 前 prune；**`try_wait`** 剔除已退出 worker；Runbook 仍可对齐 SLO 细调 |
| LLM 流式工具调用融合 | `next` | **必做**；协议与产品规则须书面定稿 |
| Trace / 结构化观测 + OTel 导出 | `shipped`（gRPC OTLP traces） | **必做**；与 `quality-bar`、运维 KPI 联动；**已实现**：`TOONFLOW_OTEL_EXPORT_ENABLED` + **`OTEL_EXPORTER_OTLP_*`** gRPC 导出 + `telemetry` 模块 + README + 单测 / ignored collector 烟测；采样率 / PII 白名单等见 WP-F PR 切片仍 **`next`** |

## 验收

- 变更域跑 `yarn refactor:check`。
- 新增 WS 或 HTTP 工具必须更新 `docs/websocket-events.md`；凡暴露 REST 的变更必须同步 OpenAPI。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。
>
> **全栈**：凡影响用户/运营可见行为的工作包，须 **同里程碑** 交付 **Rust + OpenAPI/WS（若适用）+ `frontend/`（含 `rust_api` 与相关 UI/错误态）**；纯文档/运维且无 API 的 WP 可在「目标」首行标 **`(ops-only)`**。约定见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

### WP-A：更广端到端契约矩阵（关键用户路径）

| 项 | 内容 |
|----|------|
| **目标** | 覆盖「登录后创建项目 → 核心工作台一条链」级别的 PG 契约或集成测试，减少回归盲区。 |
| **依赖** | `DATABASE_URL`、`SUPABASE_JWT_SECRET`；现有 `app::pg_contract_tests` 模式。 |
| **PR 切片** | （1）在 `backend/src/app/mod.rs`（或专用 `pg_contract_tests` 子模块）新增 `#[ignore]` 场景；（2）每条路径独立测试函数，避免巨型单测。 |
| **触点** | `backend/src/app/mod.rs`；各竖切 `handlers`；母文档 `rust-backend-mvp` 所列 REST。 |
| **测试** | `cd backend && cargo test <filter> -- --ignored`（本地/CI nightly）；默认 CI 仍跑非 ignore 集合。 |
| **回滚** | 删除新增测试或标记 skip，不影响生产行为。 |

### WP-B：`video_count` 与统计语义对齐产品

| 项 | 内容 |
|----|------|
| **目标** | `GET …/projects/summary` 与 `GET …/projects/{id}/stats` 中 **`video_count` 语义与产品定义一致**，并在 OpenAPI/对内文档写明规则。 |
| **依赖** | 产品书面确认「视频」判定（分镜导出 / job 成功态 / 存储对象等）。 |
| **PR 切片** | （1）查询与聚合实现；（2）handler + OpenAPI 字段说明；（3）**必做**：Flutter 侧展示与文案与语义一致（字段已暴露则必须改）。 |
| **触点** | 项目 stats 相关 handler（`backend/src/app/` 下 projects）；OpenAPI；`frontend/lib/rust_api/`。 |
| **测试** | **必做**：PG 契约或单元测试覆盖计数 fixture；禁止无测试保留模糊语义。 |
| **回滚** | 仅允许带版本协商回退；回退须同步文档与客户端。 |

### WP-C：用户上传 WASM（策略 + 存储 + 执行）

| 项 | 内容 |
|----|------|
| **目标** | 允许受限场景下用户 supplied WASM 注册为 harness 工具，含配额、审计、禁止网络等策略。 |
| **依赖** | 现有 `wasm_runtime.rs` / `wasm.probe`；安全评审结论。 |
| **PR 切片** | （0）**进行中**：投递前 **`validate_user_wasm_upload`** + **`POST /api/v1/harness/user-wasm/validate`**（可单独验收；无 DB 写入）+ 体积单测；（1）设计与威胁模型（[`harness-user-wasm-threat-model.md`](./harness-user-wasm-threat-model.md)）；（2）**Stub**：迁移 **`app_harness_user_wasm`** + **`POST/GET /api/v1/harness/user-wasm`**（持久化 RAW 校验后的模块 + SHA256 / 列出元数据；可调 **`HARNESS_USER_WASM_MAX_STORED_PER_USER`**、**`HARNESS_USER_WASM_LIST_CAP`**）；（3）吊销 / 对象存储 offload / 审计仍为 **`next`**；（4）WS `harness.tool.invoke` 分支与超时/内存限额；（5）运维开关 kill-switch（内建 **`wasm.probe`** 已支持 **`HARNESS_WASM_PROBE_DISABLED`**）。 |
| **触点** | `backend/src/harness/wasm_runtime.rs`；`backend/src/harness/ws/tool.rs`；`backend/src/harness/tools.rs`；`docs/websocket-events.md`。 |
| **测试** | **必做**：畸形 WASM、超时、未授权上传；**必做**：体量上限测试（fuzz 或等价边界单测）。 |
| **回滚** | Feature flag 关闭新工具类型；DB 吊销所有用户 WASM。 |

### WP-D：隔离执行进程池预热 / 回收

| 项 | 内容 |
|----|------|
| **目标** | 降低 `isolated.*` 工具冷启动延迟；并发受控于 `HARNESS_ISOLATE_MAX_CONCURRENT` 且可观测。 |
| **依赖** | 现有 `backend/src/harness/isolate.rs` 行为基线。 |
| **PR 切片** | （1）**已交付**：指标（队列深度、Semaphore 等待、子进程 spawn、**`process_reuse_hits`** 等）+ **`tracing`** / **`GET /ready`**（**`9388ec3a`**）；（2）**已交付**：默认 **`HARNESS_ISOLATE_POOL`** 常驻 worker + idle 复用（**`3b326f26`**）；运维说明见 **`backend/README.md`**；（3）**已交付**：启动前 **prefork**（**`HARNESS_ISOLATE_PREFORK`** + **`warm_isolate_pool_prefork`**）；（4）**已交付**：池 worker **idle TTL** / **最大存活时间** / 死进程剔除（**`HARNESS_ISOLATE_POOL_IDLE_TTL_SECS`**、**`HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS`**、**`total_pool_evictions`**）。 |
| **触点** | `backend/src/harness/isolate.rs`；`backend/src/harness/observe.rs`；环境变量 README。 |
| **测试** | **必做**：`cargo test` 覆盖并发槽耗尽；负载或 bench 纳入 **nightly 或发版前清单**（书面固定频率）。 |
| **回滚** | **`HARNESS_ISOLATE_POOL`** 关闭即退回单次 spawn；完整 Runbook 待 prefork/老化策略落地后补全。 |

### WP-E：LLM 流式工具调用融合

| 项 | 内容 |
|----|------|
| **目标** | Agent 循环在流式输出过程中可交错工具调用与继续生成（产品定义为准）。 |
| **依赖** | 当前 LLM envelope 与 `harness.agent.run` 协议；**必做**：产品书面定稿并行工具与交错语义。 |
| **PR 切片** | （1）wire 协议增量：`backend/src/harness/wire.rs`；（2）dispatch：`ws/dispatch` + `ws/agent.rs`；（3）Flutter 客户端解析；（4）文档。 |
| **触点** | `backend/src/harness/wire.rs`；`backend/src/harness/ws/agent.rs`；`frontend/lib/agent_workspaces/`（或等价 WS 客户端）。 |
| **测试** | **必做**：契约或 fake LLM 集成；**必做**：WS 顺序/快照回归（关键事件序列锁定）。 |
| **回滚** | 协议版本协商：旧客户端走旧事件子集。 |

### WP-F：Trace / 结构化观测与 OTel 导出（必做）

| 项 | 内容 |
|----|------|
| **目标** | 在 `request_id` 基础上，将 harness session / tool invoke / job **全链路透传 trace id**，并 **必做 OTel（或等价标准导出）管线**，供运维查询与 SLO。 |
| **依赖** | 与 [`roadmap-quality.md`](./roadmap-quality.md) WP-D 的关联字段设计对齐；**顺序**：先贯通 trace id，再扩展业务关联字段。 |
| **PR 切片** | （0）**stub**：~~`TOONFLOW_OTEL_EXPORT_ENABLED` 时仅 warn~~ **已替换**；（**OTLP gRPC traces**）`TOONFLOW_OTEL_EXPORT_ENABLED` + `OTEL_EXPORTER_OTLP_ENDPOINT` / `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` + `telemetry::init_tracing_subscriber` + README + 测试；（1）统一 `tracing` span 与 baggage 约定；（2）**必做**：可配置导出（环境区分 staging/prod，采样率可调但 prod 非零）；（3）**必做**：PII 脱敏与字段白名单评审。 |
| **触点** | `backend/src/telemetry.rs`；`backend/src/main.rs`；`backend/src/harness/observe.rs`；HTTP 中间件；`jobs/worker` **必做**关联 `job_id`。 |
| **测试** | **必做**：本地或 CI OTel collector 冒烟（**`tests/telemetry_otlp_collector_smoke.rs`**，`--ignored`）；单测 span 父子关系（**`telemetry` 模块**）。 |
| **回滚** | 导出降为最低采样 + 磁盘日志兜底；不得在未知故障下静默关闭 trace id 传递。 |
