# Workspace Security Boundary（W9.1）

**目标**：把团队 Workspace 的安全边界写清楚：Rust `backend/` 通过 `DATABASE_URL` 直连 Postgres 时，哪些能力来自应用层，哪些能力来自 Supabase RLS，哪些地方绝不能“以为数据库会替你挡”。  
关联总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。  
关联路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。  
运维排障：[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)。

## 1) 结论先行

当前仓库的默认安全边界是：

1. **Rust API 把 `DATABASE_URL` 视为特权后端连接**，**不依赖 Supabase RLS 作为每个 HTTP/WS 请求的最终授权器**
2. **Flutter / Supabase 直连客户端** 若存在，仍受 RLS 约束；但这条路径 **不能** 替代 Rust API 的应用层授权
3. 只要请求经过 Rust `backend/`，就必须在 handler / helper 层显式校验：
   - 当前用户是谁
   - 当前用户是否是目标 workspace 成员
   - 当前用户角色是否允许该动作
   - 项目 / job / workbench / Harness attach 是否属于该 workspace

换句话说：**RLS 是补充护栏，不是 Rust API 的授权主链。**

## 2) 为什么这样定义

### 2.1 Rust 的 `DATABASE_URL` 并不等于“带终端用户身份的 Supabase 请求”

仓库当前运行方式见 [`backend/README.md`](../../backend/README.md)：

- `backend/` 直接读取 `DATABASE_URL`
- Rust 进程用 `sqlx` 直连 Postgres
- 用户身份来自 `Authorization: Bearer <jwt>`，由 Rust 校验并提取 `user_id`

这意味着：

- Rust 连接数据库时，并不会自动带上 Supabase `auth.uid()` 的“当前终端用户上下文”
- 即使数据库层开启了 RLS，Rust 也**不能**假设每条 SQL 都天然按最终用户隔离
- 尤其是多表 join、workspace 成员语义、当前 workspace fallback、job payload 派生可见性，都是应用层自己定义的，不是 PostgREST 自动代劳

因此，本仓库的安全设计应当按 **“特权后端 + 应用层授权”** 理解，而不是按 **“数据库自己看 JWT 做授权”** 理解。

### 2.2 RLS 仍然有价值，但职责不同

`supabase/migrations/` 中已对多张表启用 RLS，例如：

- `app_workspace` / `app_workspace_member`：[`20260506193000_app_workspace_foundation.sql`](../../supabase/migrations/20260506193000_app_workspace_foundation.sql)
- `app_project`、`app_script`、`app_asset`、`app_novel`、`app_video` 等：各自 migration 内的 `ENABLE ROW LEVEL SECURITY` / `CREATE POLICY`

这些 RLS 规则的主要价值是：

- 保护 **Supabase 直连客户端** 路径
- 为手工 SQL / Studio 排查提供一层额外的误操作缓冲
- 让 schema 本身保留“预期用户边界”的声明

但它们**不是** Rust API 授权正确性的充分条件。

## 3) 当前 RLS 与应用层的责任分工

### 3.1 RLS 负责什么

- `authenticated` 角色下的直连查询，只能看到策略允许的数据
- workspace 基础表有成员可见性约束：
  - `app_workspace_member_access`：workspace 必须存在该用户 membership
  - `app_workspace_member_self`：成员表仅允许用户操作自己的 membership 行
- 若未来有 Flutter/Supabase 直连读路径，RLS 是最后一道数据库侧护栏

### 3.2 Rust 应用层必须负责什么

以下能力必须由 Rust 显式校验，不可只依赖 RLS：

- **Workspace 成员关系**
  - `backend/src/workspaces/http.rs`
  - `require_workspace_member_role`
  - `require_workspace_admin_or_owner`
- **项目属于哪个 workspace，用户是否是该项目 workspace 成员**
  - `backend/src/projects/routes/common.rs`
  - `require_project_workspace_member_scope`
- **角色动作矩阵**
  - `backend/src/workspaces/http.rs`
  - `WorkspaceRoleAction`
  - `role_allows_workspace_action`
- **当前 workspace 自动回退 personal**
  - `reset_current_workspace_if_matches`
- **项目删除的 owner/admin/member 差异**
  - `backend/src/projects/routes/handlers/detail/delete.rs`
  - `can_delete_project_by_workspace_policy`
- **Jobs 通过 `project_uuid` / `project_numeric_id` 派生 workspace 可见性**
  - 这是应用层策略，不在数据库默认 RLS 表达范围内
- **Harness / WS attach / tool / production/script channel 的 workspace 门禁**
  - 这是应用层上下文协议，不能指望数据库自动理解 WebSocket 语义

## 4) Workspace 方向的最低授权清单

下面这些问题，只要答案不是“应用层已经显式判断”，就说明实现还不安全：

1. 这个 handler 有没有先拿到 `user_id`？
2. 如果目标资源属于 project，是否经过 `require_project_workspace_member_scope` 或等价 helper？
3. 如果目标资源属于 workspace，是否经过 `require_workspace_member_role` / `require_workspace_admin_or_owner`？
4. 如果动作区分 owner/admin/member，是否显式套用了 `WorkspaceRoleAction` 或等价策略？
5. 如果资源不是直接存 `workspace_id`（例如 jobs 由 payload 派生），是否把“派生后的 workspace 可见性”写清楚并校验？
6. 如果是 WS / Harness attach，是否在建立上下文时就完成成员校验，而不是等工具执行中再碰运气？
7. 如果 current workspace 失效，是否有 fallback 或明确拒绝语义？

## 5) 当前已落地的关键护栏

### 5.1 Workspace 本体

- `app_workspace` 与 `app_workspace_member` 已启用 RLS
- Rust 侧对 workspace 详情、PATCH、成员管理、邀请创建/列表都走 `require_workspace_admin_or_owner` 或 membership 校验

### 5.2 项目与工作台

- `app_project.workspace_id` 已成为 workspace 可见性边界
- 大部分项目详情/概览/workbench/publish 路径都已复用 `require_project_workspace_member_scope`
- 删除项目仍保留 owner/admin/member 差异，不是“member 只要看得见就能删”

### 5.3 当前上下文

- `GET /api/v1/me` 与部分项目列表路径对失效的 `current_workspace_id` 做 automatic fallback
- workspace 归档、成员离开当前 workspace 时会主动回退到 personal

### 5.4 邀请与成员生命周期

- 邀请接受由 Rust 应用层做 token / status / expires_at 校验
- “最后一个 owner 不可移除/降级” 也是应用层规则，不应交给 SQL 偶然约束

## 6) 哪些情况最容易误用 RLS

以下是后续开发最容易踩的坑：

- **误区 1：**“表开了 RLS，所以 Rust 直接查就安全”
  - 错。Rust 不是按终端用户身份经 PostgREST 发请求；它自己就是授权层

- **误区 2：**“只要 `owner_user_id = uid` 的老逻辑还在，workspace 也差不多”
  - 错。workspace 成员语义已经高于 owner 个人语义，尤其在项目共享、jobs、publish、Harness 上

- **误区 3：**“WS/agent/workbench 最后会碰数据库，所以前面不用校验”
  - 错。attach 一旦建立错误上下文，就可能把错误资源范围带入后续动作

- **误区 4：**“Supabase Studio 看不到这行，所以后端也一定拿不到”
  - 错。Studio / REST API 的 RLS 体验不能反推 Rust 直连行为

## 7) 新增代码时的评审准则

今后凡新增 workspace 相关后端能力，PR 至少要回答：

1. 资源的 workspace 边界是什么？
2. 授权靠哪个 helper？
3. 角色差异在哪里实现？
4. 这个路径如果绕过前端，直接 curl / WS 调用，会不会越权？
5. 如果数据库未来策略变化，Rust 授权是否仍自洽？

建议优先复用现有 helper，而不是再发明一套隐式规则：

- `require_workspace_member_role`
- `require_workspace_admin_or_owner`
- `require_project_workspace_member_scope`
- `can_delete_project_by_workspace_policy`
- `reset_current_workspace_if_matches`

## 8) 对 W9.2 / 后续工作的影响

本文件先把 **W9.1 文档边界** 定下来，后续再推进：

- **W9.2**：若存在 Supabase 直连客户端路径，补 RLS 与 Rust 语义一致性测试
- **W10.1**：把 `workspace_id` 进入 trace / logs，便于排查授权与作用域问题
- **W8**：计费若切到 workspace 口径，也必须沿用同样的“应用层为主、RLS 为辅”原则

## 9) 当前默认结论

除非未来显式引入“数据库按每请求用户身份执行 SQL”的机制，并完成全链路验证，否则本仓库的默认原则保持为：

- **Rust `DATABASE_URL` = 特权后端连接**
- **授权真源 = Rust 应用层**
- **RLS = 直连客户端与数据库层补充护栏**

这条结论是团队 Workspace 多用户能力的安全基线。
