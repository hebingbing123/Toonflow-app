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

| 内容 | 状态 | 备注 |
|------|------|------|
| Redis / 托管队列第二后端 | `next` | **必做**；顺序在队列抽象与 PG 路径稳定之后；PG 保留兼容或降级路径 |
| 全局限流与滥用防护（plan_tier） | `next` | **必做**；与各 tier 限额表一致 |

### SaaS / 收单

| 内容 | 状态 | 备注 |
|------|------|------|
| 生产级收单适配（各 provider 边界案例） | `next` | **必做**；YAML「仍缺生产级收单适配细节」 |
| USD/CNY 路由与运营后台视图 | `blocked` | **必做**；Gate：财务/法务与真实商户号；staging 须先做满 |

## 验收

- 计费相关改动跑 `yarn refactor:check`；webhook 变更核对 OpenAPI 与审计字段。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。

### WP-A：Redis / 托管队列第二后端（必做，顺序后置）

| 项 | 内容 |
|----|------|
| **目标** | **必做**落地第二队列实现（Redis 或云托管队列），支撑峰值与多实例运维目标；[`jobs/queue/pg.rs`](../../backend/src/jobs/queue/pg.rs) 保持 **兼容真源或降级路径**，Runbook 写明切换条件。 |
| **依赖** | 运维确认目标队列产品；幂等、重复消费、可见性超时语义书面定稿。 |
| **PR 切片** | （1）队列抽象补齐（trait / factory）；（2）第二后端实现 + 配置切换；（3）**必做**：双写或影子流量验证期，直至对比指标达标；（4）Runbook（切换、排空、故障降级）。 |
| **触点** | `backend/src/jobs/queue/`；`backend/src/jobs/enqueue.rs`；`backend/src/jobs/worker/mod.rs`。 |
| **测试** | **必做**：集成入队→消费；**必做**：故障注入（队列不可用 → 降级行为符合 Runbook）。 |
| **回滚** | 配置切回 PG 路径；残留消息排空与数据对账步骤写入 Runbook。 |

### WP-B：全局限流与滥用防护（plan_tier）

| 项 | 内容 |
|----|------|
| **目标** | 按 `plan_tier` / 用户 / IP 限制昂贵接口与 job 创建速率，与用量表一致。 |
| **依赖** | 产品定义各 tier 限额；现有 `app_usage_event` 与 `/me` 字段。 |
| **PR 切片** | （1）中间件或 handler 层计数（Redis 或 PG 滑动窗口）；（2）429 + 统一 `code`；（3）OpenAPI 描述；（4）Flutter 错误提示。 |
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
| **目标** | **必做**：运营可按币种 / provider / 时间窗审计订阅与 webhook（API + 最小可用 UI 或受控导出）；能力建立在 `GET …/webhooks/billing/events` 等现有接口之上，缺口则 **必扩 query**。 |
| **依赖** | **staging 先做满**；生产 Gate（商户号、合规）标记 `blocked` 时不减免实现，仅减免 prod URL。 |
| **PR 切片** | （1）API 筛选维度补齐；（2）**必做**：Flutter 内部页 **或** 等效导出流水（CSV）至少一种；（3）**必做**：RBAC（admin / 限定 workspace role）。 |
| **触点** | `backend/src/billing/events_list/`；billing handlers；`frontend/` 内部入口（无则新建最小屏）。 |
| **测试** | **必做**：契约烟雾 + 书面验收矩阵（staging）。 |
| **回滚** | API 不得破坏性回滚；UI 可按 flag 隐藏，功能须在 staging 可重现。 |
