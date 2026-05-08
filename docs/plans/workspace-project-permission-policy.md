# Workspace Project Permission Policy（W5.3）

## 结论

当前 Workspace 项目权限采用 **workspace-level 默认策略 + 可选 project-level ACL 增强**。  
默认情况下，仍然是：

- `owner` / `admin` 可以删除该 workspace 下任意项目
- `member` 可以创建项目
- `member` 只能删除自己创建的项目，**不能**删除其他成员创建的项目

而当某个项目开始配置显式 `app_project_member` 行时：

- `viewer`：只读
- `editor`：可写
- `owner` / `admin` / 项目 owner：仍然天然拥有完全权限，不需要额外 project row

这意味着 W5.3 仍是默认回退语义，而 W5.2 现在已经有了可选增强落点。

## 代码真源

- Workspace 角色动作矩阵：[`backend/src/workspaces/http.rs`](../../backend/src/workspaces/http.rs)
  - `delete_any_project`：`owner` / `admin` = allowed，`member` = denied
  - `create_project`：`owner` / `admin` / `member` = allowed
- 项目 ACL helper：[`backend/src/projects/routes/common.rs`](../../backend/src/projects/routes/common.rs)
  - 默认无 `app_project_member` 时，workspace member 继续沿用原有读写回退
  - 一旦某项目存在显式 ACL 行，`viewer` / `editor` 开始对普通 member 生效
- 项目成员管理：[`backend/src/projects/routes/handlers/detail/members.rs`](../../backend/src/projects/routes/handlers/detail/members.rs)
  - `GET/POST/PATCH/DELETE /api/v1/projects/{project_id}/members*`
- 项目删除策略：[`backend/src/projects/routes/handlers/detail/delete.rs`](../../backend/src/projects/routes/handlers/detail/delete.rs)
  - `owner` / `admin` 可删除任意项目
  - 项目 owner 可删除自己的项目
  - `viewer` / `editor` 都不能越过项目删除门槛

## 为什么采用“默认回退 + 显式增强”

当前阶段优先保证：

1. Workspace 成员协作语义清晰
2. project/workspace/jobs/Harness 的可见范围一致
3. 不让“普通成员误删别人项目”

在这个目标下，workspace-level 默认策略已经足够，而且更容易和现有实现保持一致。

如果一开始就强制所有项目都走 `app_project_member`，会立刻带来这些额外成本：

- 列表、详情、删除、导出、jobs、Harness 都要重新定义“项目可见”与“项目可写”
- OpenAPI、Flutter `rust_api`、前端入口和回归矩阵都要同步扩面
- 需要补充成员继承规则：workspace 成员是否默认拥有 project viewer？被移出 workspace 后 project ACL 是否仍保留？

这些都不是当前 W5.3 收口必须要回答的问题。

## 与 W5.2 / W5.3 的关系

- **W5.3**：继续是默认语义
- **W5.2**：现在已具备后端可选增强落点
- 当前这版的取舍是：
  - 不要求所有项目都配置 ACL
  - 不打断现有 workspace 协作主路径
  - 只在需要“只读协作者 / 指定编辑者”的项目上显式启用

## 对产品与运营的可读描述

- Workspace 是协作边界
- Project 默认继承该边界
- 普通成员可以在团队里创建自己的项目
- 普通成员不能删除别人创建的项目
- 若某项目配置了显式 ACL，普通成员的读写权限会收敛到 `viewer` / `editor`
- 管理员和 owner 负责团队级项目治理

## 对后续计划的影响

- **W5.3**：本文件继续作为默认策略真源
- **W5.2**：后端显式 ACL 已落地，可继续补 Flutter / `rust_api` 管理入口
- **W8**：与 billing scope 无直接耦合
- **W9/W10**：继续沿用 workspace 成员语义作为排障与观测主轴

## 关联文档

- 总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)
- 路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)
- 计费口径：[`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md)
