# Workspace Billing Scope Decision（W8.1）

**决策**：当前阶段维持 **user-scope billing / quota**，**不**把 `plan_tier`、`daily_job_quota`、`jobs_today` 提前切成 workspace-scope。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W8。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。  
相关路线：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) WP-B / WP-D。

若未来切换为 **workspace-scope** 计费，工程侧完整规格（需求 / 架构 / 任务）见 Kiro：[`.kiro/specs/workspace-scope-billing/`](../../.kiro/specs/workspace-scope-billing/)（`requirements.md`、`design.md`、`tasks.md`）。本文档 **W8.1** 结论在切换前仍以 **user-scope** 为准。

## 1) 结论

在现有实现和产品基线上，以下字段继续按 **user** 口径解释：

- `plan_tier`
- `billing_currency`
- `billing_provider`
- `daily_job_quota`
- `jobs_today`

这意味着：

1. **订阅归属用户，不归属 workspace**
2. **日配额按用户累计，不按 workspace 汇总**
3. **多人同 workspace 协作，并不共享一份 jobs_today / daily_job_quota**

## 2) 为什么现在选 user-scope

### 2.1 现有数据模型已经是 user-scope

从当前实现看：

- `/api/v1/me` 从 `app_user_profile` 读取 `plan_tier`、`billing_currency`、`billing_provider`、`daily_job_quota`
- `jobs_today` 通过 `app_generation_job.owner_user_id = current_user` 统计
- 现有 billing webhook 也是先写 `app_user_profile`

所以如果现在强行改成 workspace-scope，会引入一次真正的模型迁移，而不是“顺手改个文档”。

### 2.2 现有 usage / memory / skills / quality 也都先收口到了 user-scope

当前仓库已经明确：

- `GET /api/v1/usage/summary` -> `scope = user`
- `GET /api/v1/skills/summary` -> `scope = user`
- `GET /api/v1/agents/memory/cost-overview` -> `scope = user`
- quality 聚合端点 -> `scope = user`

如果计费先切 workspace-scope，而其他用量与质量聚合仍是 user-scope，会让产品语义更混乱。

### 2.3 jobs 目前仍保留 owner 个人视角残留

尽管带项目上下文的 jobs 已能按 workspace 成员可见，但：

- `app_generation_job` 仍不双写 `workspace_id`
- 无 `project_*` 的 jobs 仍按 `owner_user_id` 个人视图
- 本地 artifact / 通知也仍可能按 `job.owner_user_id` 对齐

在这种状态下，先宣布 workspace 级共享配额，会把“可见性共享”和“计费归属共享”混成一团。

## 3) 当前产品解释

当前更一致的产品解释是：

> Workspace 解决的是协作与可见范围；订阅与配额解决的是谁为调用成本负责。

在这个解释下：

- 用户可以在团队 workspace 协作
- 但昂贵调用、额度、套餐仍属于发起该调用的用户

这和当前 `owner_user_id` / `plan_tier` / `jobs_today` 的实现最一致。

## 4) 对前后端的直接影响

### 4.1 后端

当前不需要：

- 给 `app_workspace` 新增 `plan_tier`
- 给 `app_generation_job` 新增 `workspace_id` 作为计费真源
- 改 `/api/v1/me` 响应形状

### 4.2 前端

当前应继续把：

- 订阅状态
- 额度
- 超限提示

解释成“当前登录用户”的能力，而不是“当前 workspace 的公共余额”。

### 4.3 运营 / 支持

当用户问“为什么我在团队空间里还能看到项目，但额度却是我自己的”时，当前正确答案应当是：

- 团队空间共享的是协作上下文
- 套餐和配额仍按用户计算

## 5) 未来何时再评估 workspace-scope

只有在以下至少两项同时成立时，才建议重开 W8.2–W8.4：

1. 产品明确希望“团队统一买套餐、成员共享额度”
2. 财务 / 商务明确需要 workspace 级账单主体
3. jobs / usage / quality / memory 至少有一部分已经具备 workspace 聚合口径
4. `app_generation_job` 与关键昂贵调用已经能稳定映射到 workspace 计费归属

否则默认继续沿 user-scope 前进。

## 6) 当前不做的事

本决策明确暂不做：

- workspace 级 `plan_tier`
- workspace 级 `daily_job_quota`
- workspace 级 `jobs_today`
- workspace 级 billing webhook 回填
- workspace 级账单运营面

这些都留给 W8.2–W8.4，在产品/财务结论明确后再单独立项。

## 7) 当前默认策略

因此，W8 当前默认策略固定为：

1. **W8.1 = user-scope 计费结论已定**
2. **W8.2–W8.4 = 暂不执行，等待 workspace-scope 的明确业务驱动**

这样做的主要理由是：它和当前代码、观测、jobs 归属、Flutter 文案解释最一致，返工最少，风险也最低。

## 8) 若未来切换 workspace-scope（仅占位）

产品与财务触发重评后，实施提纲（字段、`/me` 版本化、webhook 双写、迁移阶段）见 **[`workspace-billing-future-workspace-scope.md`](./workspace-billing-future-workspace-scope.md)**；在该决策反转之前 **不写迁移代码**。
