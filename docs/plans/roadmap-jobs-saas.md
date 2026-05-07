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
| Redis / 云队列 | `next`（刻意后置） | 母文档明确非必需 |
| 全局限流「极致化」 | `next` | 与 plan_tier、滥用防护产品决策绑定 |

### SaaS / 收单

| 内容 | 状态 | 备注 |
|------|------|------|
| 生产级收单适配（各 provider 边界案例） | `next` | YAML「仍缺生产级收单适配细节」 |
| USD/CNY 路由与运营后台视图 | `blocked`/`next` | 依赖财务/法务与真实商户号 |

## 验收

- 计费相关改动跑 `yarn refactor:check`；webhook 变更核对 OpenAPI 与审计字段。

## 实施步骤（草案）

### WP-A：Redis / 云队列（刻意后置）

| 项 | 内容 |
|----|------|
| **目标** | 仅在 PG 队列成为明确瓶颈或需要跨地域削峰时引入第二队列；默认仍以 [`jobs/queue/pg.rs`](../../backend/src/jobs/queue/pg.rs) 为真源。 |
| **依赖** | 运维愿意维护 Redis 或托管队列；重复消费/幂等语义已文档化。 |
| **PR 切片** | （1）抽象 `jobs/queue` trait（若尚未完全抽象）；（2）Redis 实现 + 配置开关；（3）双写观测期（可选）；（4）Runbook。 |
| **触点** | `backend/src/jobs/queue/`；`backend/src/jobs/enqueue.rs`；`backend/src/jobs/worker/mod.rs`。 |
| **测试** | 集成：入队→worker 消费；故障注入：Redis 宕机回落或降级策略（须事先选定）。 |
| **回滚** | 配置切回 `pg` only；清空 Redis 中残留消息策略写入 Runbook。 |

### WP-B：全局限流与滥用防护（plan_tier）

| 项 | 内容 |
|----|------|
| **目标** | 按 `plan_tier` / 用户 / IP 限制昂贵接口与 job 创建速率，与用量表一致。 |
| **依赖** | 产品定义各 tier 限额；现有 `app_usage_event` 与 `/me` 字段。 |
| **PR 切片** | （1）中间件或 handler 层计数（Redis 或 PG 滑动窗口）；（2）429 + 统一 `code`；（3）OpenAPI 描述；（4）Flutter 错误提示。 |
| **触点** | `backend/src/app/router/build.rs` 或各模块 `handlers`；`billing/` 若与订阅联动；OpenAPI。 |
| **测试** | 单元 + 烟雾：超限返回预期码；避免影响现有契约测试默认路径。 |
| **回滚** | 功能开关关闭限流中间件。 |

### WP-C：生产级收单适配（provider 边界案例）

| 项 | 内容 |
|----|------|
| **目标** | 补齐 Stripe / Alipay / Paddle 等「长尾事件 + 乱序 + 重复」真实案例在 `billing/ingest` 下的行为与审计一致性。 |
| **依赖** | 沙盒凭证；法务允许的 fixture 数据脱敏。 |
| **PR 切片** | （1）每 provider 增加 golden fixture + `billing/ingest/tests`；（2）修正 `provider_rules/*` 映射；（3）更新 OpenAPI webhook 说明。 |
| **触点** | `backend/src/billing/ingest/`；`backend/src/billing/provider_rules/`；`backend/src/billing/events_list/`；`billing/openapi.rs`。 |
| **测试** | `cargo test` billing 模块；`yarn refactor:check`。 |
| **回滚** | Git revert；数据库审计表保留历史（一般不删）。 |

### WP-D：USD/CNY 路由与运营查询视图（前端或内部工具）

| 项 | 内容 |
|----|------|
| **目标** | 运营可按币种/provider 查看订阅与 webhook 审计摘要（最小：只读筛选已有 `GET …/webhooks/billing/events`）。 |
| **依赖** | 真实商户与合规流程（常 `blocked`）；或先做内部 staging。 |
| **PR 切片** | （1）确认 API 已覆盖筛选维度；不足则扩展 query；（2）Flutter 内部页或导出 CSV；（3）权限：仅 admin/workspace role。 |
| **触点** | `backend/src/billing/events_list/`；对应 handler 注册；`frontend/` 管理入口（若存在）。 |
| **测试** | 契约烟雾 + 手动验收清单。 |
| **回滚** | 隐藏 UI；API 保持向后兼容。 |
