# Workspace RLS Consistency Matrix（W9.2）

**目标**：把“Rust 应用层的 workspace 成员语义”与“Supabase 直连客户端当前能否得到同样结果”逐项对照，避免误把两条路径当成已经一致。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。  
安全边界：[`workspace-security-boundary.md`](./workspace-security-boundary.md)。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。
可执行验证步骤：[`workspace-rls-validation-runbook.md`](./workspace-rls-validation-runbook.md)。

## 1) 为什么需要这张表

当前仓库同时存在两层权限语义：

1. **Rust API / Harness / jobs**
   - 以 workspace membership 与应用层 helper 为真源
2. **Supabase RLS**
   - 对直连客户端生效
   - 但不少历史表仍是 owner-only 语义

所以“Rust 能看见 / 能操作”的东西，并不自动等于“Supabase 直连客户端也能看见 / 能操作”。

W9.2 的任务不是立刻把所有 RLS 改完，而是先把 **哪些一致、哪些不一致、哪些必须禁止直连** 说清楚。

## 2) 当前结论摘要

| 域 | Rust 语义 | 当前 RLS 语义 | 一致性 |
|----|-----------|---------------|--------|
| `app_workspace` / `app_workspace_member` | workspace member / role | member self / workspace member access | `partial_match` |
| `app_project` | workspace member 可见；删除权限再细分 owner/admin/member | `owner_user_id = auth.uid()` | `mismatch` |
| `app_script` | 跟随 project workspace member | via project owner | `mismatch` |
| `app_asset` / `app_script_asset` | 跟随 project workspace member | via project owner | `mismatch` |
| `app_novel` / novel events | 跟随 project workspace member | via project owner | `mismatch` |
| `app_generation_job` | 无 project 时 owner；有 project 时 owner 或同 workspace 成员 | `owner_user_id = auth.uid()` | `mismatch` |
| `app_agent_memory` | 设计上就是 user scope | owner only | `match` |
| `app_art_style` / vendor credential / user prompt 等用户级资源 | user scope | owner only | `match` |

这意味着：**workspace 协作路径当前主要只在 Rust API 层成立，不应默认开放 Supabase 直连数据面给协作者。**

## 3) 分域矩阵

### 3.1 workspace 基础表

真源：

- migration：[`20260506193000_app_workspace_foundation.sql`](../../supabase/migrations/20260506193000_app_workspace_foundation.sql)
- Rust：`backend/src/workspaces/http.rs`

| 项 | 当前情况 |
|----|----------|
| `app_workspace` RLS | `app_workspace_member_access`：只要是 member 就能看到 workspace |
| `app_workspace_member` RLS | `app_workspace_member_self`：只允许用户看/改自己的 membership 行 |
| Rust 行为 | owner/admin/member 由 `WorkspaceRoleAction` 进一步细分 |
| 判断 | `partial_match` |

说明：

- workspace 本体“能不能看见”与 Rust 的 member 语义大体一致
- 但成员管理、邀请、owner/admin 差异并不是 RLS 自动表达出来的，仍靠 Rust 应用层

### 3.2 项目 / 剧本 / 分镜 / 小说 / 素材

真源：

- `app_project`：[`20260404120000_app_domain_and_promote.sql`](../../supabase/migrations/20260404120000_app_domain_and_promote.sql)
- `app_asset`：[`20260406120000_app_asset.sql`](../../supabase/migrations/20260406120000_app_asset.sql)
- `app_novel`：[`20260408120000_app_novel.sql`](../../supabase/migrations/20260408120000_app_novel.sql)
- Rust helper：`backend/src/projects/routes/common.rs` `require_project_workspace_member_scope`

| 项 | 当前情况 |
|----|----------|
| Rust 行为 | project 所属 workspace 的成员可读；部分写动作再按角色或 owner 细分 |
| RLS 行为 | 仍多为 `owner_user_id = auth.uid()` 或 via project owner |
| 判断 | `mismatch` |

影响：

- Rust API 下，enterprise 成员能看见协作项目
- Supabase 直连客户端若直接查这些表，通常只能看到自己 owner 的项目与下游资源

结论：

- 在 RLS 收口前，**不要把这些表的协作查询下放到 Supabase 直连客户端**

### 3.3 jobs

真源：

- Rust：jobs 列表/详情/取消/重试与 `project_*` 派生 workspace 可见性
- RLS：`app_generation_job_own`

| 项 | 当前情况 |
|----|----------|
| Rust 行为 | 带项目上下文的 jobs，可见性可由 workspace membership 派生 |
| RLS 行为 | owner-only |
| 判断 | `mismatch` |

结论：

- jobs 的 workspace 协作视图当前只能走 Rust API
- 任何直连 jobs 表的客户端都不应假设能看到协作成员任务

### 3.4 用户级资源

典型包括：

- `app_agent_memory`
- `app_art_style`
- `app_vendor_credential`
- `app_user_prompt`

| 项 | 当前情况 |
|----|----------|
| 产品语义 | 本来就是 user scope |
| RLS 语义 | owner-only / self-only |
| 判断 | `match` |

结论：

- 这些资源不应为了 workspace 协作而被强行改成共享
- Rust API 与 RLS 在这类资源上应继续保持 user scope 一致

## 4) 建议测试矩阵

若要直接执行而不是手工拼 SQL / curl，优先使用 [`workspace-rls-validation-runbook.md`](./workspace-rls-validation-runbook.md) 里的探针脚本与记录模板。

当前还已有一轮本地 seeded 样本基线（2026-05-08）：

- owner：可见目标 workspace、本人 membership，以及 project / script / asset / novel / generation job
- member：可见目标 workspace 与本人 membership，但看不到 project / script / asset / novel / generation job
- outsider：上述目标表均不可见

这轮结果再次确认：当前 workspace 协作主语义仍在 Rust API 层，而不是 Supabase 直连 RLS 层。

至少准备三类身份：

1. **workspace owner**
2. **同 workspace member（非 owner）**
3. **非该 workspace 成员**

每类身份至少验证：

### 4.1 Rust API

- `GET /api/v1/me`
- `GET /api/v1/projects`
- 选一个 `project_id` 下的详情或 workbench 接口
- `GET /api/v1/jobs`（带 project 上下文的样本）

### 4.2 Supabase 直连

用同一用户身份直接读取：

- `app_workspace`
- `app_workspace_member`
- `app_project`
- `app_script`
- `app_asset`
- `app_novel`
- `app_generation_job`

### 4.3 判定结果

- 若 Rust allow、RLS deny：
  - 记为 **expected mismatch**
  - 前提是该路径当前本来就不允许直连客户端承担协作读写
- 若 Rust deny、RLS allow：
  - 记为 **security bug**
- 若二者都 allow / 都 deny：
  - 记为 **match**

## 5) 当前默认策略

在 W9.2 真正收口前，遵循以下默认策略：

1. **workspace 协作数据面默认走 Rust API**
2. **Supabase 直连客户端只承担已经确认与 RLS 一致的 user-scope 或 workspace-base-scope 数据**
3. **任何新开的直连查询，只要目标表仍是 owner-only RLS，就必须先过这张矩阵**

## 6) 收口标准

W9.2 可以视为完成，至少需要满足：

1. 这张矩阵覆盖当前实际使用的主要协作域
2. 团队明确哪些表/路径允许直连，哪些必须只走 Rust
3. 对于 `mismatch` 项，要么：
   - 补 RLS 到 workspace 语义
   - 要么书面声明“禁止直连，Rust-only”
4. 至少有一轮 staging 验证记录

## 7) 当前最重要的提醒

现在最危险的误判不是“RLS 太宽”，而是：

> 看到 workspace 在 Rust API 里已经能协作，就误以为 Supabase 直连查询也天然协作。

这张矩阵的目的，就是在真正做 W9.2 实现前，把这个错觉先拆掉。
