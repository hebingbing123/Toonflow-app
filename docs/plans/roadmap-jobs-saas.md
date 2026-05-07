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
