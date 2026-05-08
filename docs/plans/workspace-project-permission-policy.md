# Workspace Project Permission Policy（W5.3）

## 结论

当前 Workspace 项目权限采用 **workspace-level 默认策略**，**不**在这一阶段引入 `app_project_member`、`editor`、`viewer` 等项目级 ACL。  
也就是说：

- `owner` / `admin` 可以删除该 workspace 下任意项目
- `member` 可以创建项目
- `member` 只能删除自己创建的项目，**不能**删除其他成员创建的项目

这就是 W5.3 的当前定稿，也是现有后端代码已经执行的真实语义。

## 代码真源

- Workspace 角色动作矩阵：[`backend/src/workspaces/http.rs`](../../backend/src/workspaces/http.rs)
  - `delete_any_project`：`owner` / `admin` = allowed，`member` = denied
  - `create_project`：`owner` / `admin` / `member` = allowed
- 项目删除策略：[`backend/src/projects/routes/handlers/detail/delete.rs`](../../backend/src/projects/routes/handlers/detail/delete.rs)
  - `owner` / `admin` 可删除任意项目
  - `member` 仅当 `actor_user_id == project_owner_user_id` 时可删除

## 为什么先不做项目级角色

当前阶段优先保证：

1. Workspace 成员协作语义清晰
2. project/workspace/jobs/Harness 的可见范围一致
3. 不让“普通成员误删别人项目”

在这个目标下，workspace-level 默认策略已经足够，而且更容易和现有实现保持一致。

如果现在提前引入 `app_project_member` 或 JSON policy，会立刻带来这些额外成本：

- 列表、详情、删除、导出、jobs、Harness 都要重新定义“项目可见”与“项目可写”
- OpenAPI、Flutter `rust_api`、前端入口和回归矩阵都要同步扩面
- 需要补充成员继承规则：workspace 成员是否默认拥有 project viewer？被移出 workspace 后 project ACL 是否仍保留？

这些都不是当前 W5.3 收口必须要回答的问题。

## 与 W5.2 的关系

`W5.2` 仍然保留，但它现在属于 **可选增强项**，而不是当前 workspace 基线的缺口。

只有在出现以下业务信号之一时，才建议重开 W5.2：

- 同一 workspace 内需要“只读协作者”
- 同一 workspace 内需要限制成员只能看到部分项目
- 企业客户明确要求项目级授权审计
- 运营或法务要求项目级访问边界独立于 workspace 成员关系

在没有这些触发条件之前，继续沿用 W5.3 的默认策略更稳。

## 对产品与运营的可读描述

- Workspace 是协作边界
- Project 是该边界内的业务对象
- 普通成员可以在团队里创建自己的项目
- 普通成员不能删除别人创建的项目
- 管理员和 owner 负责团队级项目治理

## 对后续计划的影响

- **W5.3**：本文件补齐为书面定稿
- **W5.2**：继续保留为可选增强，不在当前阶段承诺
- **W8**：与 billing scope 无直接耦合
- **W9/W10**：继续沿用 workspace 成员语义作为排障与观测主轴

## 关联文档

- 总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)
- 路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)
- 计费口径：[`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md)
