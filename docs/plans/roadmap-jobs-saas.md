# 路线图：异步任务 + Webhook + SaaS 计费

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`jobs-and-webhook-hardening`、`saas-product-spec`。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| `app_generation_job` + REST + worker + WS 更新 | `baseline_done` | `jobs-and-webhook-hardening` |
| 计费 webhook：验签、去重、审计查询、`/me` 订阅字段 | `baseline_done` | `saas-product-spec` YAML completed |

## 下一阶段

### Jobs / 队列

与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) **§7.1 / YAML `jobs-and-webhook-hardening`** 一致：**默认真源为 Postgres**（`SKIP LOCKED`）；Redis / 云托管队列为 **旁路升级**，非默认里程碑。

| 内容 | 状态 | 备注 |
|------|------|------|
| PG 队列：观测、容量 Runbook、队列抽象（trait/factory） | `next` | **必做**；未触发旁路 Gate 前持续交付 |
| Redis / 云托管第二队列 | `blocked` | **架构 Gate**：仅当书面瓶颈指标（延迟、锁竞争、写入吞吐等）评审通过 → 转 `next` 并执行 WP-A1；否则维持 PG-only |
| 全局限流与滥用防护（plan_tier） | `next` | **必做**；与各 tier 限额表一致；**默认不依赖 Redis**（见母文档 §13 / `tower_governor`） |

### SaaS / 收单

| 内容 | 状态 | 备注 |
|------|------|------|
| 生产级收单适配（各 provider 边界案例） | `next` | **必做**；YAML「仍缺生产级收单适配细节」 |
| USD/CNY 路由与运营后台视图 | `blocked` | **必做**；Gate：财务/法务与真实商户号；staging 须先做满 |

## 验收

- 计费相关改动跑 `yarn refactor:check`；webhook 变更核对 OpenAPI 与审计字段。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。
>
> **全栈**：凡影响用户/运营可见行为的工作包，须 **同里程碑** 交付 **Rust + OpenAPI/WS（若适用）+ `frontend/`（含 `rust_api` 与相关 UI/错误态）**；纯文档/运维且无 API 的 WP 可在「目标」首行标 **`(ops-only)`**。约定见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

### WP-A0：PG 队列观测 + 队列抽象就绪（必做，默认路径）

**竖切清单（勾选执行）**：[**`tasks-pg-queue-observability.md`**](./tasks-pg-queue-observability.md) · **Runbook**：[**`jobs-pg-queue-runbook.md`**](./jobs-pg-queue-runbook.md)。

| 项 | 内容 |
|----|------|
| **目标** | 在 **不实装 Redis** 的前提下，把 PG 队列跑清楚：**指标**（排队深度、claim 延迟、失败重试率）、**容量 Runbook**（如何水平扩 worker、如何读 PG 诊断）、**队列 trait/factory** 足以挂载第二后端（即便暂未启用）。 |
| **依赖** | 现有 [`jobs/queue/pg.rs`](../../backend/src/jobs/queue/pg.rs)；运维愿保留 PG 为主要队列时的 SLO 定义。 |
| **PR 切片** | （1）指标导出或日志字段（与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F 可共用 trace/job_id）；（2）文档：瓶颈 Gate 判定阈值（写入何种纪要即触发 WP-A1）；（3）代码：`jobs/queue/*` 抽象边界清晰。 |
| **触点** | `backend/src/jobs/queue/`；`backend/src/jobs/worker/mod.rs`；`backend/src/jobs/enqueue.rs`。 |
| **测试** | **必做**：现有集成路径保持绿；新增观测相关单测或烟雾（若有导出）。 |
| **回滚** | 观测开关降级不影响任务执行。 |

### WP-A1：Redis / 云托管第二队列（仅架构 Gate 通过后）

| 项 | 内容 |
|----|------|
| **目标** | 当 **WP-A0** 中书面 Gate 触发且评审签字后，落地第二后端（Redis 或云托管）；[`jobs/queue/pg.rs`](../../backend/src/jobs/queue/pg.rs) 保留 **降级或并行验证** 路径，Runbook 写明切换与排空。 |
| **依赖** | Gate 纪要 + 运维选定产品；幂等、重复消费、可见性超时语义定稿。 |
| **PR 切片** | （1）第二后端实现 + 配置切换；（2）双写或影子流量验证期至指标达标；（3）故障降级 Runbook。 |
| **触点** | 同 WP-A0。 |
| **测试** | **必做**：集成入队→消费；**必做**：故障注入（旁路不可用 → 符合 Runbook 的降级）。 |
| **回滚** | 配置切回 PG-only；残留消息排空与对账写入 Runbook。 |

### WP-B：全局限流与滥用防护（plan_tier）

| 项 | 内容 |
|----|------|
| **目标** | 按 `plan_tier` / 用户 / IP 限制昂贵接口与 job 创建速率，与用量表一致。 |
| **依赖** | 产品定义各 tier 限额；现有 `app_usage_event` 与 `/me` 字段。 |
| **PR 切片** | （1）中间件或 handler 层计数（**优先 PG / 进程内**；与母文档一致：**Redis 非 HTTP 限流默认路径**）；（2）429 + 统一 `code`；（3）OpenAPI 描述；（4）Flutter 错误提示。 |
| **触点** | `backend/src/app/router/build.rs` 或各模块 `handlers`；`billing/` **须与订阅/tier 联动**；OpenAPI。 |
| **测试** | **必做**：单元 + 烟雾覆盖超限码；回归现有契约路径不得静默损坏。 |
| **回滚** | 临时调高限额须记 incident；长期禁止「永久关闭限流」作为常态。 |

### WP-C：生产级收单适配（provider 边界案例）

| 项 | 内容 |
|----|------|
| **目标** | 补齐 Stripe / Alipay / Paddle 等「长尾事件 + 乱序 + 重复」真实案例在 `billing/ingest` 下的行为与审计一致性。 |
| **依赖** | 沙盒凭证；法务允许的 fixture 数据脱敏。 |
| **PR 切片** | （1）每 provider 增加 golden fixture + `billing/ingest/tests`；（2）修正 `provider_rules/*` 映射；（3）更新 OpenAPI webhook 说明。 |
| **触点** | `backend/src/billing/ingest/`；`backend/src/billing/provider_rules/`；`backend/src/billing/events_list/`；`billing/openapi.rs`。 |
| **测试** | `cargo test` billing 模块；`yarn refactor:check`。 |
| **回滚** | Git revert；数据库审计表保留历史（一般不删）。 |

### WP-D：USD/CNY 路由与运营查询视图（必做）

| 项 | 内容 |
|----|------|
| **目标** | **必做**：运营可按币种 / provider / 时间窗审计订阅与 webhook（API + 最小可用 UI 或受控导出）；能力建立在 `GET …/webhooks/billing/events` 等现有接口之上，缺口则 **必扩 query**。当前 Flutter「帮助 / 出站 Webhook」页已补较完整的 billing webhook 审计产品面：provider / informational / `event_type` / raw/provider event id 与 prefix / `event_created_*` + `created_*` 时间窗 / 分页查询，以及当前加载摘要、复制查询摘要、复制当前查询 URL、当前页 CSV / 多页全量 CSV 导出、行级 drilldown 过滤。 |
| **依赖** | **staging 先做满**；生产 Gate（商户号、合规）标记 `blocked` 时不减免实现，仅减免 prod URL。 |
| **PR 切片** | （1）API 筛选维度补齐；（2）**必做**：Flutter 内部页 **或** 等效导出流水（CSV）至少一种；（3）**必做**：RBAC（admin / 限定 workspace role）。 |
| **触点** | `backend/src/billing/events_list/`；billing handlers；`frontend/` 内部入口（无则新建最小屏）。 |
| **测试** | **必做**：契约烟雾 + 书面验收矩阵（staging）。 |
| **回滚** | API 不得破坏性回滚；UI 可按 flag 隐藏，功能须在 staging 可重现。 |
