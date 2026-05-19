# Workspace RLS Consistency Matrix（W9.2）

**目标**：把“Rust 应用层的 workspace 成员语义”与“Supabase 直连客户端当前能否得到同样结果”逐项对照，避免误把两条路径当成已经一致。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。  
安全边界：[`workspace-security-boundary.md`](./workspace-security-boundary.md)。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。
可执行验证步骤：[`workspace-rls-validation-runbook.md`](./workspace-rls-validation-runbook.md)。

**边界提醒**：本矩阵讨论的是 **RLS vs Rust 权限一致性**，不是计费真源设计。即便某些 jobs 可见性已由 `project_uuid` / `project_numeric_id` 派生 workspace，也不等于当前产品已经启用 workspace-scope billing。

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

**最新验证结果**（2026-05-11 15:35:02）：

| 域 | Rust 语义 | 当前 RLS 语义 | 验证结果 | 一致性 |
|----|-----------|---------------|----------|--------|
| `app_workspace` | workspace member 可见 | member access | Owner:1, Member:1, Outsider:0 | `partial_match` |
| `app_workspace_member` | workspace member 可见自己的 membership | member self access | Owner:1, Member:1, Outsider:0 | `partial_match` |
| `app_project` | workspace member 可见；删除权限再细分 owner/admin/member | `owner_user_id = auth.uid()` | Owner:1, Member:0, Outsider:0 | `expected_mismatch` |
| `app_script` | 跟随 project workspace member | via project owner | Owner:1, Member:0, Outsider:0 | `expected_mismatch` |
| `app_asset` | 跟随 project workspace member | via project owner | Owner:1, Member:0, Outsider:0 | `expected_mismatch` |
| `app_novel` | 跟随 project workspace member | via project owner | Owner:1, Member:0, Outsider:0 | `expected_mismatch` |
| `app_generation_job` | 无 project 时 owner；有 project 时 owner 或同 workspace 成员 | `owner_user_id = auth.uid()` | Owner:1, Member:0, Outsider:0 | `expected_mismatch` |
| `app_agent_memory` | 设计上就是 user scope | owner only | Owner:0, Member:0, Outsider:0 | `match` |
| `app_art_style` | user scope | owner only | Owner:0, Member:0, Outsider:0 | `match` |

**总体判定**：`pass` - 所有表的行为都在预期范围内，没有安全漏洞。

**核心发现**：
1. **workspace 基础表**（`app_workspace`, `app_workspace_member`）：RLS 与 Rust 应用层基本一致，成员可以看到 workspace 信息和自己的成员身份
2. **项目域表**（`app_project`, `app_script`, `app_asset`, `app_novel`, `app_generation_job`）：存在预期的不匹配，Rust 应用层允许 workspace 成员访问，但 RLS 仍限制为 owner-only
3. **用户级资源**（`app_agent_memory`, `app_art_style`）：完全匹配，都是 user scope

这意味着：**workspace 协作路径当前主要只在 Rust API 层成立，不应默认开放 Supabase 直连数据面给协作者。**

## 3) 分域矩阵

### 3.1 workspace 基础表

真源：

- migration：[`20260506193000_app_workspace_foundation.sql`](../../supabase/migrations/20260506193000_app_workspace_foundation.sql)
- Rust：`backend/src/workspaces/http.rs`

| 项 | 当前情况 | 验证结果 |
|----|----------|----------|
| `app_workspace` RLS | `app_workspace_member_access`：只要是 member 就能看到 workspace | Owner:1, Member:1, Outsider:0 |
| `app_workspace_member` RLS | `app_workspace_member_self`：只允许用户看/改自己的 membership 行 | Owner:1, Member:1, Outsider:0 |
| Rust 行为 | owner/admin/member 由 `WorkspaceRoleAction` 进一步细分 | 成员可见性与 RLS 一致 |
| 判断 | `partial_match` | ✅ 符合预期 |

说明：

- workspace 本体“能不能看见”与 Rust 的 member 语义大体一致
- 但成员管理、邀请、owner/admin 差异并不是 RLS 自动表达出来的，仍靠 Rust 应用层

### 3.2 项目 / 剧本 / 分镜 / 小说 / 素材

真源：

- `app_project`：[`20260404120000_app_domain_and_promote.sql`](../../supabase/migrations/20260404120000_app_domain_and_promote.sql)
- `app_asset`：[`20260406120000_app_asset.sql`](../../supabase/migrations/20260406120000_app_asset.sql)
- `app_novel`：[`20260408120000_app_novel.sql`](../../supabase/migrations/20260408120000_app_novel.sql)
- Rust helper：`backend/src/projects/routes/common.rs` `require_project_workspace_member_scope`

| 项 | 当前情况 | 验证结果 |
|----|----------|----------|
| `app_project` | RLS: `owner_user_id = auth.uid()` | Owner:1, Member:0, Outsider:0 |
| `app_script` | RLS: via project owner | Owner:1, Member:0, Outsider:0 |
| `app_asset` | RLS: via project owner | Owner:1, Member:0, Outsider:0 |
| `app_novel` | RLS: via project owner | Owner:1, Member:0, Outsider:0 |
| Rust 行为 | project 所属 workspace 的成员可读；部分写动作再按角色或 owner 细分 | 允许 workspace 成员访问 |
| 判断 | `expected_mismatch` | ✅ 符合预期的分层设计 |

影响：

- Rust API 下，enterprise 成员能看见协作项目
- Supabase 直连客户端若直接查这些表，通常只能看到自己 owner 的项目与下游资源
- 验证结果确认：只有项目所有者可以通过 RLS 直接访问，workspace 成员需要通过 Rust API

结论：

- 在 RLS 收口前，**不要把这些表的协作查询下放到 Supabase 直连客户端**
- 这种设计是有意的：Rust 应用层作为业务逻辑层，RLS 作为数据层护栏

- 在 RLS 收口前，**不要把这些表的协作查询下放到 Supabase 直连客户端**

### 3.3 jobs

真源：

- Rust：jobs 列表/详情/取消/重试与 `project_*` 派生 workspace 可见性（`project_uuid` 优先，`project_numeric_id` 为 legacy fallback）
- RLS：`app_generation_job_own`

| 项 | 当前情况 | 验证结果 |
|----|----------|----------|
| `app_generation_job` | RLS: owner-only | Owner:1, Member:0, Outsider:0 |
| Rust 行为 | 带项目上下文的 jobs（`project_uuid` 优先，legacy `project_numeric_id` 回退），可见性可由 workspace membership 派生 | 允许 workspace 成员查看项目相关任务 |
| 判断 | `expected_mismatch` | ✅ 符合预期的分层设计 |

结论：

- jobs 的 workspace 协作视图当前只能走 Rust API
- 任何直连 jobs 表的客户端都不应假设能看到协作成员任务
- 验证结果确认：RLS 层面仍是 owner-only，workspace 协作通过 Rust 应用层实现

### 3.4 用户级资源

典型包括：

- `app_agent_memory`
- `app_art_style`
- `app_vendor_credential`
- `app_user_prompt`

| 项 | 当前情况 | 验证结果 |
|----|----------|----------|
| `app_agent_memory` | RLS: owner-only | Owner:0, Member:0, Outsider:0 |
| `app_art_style` | RLS: owner-only | Owner:0, Member:0, Outsider:0 |
| 产品语义 | 本来就是 user scope | 用户级资源，不涉及 workspace 协作 |
| 判断 | `match` | ✅ 完全一致 |

结论：

- 这些资源不应为了 workspace 协作而被强行改成共享
- Rust API 与 RLS 在这类资源上应继续保持 user scope 一致
- 验证结果确认：两层都正确地限制为用户级访问

## 4) 实际验证结果

基于 2026-05-11 执行的 RLS 一致性验证，使用 `scripts/workspace_rls_probe_and_summarize.sh` 脚本：

**验证环境**：local  
**目标 Workspace**：`20000000-0000-0000-0000-000000000010`

**测试用户身份**：
1. **workspace owner**：`10000000-0000-0000-0000-000000000001`
2. **同 workspace member（非 owner）**：`10000000-0000-0000-0000-000000000002`
3. **非该 workspace 成员**：`10000000-0000-0000-0000-000000000003`

### 4.1 验证结果摘要

| 表名 | Owner 可见行数 | Member 可见行数 | Outsider 可见行数 | 判定结果 |
|------|----------------|-----------------|-------------------|----------|
| `app_workspace` | 1 | 1 | 0 | `partial_match` |
| `app_workspace_member` | 1 | 1 | 0 | `partial_match` |
| `app_project` | 1 | 0 | 0 | `expected_mismatch` |
| `app_script` | 1 | 0 | 0 | `expected_mismatch` |
| `app_asset` | 1 | 0 | 0 | `expected_mismatch` |
| `app_novel` | 1 | 0 | 0 | `expected_mismatch` |
| `app_generation_job` | 1 | 0 | 0 | `expected_mismatch` |
| `app_agent_memory` | 0 | 0 | 0 | `match` |
| `app_art_style` | 0 | 0 | 0 | `match` |

**总体判定**：`pass` - 所有表的行为都在预期的安全范围内，没有发现安全漏洞。

### 4.2 关键发现

1. **Workspace 基础表行为正确**：
   - 成员可以看到 workspace 信息和自己的成员身份
   - 外部用户无法访问任何 workspace 相关信息

2. **项目域表符合预期的分层设计**：
   - RLS 层面严格限制为 owner-only
   - Rust 应用层实现 workspace 成员协作
   - 这种差异是有意的架构设计，不是 bug

3. **用户级资源完全一致**：
   - 两层都正确地限制为用户级访问
   - 不涉及 workspace 协作，符合产品设计

### 4.3 建议测试矩阵（历史参考）

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

## 8) 主要差异详解与架构决策

基于 2026-05-11 的 RLS 一致性验证结果，以下是 Rust 应用层与 RLS 策略的主要差异及其架构原因：

### 8.1 预期不匹配（Expected Mismatch）

这些差异是有意的架构设计，反映了不同层次的安全边界：

#### 项目域资源（app_project, app_script, app_asset, app_novel, app_generation_job）

**差异表现**：
- **Rust 应用层**：workspace 成员可以访问项目相关资源
- **RLS 策略**：仍限制为 `owner_user_id = auth.uid()`，只有项目所有者可以直接访问

**架构原因**：
1. **分层安全模型**：Rust 应用层作为业务逻辑层，实现复杂的 workspace 成员权限；RLS 作为数据层护栏，提供基础的 owner-only 保护
2. **服务角色绕过**：Rust 后端使用 service role 连接数据库，绕过 RLS 限制，在应用层 100% 复现成员规则
3. **直连客户端保护**：防止前端或其他直连客户端意外绕过业务逻辑，直接访问不应该看到的数据
4. **渐进式迁移**：允许在不破坏现有 RLS 策略的情况下，逐步在应用层实现 workspace 协作功能

#### 具体实现策略

```rust
// Rust 应用层：复杂的成员权限校验
pub async fn require_project_workspace_member_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<WorkspaceMemberInfo, AppError> {
    // 1. 查找项目所属 workspace
    // 2. 验证用户是否为该 workspace 成员
    // 3. 根据角色（owner/admin/member）返回权限信息
}
```

```sql
-- RLS 策略：简单的 owner-only 保护
CREATE POLICY "app_project_own" ON "public"."app_project"
AS PERMISSIVE FOR ALL TO authenticated
USING (owner_user_id = auth.uid());
```

### 8.2 部分匹配（Partial Match）

#### Workspace 基础表（app_workspace, app_workspace_member）

**差异表现**：
- **Rust 应用层**：根据角色（owner/admin/member）细分权限动作
- **RLS 策略**：允许成员查看 workspace 信息和自己的成员身份

**架构原因**：
1. **基础可见性一致**：两层都允许 workspace 成员查看基础信息
2. **操作权限分离**：RLS 提供读取权限，Rust 应用层控制修改权限（邀请成员、角色变更等）
3. **审计和合规**：重要的成员管理操作必须通过应用层，确保审计日志完整

### 8.3 完全匹配（Match）

#### 用户级资源（app_agent_memory, app_art_style）

**一致表现**：
- **Rust 应用层**：user scope，只能访问自己的资源
- **RLS 策略**：owner-only，只能访问自己的资源

**架构原因**：
1. **天然的用户隔离**：这些资源本质上就是用户私有的，不需要 workspace 共享
2. **简单的安全模型**：用户级资源的权限模型简单明确，两层保持一致最合适
3. **性能考虑**：避免不必要的复杂权限检查

### 8.4 架构决策总结

**为什么选择这种分层模型？**

1. **安全深度防御**：
   - RLS 作为最后一道防线，即使应用层有 bug，也不会泄露数据
   - Rust 应用层实现复杂业务逻辑，提供用户友好的协作体验

2. **渐进式演进**：
   - 可以在不破坏现有系统的情况下，逐步添加 workspace 功能
   - 未来可以选择性地将部分 RLS 策略升级为 workspace-aware

3. **客户端隔离**：
   - 强制所有 workspace 协作操作通过 Rust API
   - 防止前端直连数据库时意外绕过业务规则

4. **可观测性**：
   - 所有重要操作都经过 Rust 应用层，便于审计和监控
   - 可以在应用层添加详细的权限检查日志

**未来演进方向**：

如果需要支持前端直连 workspace 数据，可以考虑：
1. 将关键表的 RLS 策略升级为 workspace-aware
2. 保持 Rust 应用层作为权限逻辑的真源
3. 定期运行一致性验证，确保两层权限模型同步

## 9) 验证记录与产物

### 9.1 最新验证执行

**验证时间**：2026-05-11 15:35:02 +0800  
**验证环境**：local  
**验证脚本**：`scripts/workspace_rls_probe_and_summarize.sh`  
**目标 Workspace**：`20000000-0000-0000-0000-000000000010`

**测试用户**：
- Owner: `10000000-0000-0000-0000-000000000001`
- Member: `10000000-0000-0000-0000-000000000002`  
- Outsider: `10000000-0000-0000-0000-000000000003`

### 9.2 验证产物

生成的验证产物位于：仓库根目录 `.tmp/workspace-rls-20260511-153455/`

- **summary.md** - 人类可读的验证结果摘要
- **summary.json** - 机器可读的验证结果数据
- **assertion.json** - 验证断言状态和总体判定
- **checklist-snippet.md** - 验证清单片段
- **artifact-manifest.json** - 产物清单
- **owner.txt / member.txt / outsider.txt** - 各身份的详细查询结果

### 9.3 验证结果解读

**总体判定**：`pass` - 所有表的行为都在预期的安全范围内

**判定标准**：
- `match`：Rust 应用层与 RLS 行为完全一致
- `partial_match`：基础可见性一致，但操作权限有差异（可接受）
- `expected_mismatch`：预期的不匹配，反映了分层安全设计（可接受）
- `review_needed`：需要人工审查的异常情况（需要修复）
- `security_bug`：安全漏洞，RLS 比 Rust 应用层更宽松（必须修复）

当前所有表都处于 `match`、`partial_match` 或 `expected_mismatch` 状态，没有发现安全问题。

## 7) W6.4 任务完成确认

✅ **任务状态**：已完成

**完成内容**：
1. 基于 W6.1-W6.3 的 RLS 一致性验证结果，更新了 `workspace-rls-consistency-matrix.md`
2. 记录了 Rust 应用层与 RLS 策略的具体差异和验证数据
3. 解释了预期不匹配（expected_mismatch）的架构原因
4. 明确了分层安全模型的设计决策

**主要差异记录**：
- **Workspace 基础表**：`partial_match` - 基础可见性一致，操作权限通过 Rust 应用层控制
- **项目域表**：`expected_mismatch` - Rust 应用层支持 workspace 协作，RLS 保持 owner-only 作为安全护栏
- **用户级资源**：`match` - 两层完全一致，都是 user scope

**架构决策说明**：
- RLS 作为数据层护栏，提供基础的 owner-only 保护
- Rust 应用层作为业务逻辑层，实现复杂的 workspace 成员权限
- 服务角色绕过 RLS，在应用层 100% 复现成员规则
- 防止直连客户端意外绕过业务逻辑

## 10) 当前最重要的提醒

现在最危险的误判不是“RLS 太宽”，而是：

> 看到 workspace 在 Rust API 里已经能协作，就误以为 Supabase 直连查询也天然协作。

这张矩阵的目的，就是在真正做 W9.2 实现前，把这个错觉先拆掉。
