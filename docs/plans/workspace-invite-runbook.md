# Workspace Invite Runbook（W2.9）

本 Runbook 记录团队 Workspace 邀请的两条运营路径：**无邮件**（当前默认）与 **邮件发送**（后续可接入）。

若排障已超出邀请本身（例如成员明明被接受却仍看不到 workspace、`current_workspace` 回退异常、项目可见性不对），转到 [`workspace-operations-runbook.md`](./workspace-operations-runbook.md)。

## 1) 现状（已上线）

- 邀请创建：`POST /api/v1/workspaces/{workspace_id}/invites`
- 邀请接受：`POST /api/v1/workspaces/invites/accept`
- 数据表：`app_workspace_invite`（`pending/accepted/revoked`）
- 速率限制：`TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR`（默认 120 / workspace / hour）
- 审计：`app_workspace_audit` 记录邀请创建、接受、成员变更

## 2) 无邮件路径（默认）

适用于内测或运营手动分发链接/口令。

1. 管理员在 UI 或 API 创建邀请。
2. 服务端返回 `token`（一次性邀请口令）。
3. 运营通过安全渠道发给被邀请人（如企业 IM）。
4. 被邀请人调用 `POST /api/v1/workspaces/invites/accept` 完成加入。

注意：

- `token` 等同短期凭证，禁止公开群组传播。
- 若 `status != pending` 或已过期，接口返回冲突错误，需重新发起邀请。

## 3) 邮件路径（待接入）

推荐接入后端邮件服务（例如 Postmark/SES）并保持 API 不变：

1. `create invite` 后由后端异步发送邮件（模板包含 `token` 或封装链接）。
2. 邮件链接跳转到前端邀请接受页（当前最小路由：`/join-workspace` 或 `/join-workspace/<token>`；也兼容 `invite_token|inviteToken|token` query），前端提交 `token` 到接受接口。
3. 失败重试与死信队列按现有 jobs 体系处理。

建议补充：

- 邀请邮件幂等键：`invite_id`
- 邮件发送状态回写（可选）到 `details` 或独立表
- 模板变量：workspace 名称、角色、过期时间

## 4) 常见故障排查

- **返回 `429 quota_exceeded`**：检查 `TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR` 与短时批量导入行为。
- **返回 `409 conflict`**：通常为邀请已接受/已失效，重新创建邀请。
- **返回 `403 forbidden`**：操作者非 workspace `owner/admin`。
- **成员未生效**：检查 `app_workspace_member` 与 `app_workspace_audit` 是否有写入记录。

## 5) 运维查询片段

```sql
-- 最近 50 条邀请记录
SELECT id, workspace_id, email, role, status, expires_at, invited_by, accepted_by, created_at
FROM public.app_workspace_invite
ORDER BY created_at DESC
LIMIT 50;

-- 某 workspace 最近 100 条审计
SELECT id, action, actor_user_id, target_user_id, details, created_at
FROM public.app_workspace_audit
WHERE workspace_id = '<workspace_uuid>'
ORDER BY created_at DESC, id DESC
LIMIT 100;
```
