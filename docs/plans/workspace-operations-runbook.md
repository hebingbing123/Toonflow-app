# Workspace Operations Runbook（W10.3）

本 Runbook 面向 staging / 生产排障，覆盖 **Workspace 生命周期、成员关系、当前上下文与项目可见性** 的常见问题。  
**真源优先级**：代码与现有契约优先于本文；若本文与实现不一致，以 `backend/src/workspaces/http.rs`、`backend/src/projects/routes/`、`GET /api/v1/me` / `PATCH /api/v1/me/current-workspace` / `POST /api/v1/workspaces/invites/accept` 的当前行为为准，并在同一 PR 修正文档。

关联文档：

- [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) — W1–W11 总表
- [`workspace-invite-runbook.md`](./workspace-invite-runbook.md) — 邀请专用运行手册
- [`workspace-release-checklist.md`](./workspace-release-checklist.md) — staging / 发布前统一检查单
- [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) — 当前竖切进度

## 1) 当前语义速记

排障时先记住这四张表，它们决定了绝大多数 workspace 问题：

- `public.app_workspace`：workspace 本体；`workspace_type` 为 `personal` 或 `enterprise`；`archived_at` 非空表示已归档
- `public.app_workspace_member`：成员关系与角色（`owner` / `admin` / `member`）
- `public.app_user_profile`：`current_workspace_id` 当前上下文
- `public.app_project`：项目归属；`workspace_id` 是项目可见性边界

当前实现中的关键行为：

- 用户切换 workspace：`PATCH /api/v1/me/current-workspace`
  - 非成员返回 **`403 forbidden`**
- 读取 `/api/v1/me` 或部分项目列表时：
  - 若 `current_workspace_id` 失效或用户已不再是成员，会自动回退到 personal workspace，并修正 profile
- 归档 workspace、成员主动离开 workspace 时：
  - 若命中 `current_workspace_id`，服务端会自动回退到 personal workspace
- 接受邀请：`POST /api/v1/workspaces/invites/accept`
  - token 不存在返回 **`404`**
  - token 空字符串返回 **`400`**
  - 邀请非 `pending` 或已过期返回 **`409 conflict`**
- 项目删除权限：
  - `owner` / `admin` 可删任意项目
  - `member` 只能删自己创建的项目；否则返回 **`403 forbidden`**
- jobs / Harness scope：
  - jobs 可见性按 **`project_uuid`**（首选）/ **`project_numeric_id`**（legacy fallback）派生 workspace
  - WS attach / 工作台上下文按 **`projectUuid`** / **`scriptUuid`** 优先，legacy numeric 仅作兼容回退

## 2) 快速分诊

先判断问题落在哪一层：

1. **Workspace 本体**：workspace 是否存在、是否被归档
2. **成员关系**：用户是否仍是该 workspace 的 member，角色是否正确
3. **当前上下文**：`current_workspace_id` 是否指向可访问 workspace
4. **项目归属**：项目是否在该 workspace 下，用户是否对该项目有正确权限
5. **邀请状态**：accept 失败是 token 不存在、已过期，还是已经被消费

推荐先跑只读 SQL，再决定是否需要受控修复。

## 3) 场景 A：用户“看不到某个 workspace / 项目”

### 预期行为

- 不是该 workspace 成员：workspace 详情/切换应返回 **`403`**
- workspace 已归档：默认列表不展示；仅 `include_archived=true` 时可见
- 项目在别的 workspace 下：当前 workspace 视角默认不可见

### 只读核查

```sql
-- 1. workspace 是否存在、是否已归档
SELECT id, owner_user_id, name, workspace_type, archived_at, created_at, updated_at
FROM public.app_workspace
WHERE id = '<workspace_uuid>';

-- 2. 用户是否仍是该 workspace 成员
SELECT workspace_id, user_id, role, created_at, updated_at
FROM public.app_workspace_member
WHERE workspace_id = '<workspace_uuid>'
  AND user_id = '<user_uuid>';

-- 3. 项目属于哪个 workspace，创建者是谁
SELECT id, legacy_id, name, workspace_id, owner_user_id, created_at, updated_at
FROM public.app_project
WHERE id = '<project_uuid>';

-- 4. 当前用户可见的 workspace 列表（数据库视角）
SELECT w.id, w.name, w.workspace_type, w.archived_at, m.role
FROM public.app_workspace w
JOIN public.app_workspace_member m
  ON m.workspace_id = w.id
WHERE m.user_id = '<user_uuid>'
ORDER BY
  CASE WHEN w.workspace_type = 'personal' THEN 0 ELSE 1 END,
  w.created_at ASC,
  w.id ASC;
```

### 判断与处理

- `app_workspace` 无记录：属于真实不存在，前端/接口应表现为不可见或 `404`
- `archived_at IS NOT NULL`：先确认是不是误归档；默认列表不展示是正常现象
- `app_workspace_member` 无记录：属于成员关系问题，不应靠前端缓存修复
- 项目 `workspace_id` 与用户当前 workspace 不一致：优先切 workspace，而不是直接改项目归属

## 4) 场景 B：`current_workspace_id` 指向失效或已归档 workspace

### 预期行为

- 读 `/api/v1/me`、部分项目列表路径会自动回退到 personal workspace
- 归档当前 workspace 或成员离开当前 workspace 时，服务端会主动把 `current_workspace_id` 重置到 personal workspace
- 如果 personal workspace 本身缺失，属于数据不一致，需要人工修复

### 只读核查

```sql
-- 1. 当前 profile 指向哪个 workspace
SELECT user_id, current_workspace_id, updated_at
FROM public.app_user_profile
WHERE user_id = '<user_uuid>';

-- 2. 当前 workspace 是否存在、是否已归档
SELECT id, owner_user_id, name, workspace_type, archived_at
FROM public.app_workspace
WHERE id = (
  SELECT current_workspace_id
  FROM public.app_user_profile
  WHERE user_id = '<user_uuid>'
);

-- 3. personal workspace 是否存在
SELECT id, owner_user_id, name, workspace_type, archived_at, created_at
FROM public.app_workspace
WHERE owner_user_id = '<user_uuid>'
  AND workspace_type = 'personal'
ORDER BY created_at ASC, id ASC;
```

### 受控修复

仅当自动回退没有生效，且确认用户确实已有 personal workspace 时，再执行：

```sql
-- 将 current_workspace_id 受控修回 personal workspace
UPDATE public.app_user_profile p
SET current_workspace_id = sub.id,
    updated_at = NOW()
FROM (
  SELECT id
  FROM public.app_workspace
  WHERE owner_user_id = '<user_uuid>'
    AND workspace_type = 'personal'
  ORDER BY created_at ASC, id ASC
  LIMIT 1
) AS sub
WHERE p.user_id = '<user_uuid>';
```

### 修复后验证

- 重新请求 `GET /api/v1/me`
- 确认 `current_workspace.workspace_type = personal`
- 确认项目列表已回到个人空间视角

## 5) 场景 C：成员被移除后仍声称上下文异常

### 预期行为

- 被移除后，该用户不再是 workspace 成员
- 若当时正停留在该 workspace，服务端应将其 `current_workspace_id` 回退到 personal
- 之后再切回该 workspace，应返回 **`403 forbidden`**

### 只读核查

```sql
-- 1. 成员记录是否已删除
SELECT workspace_id, user_id, role, created_at, updated_at
FROM public.app_workspace_member
WHERE workspace_id = '<workspace_uuid>'
  AND user_id = '<user_uuid>';

-- 2. profile 是否还停在被移除的 workspace
SELECT user_id, current_workspace_id, updated_at
FROM public.app_user_profile
WHERE user_id = '<user_uuid>';

-- 3. 最近审计记录
SELECT id, action, actor_user_id, target_user_id, details, created_at
FROM public.app_workspace_audit
WHERE workspace_id = '<workspace_uuid>'
  AND (
    target_user_id = '<user_uuid>'
    OR actor_user_id = '<user_uuid>'
  )
ORDER BY created_at DESC, id DESC
LIMIT 50;
```

### 判断与处理

- `app_workspace_member` 已无记录，且 `current_workspace_id` 已回到 personal：
  - 优先排查客户端缓存或旧页面未刷新
- `app_workspace_member` 已无记录，但 `current_workspace_id` 仍指向原 workspace：
  - 视为数据修复场景，按场景 B 的受控 SQL 修回 personal
- 审计缺少 `workspace_member_removed` / `workspace_member_left`：
  - 记录为观测缺口，不要先改业务数据掩盖问题

## 6) 场景 D：邀请接受失败、token 过期、状态冲突

### 预期行为

- `POST /api/v1/workspaces/invites/accept`
  - 空 token：**`400`**
  - token 不存在：**`404`**
  - 邀请已接受 / 已撤销 / 已过期：**`409`**

### 只读核查

```sql
SELECT
  id,
  workspace_id,
  email,
  token,
  role,
  invited_by,
  status,
  expires_at,
  accepted_by,
  accepted_at,
  created_at,
  updated_at
FROM public.app_workspace_invite
WHERE token = '<invite_token>';
```

### 判断与处理

- 无记录：不是“重试一次”的问题，应提示重新创建邀请
- `status != 'pending'`：属于已消费或已撤销，预期返回 `409`
- `expires_at < NOW()`：属于过期邀请，预期返回 `409`
- 接受成功但用户仍看不到 workspace：
  - 回到场景 A / B 检查 `app_workspace_member` 与 `current_workspace_id`

### 受控修复原则

- 不直接复活已过期 / 已接受邀请
- 默认做法是 **重新创建邀请**
- 只有在 staging 数据演练或明确人工审批下，才允许手工调整邀请状态

## 7) 场景 E：owner / admin / member 权限误判

### 当前权限基线

- `owner`
  - 可邀请成员、管理成员、管理计费、删除 workspace、删除任意项目
- `admin`
  - 可邀请成员、管理成员、删除任意项目
  - 不可管理计费，不可删除 workspace
- `member`
  - 可创建项目
  - 不可邀请成员，不可管理成员
  - 删除项目仅限自己创建的项目

### 只读核查

```sql
-- 1. 某用户在 workspace 内的角色
SELECT workspace_id, user_id, role, created_at, updated_at
FROM public.app_workspace_member
WHERE workspace_id = '<workspace_uuid>'
  AND user_id = '<user_uuid>';

-- 2. 项目创建者与 workspace 归属
SELECT id, name, workspace_id, owner_user_id, created_at
FROM public.app_project
WHERE id = '<project_uuid>';
```

### 判断与处理

- 用户根本不是成员：应返回 **`403`**，不是角色误判
- 用户是 `member`，删除别人项目返回 **`403 workspace member can only delete own projects`**：属预期
- 用户应是 `admin/owner` 却查到 `member`：
  - 先看审计是否有最近一次降级/转移操作
  - 再决定是否做受控角色修复

### 受控修复

```sql
-- 将角色受控修为 admin 或 member；不要手工造出非法 role
UPDATE public.app_workspace_member
SET role = 'admin',
    updated_at = NOW()
WHERE workspace_id = '<workspace_uuid>'
  AND user_id = '<user_uuid>';
```

注意：

- 不要把最后一个 `owner` 直接改没；这会绕过应用层保护
- 涉及 owner 调整时，优先通过产品/API 路径完成；无法通过 API 修复时，必须先做备份并留痕

## 8) 数据不一致与修复边界

以下情况属于 **数据不一致**，而不是普通权限错误：

- 用户没有 personal workspace
- `app_user_profile.current_workspace_id` 指向不存在的 workspace，且自动回退未生效
- `app_project.workspace_id` 为空或指向不存在 workspace
- `app_workspace_member.role` 出现非 `owner/admin/member` 值

推荐流程：

1. 先执行只读 SQL，截图或保存结果
2. 在工单/值班记录中注明影响用户、workspace、项目
3. 如需写 SQL，先备份相关行
4. 修复后立即做 API 级验证

备份模板：

```sql
-- 备份 profile
SELECT *
FROM public.app_user_profile
WHERE user_id = '<user_uuid>';

-- 备份 workspace / member / project
SELECT *
FROM public.app_workspace
WHERE id = '<workspace_uuid>';

SELECT *
FROM public.app_workspace_member
WHERE workspace_id = '<workspace_uuid>'
  AND user_id = '<user_uuid>';

SELECT *
FROM public.app_project
WHERE id = '<project_uuid>';
```

## 9) API / 契约验证清单

文档修复或 SQL 修复后，至少做一轮最小验证：

1. `GET /api/v1/me`：确认 `current_workspace` 是否符合预期
2. `PATCH /api/v1/me/current-workspace`：确认非成员返回 `403`，成员切换成功
3. `GET /api/v1/workspaces`：确认归档项默认隐藏；需要时用 `include_archived=true`
4. `POST /api/v1/workspaces/invites/accept`：确认 `400/404/409` 边界符合预期
5. 若涉及项目可见性：验证 `GET /api/v1/projects` 或项目详情

相关现有验证：

- `backend/src/app/pg_contract_tests/business_suite/me_current_workspace_switch_roundtrip.rs`
- `backend/src/app/pg_contract_tests/business_suite/workspaces_crud_roundtrip.rs`
- `backend/src/app/contract_smoke_tests/rest_projects_settings_skills/general/me.rs`
- `backend/src/app/contract_smoke_tests/rest_projects_settings_skills/general/workspaces_list.rs`

## 10) 不在本 Runbook 内的主题

这些能力仍需继续推进，但不阻塞本 Runbook 成立：

- W8：workspace 级计费 / 用量策略
- W9.1：RLS / service-role / Rust 直连安全评审
- W10.1：`workspace_id` 贯穿 HTTP / jobs / Harness 的结构化 trace

本 Runbook 只覆盖 **当前已上线行为** 的排障与受控修复。
