# Workspace Sensitive Operations Runbook（W9.3）

**用途**：为团队 Workspace 的敏感操作提供统一确认流程，避免在成员管理、owner 变更前置阶段、workspace 归档等动作上靠临场判断。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。  
安全边界：[`workspace-security-boundary.md`](./workspace-security-boundary.md)。  
运维排障：[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)。
发布收口：[`workspace-release-checklist.md`](./workspace-release-checklist.md)。

## 1) 当前哪些动作算“敏感操作”

在当前实现下，以下操作都应按敏感操作处理：

1. **移除成员**
   - `DELETE /api/v1/workspaces/{workspace_id}/members/{user_id}`
2. **降级成员角色**
   - `PATCH /api/v1/workspaces/{workspace_id}/members/{user_id}`
3. **成员主动离开 workspace**
   - `DELETE /api/v1/workspaces/{workspace_id}/members/me`
4. **归档 workspace**
   - `PATCH /api/v1/workspaces/{workspace_id}` 的 archive 语义
5. **任何未来的 owner 转让 / 删除 workspace**
   - 当前尚未开放 owner transfer 专用 flow，但一旦引入，应继承本文

这些操作的共同点：

- 会改变谁能看见项目、jobs、Harness、工作台
- 可能触发 `current_workspace` 自动回退
- 一旦执行错误，往往不是简单刷新页面能解决

## 2) 当前系统已经替你挡住了什么

Rust 应用层已内建的保护包括：

- **最后一个 owner 不能被降级**
  - `cannot demote the last workspace owner`
- **最后一个 owner 不能被移除**
  - `cannot remove the last workspace owner`
- **最后一个 owner 不能主动离开**
  - `cannot leave workspace as the last owner`
- **personal workspace 不能离开**
  - `cannot leave personal workspace`
- **owner 角色不能通过普通成员 PATCH 直接设入**
  - `role must be admin or member (owner requires transfer flow)`

这些保护很重要，但它们**不等于**完整操作流程。  
也就是说：系统能挡住最坏的几类误操作，但仍需要人类在执行前确认影响范围。

## 3) 最小确认清单

对每一次敏感操作，执行前至少确认：

1. **目标 workspace 是哪个**
   - `workspace_id`
   - 名称
   - `personal` 还是 `enterprise`
2. **目标用户是谁**
   - `user_id`
   - 当前角色
3. **这次动作会不会影响当前唯一 owner**
4. **这次动作会不会让目标用户失去关键项目 / job / workbench 访问**
5. **目标用户当前是否正停留在这个 workspace**
   - 若是，预期会触发 `current_workspace` 回退
6. **是否已有审计 / 工单 / 产品授权记录**

若其中任一项答不上来，默认不应直接执行。

## 4) 场景化确认流程

### 4.1 移除成员

执行前确认：

- 该用户确实应该失去所有该 workspace 访问权
- 该用户不是最后一个 owner
- 若该用户是当前活跃操作者之一，相关项目协作是否已有交接

执行后核查：

- `app_workspace_member` 记录已删除
- `app_workspace_audit` 有 `workspace_member_removed`
- 若该用户原本停留在此 workspace，其 `current_workspace_id` 已回退或将在下一次 `/me` 回读时修正

### 4.2 角色降级（例如 admin -> member）

执行前确认：

- 降级后该用户仍应保留哪些能力
- 是否会影响邀请、成员管理、删除项目等高权限动作
- 当前不是“把最后一个 owner 降级成非 owner”

执行后核查：

- `app_workspace_member.role` 已更新
- `app_workspace_audit` 有 `workspace_member_role_changed`
- 若前端仍展示旧权限，优先视为缓存/刷新问题，而不是再次写 DB

### 4.3 成员主动离开

执行前确认：

- 不是 personal workspace
- 不是最后一个 owner

执行后核查：

- membership 已删除
- `workspace_member_left` 已写审计
- `current_workspace_id` 命中时已回退 personal

### 4.4 归档 workspace

执行前确认：

- 该 workspace 下是否仍有活跃项目协作
- 是否已有明确“暂时下线 / 长期停用”的业务结论
- 是否需要先通知成员该 workspace 会从默认列表隐藏

执行后核查：

- `app_workspace.archived_at` 已写入
- 默认 `GET /api/v1/workspaces` 不再返回该 workspace
- 命中该 workspace 的 `current_workspace_id` 已回退 personal

## 5) 推荐执行方式

优先级从高到低：

1. **产品/UI 正常路径**
2. **受控 API 调用**
3. **SQL 修复**

原则：

- 能走应用层就不要先走 SQL
- SQL 只用于修复异常状态，不用于绕开当前权限设计
- 尤其不要通过 SQL 直接“伪造 owner 转让”来代替产品流程

## 6) 必留痕的信息

每次敏感操作至少保留以下记录之一：

- 工单链接
- 值班记录
- 内部审批记录
- 运营确认消息

并附上：

- `workspace_id`
- 目标 `user_id`
- 操作类型
- 操作原因
- 操作时间

## 7) 推荐 SQL 核查模板

```sql
-- 1. workspace 基本信息
SELECT id, owner_user_id, name, workspace_type, archived_at, created_at, updated_at
FROM public.app_workspace
WHERE id = '<workspace_uuid>';

-- 2. 当前成员列表
SELECT workspace_id, user_id, role, created_at, updated_at
FROM public.app_workspace_member
WHERE workspace_id = '<workspace_uuid>'
ORDER BY role DESC, created_at ASC;

-- 3. 目标用户 profile
SELECT user_id, current_workspace_id, updated_at
FROM public.app_user_profile
WHERE user_id = '<user_uuid>';

-- 4. 最近审计
SELECT id, action, actor_user_id, target_user_id, details, created_at
FROM public.app_workspace_audit
WHERE workspace_id = '<workspace_uuid>'
ORDER BY created_at DESC, id DESC
LIMIT 50;
```

## 8) 当前明确禁止的做法

在没有专门 owner transfer 产品流之前，禁止：

- 直接手工把任意成员改成 `owner`
- 先把最后一个 owner 降级，再补第二个 owner
- 为了“省事”删掉 workspace/member 数据再让用户重新进群
- 用 SQL 绕过 `cannot demote/remove/leave the last workspace owner`

这些做法会制造比原问题更难解释的状态。

## 9) 当前发布前要求

只要本次发布触及以下任一能力，就应至少对照本文过一遍：

- 成员管理 UI / API
- workspace 归档 / 恢复
- 当前 workspace 切换与自动回退
- owner/admin/member 权限矩阵

本 Runbook 的目标不是增加流程戏剧性，而是把“谁能动、动之前看什么、动后怎么验”固定下来。
