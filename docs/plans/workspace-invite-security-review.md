# Workspace Invite Security Review（W9.4）

**目标**：对当前 workspace 邀请机制做安全审视，明确现有防线、剩余风险与后续收口项。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。  
运行路径：[`workspace-invite-runbook.md`](./workspace-invite-runbook.md)。  
安全边界：[`workspace-security-boundary.md`](./workspace-security-boundary.md)。
发布收口：[`workspace-release-checklist.md`](./workspace-release-checklist.md)。

## 1) 当前实现摘要

当前邀请链路：

1. `POST /api/v1/workspaces/{workspace_id}/invites`
   - owner/admin 才能创建
   - 角色仅允许 `admin` / `member`
   - `expires_in_hours` 限制在 `1..=720`
   - token 由 `Uuid::new_v4().to_string()` 生成
2. `POST /api/v1/workspaces/invites/accept`
   - 空 token -> `400`
   - token 不存在 -> `404`
   - `status != pending` 或已过期 -> `409`
   - 接受成功后 upsert membership，并把 invite 标记为 `accepted`
3. `GET /api/v1/workspaces/{workspace_id}/invites`（owner/admin）  
   - 分页信封 `items` + `has_more`；旧客户端若仍按数组解析会失败，需升级。
4. `DELETE …/invites/{invite_id}`：`pending` → `revoked`；非 pending 返回冲突类错误。
5. `POST …/invites/{invite_id}/resend`：**轮换 token** 并按请求体或默认规则延长 `expires_at`；旧 token 即刻失效。

辅助控制：

- `TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR`
- `app_workspace_audit`（含 `workspace_invite_revoked` / `workspace_invite_resent` 等）

## 2) 当前已有防线

### 2.1 权限前置

- 非 owner/admin 不能创建 invite
- invite role 不能直接给 `owner`

### 2.2 生命周期控制

- token 有过期时间
- invite 只有 `pending` 才能被接受
- 接受后状态会变为 `accepted`

### 2.3 滥用限制

- workspace 维度 mutation rate limit（含 create / accept / **revoke** / **resend**）
- 审计日志记录 invite create / accept / **revoke** / **resend**

## 3) 当前主要风险

### 3.1 token 本质上是 bearer secret

当前 token 只要拿到就能尝试 accept。  
这意味着：

- 如果通过不安全渠道转发，任何拿到 token 的人都能使用
- 当前实现没有把 token 与预期 email / 预期接收者账户强绑定

这不是实现 bug，而是当前产品形态的安全边界。

### 3.2 email 目前更像元数据，不是强校验因子

invite 创建时保存了 `email`，但 accept 时主要依据 token。  
所以现在的安全语义更接近：

> “谁拿到 token，谁就能按该 invite 加入”

而不是：

> “只有目标 email 的那个人才能加入”

### 3.3 缺少重放与异常 accept 的告警策略

目前有审计，但还缺：

- 高频 accept 失败告警
- 大量过期 invite 的统计告警
- 同一 workspace 短时间大量发 invite 的额外通知策略

### 3.4 邮件路径尚未接入

一旦未来接入邮件发送，风险面会扩大到：

- 邮件链接泄露
- 邮件转发
- 模板中暴露过多上下文

所以现在先把无邮件路径的边界写清楚很重要。

## 4) 风险等级建议

| 风险 | 当前等级 | 说明 |
|------|----------|------|
| token 被截获后被他人使用 | `medium` | 依赖分发渠道安全；当前产品模型接受这一边界 |
| 非 owner/admin 滥发邀请 | `low` | 已有应用层权限拦截 |
| 最后一个 owner 被 invite 流绕过 | `low` | invite role 不允许 owner |
| 通过 accept 重放多次加入 | `low` | `status != pending` 会挡住 |
| 直连客户端绕过 Rust 创建/accept | `low` | invite 流走 Rust API，不应直连裸表 |
| 邮件路径未来泄露风险 | `medium` | 尚未接入，但应提前预留审视点 |

## 5) 建议的后续收口项

### 5.1 若产品要求更强绑定

可选加强项：

1. accept 时校验当前登录用户 email 与 invite email 一致
2. 或 accept 前要求二次确认邮箱/组织信息
3. 或在邮件路径中引入一次性深链 + 已登录账号确认

这些都属于产品/安全策略升级，不应在当前文档里假装已经存在。

### 5.2 观测与告警

建议后续纳入：

- invite create / accept fail 的计数指标
- 过期 invite 比例
- workspace 维度 invite 失败率

### 5.3 文档与训练

至少应保证：

- 运营知道 token 是敏感凭证，不应公开转发
- 客户端知道 `404` / `409` 的邀请边界含义
- 值班人员知道 accept 异常时先查 `app_workspace_invite` 与 `app_workspace_audit`

## 6) 当前默认策略

在产品没有升级到“账号与 email 强绑定 accept”之前，默认策略是：

1. **token 即短期 bearer secret**
2. **安全性主要依赖分发渠道、过期时间、状态机与审计**
3. **如需更强安全等级，应单独立项，而不是在现有 invite 流上口头假设**

## 7) 发布前最低检查项

每次改 invite 相关实现，至少核对：

1. owner/admin 限制还在
2. role 仍不能直接发 owner
3. `expires_in_hours` 边界仍有效
4. `pending -> accepted` 状态机未被绕开
5. 审计日志仍写入
6. rate limit 仍在入口前半段生效

## 8) 当前结论

当前 invite 机制对 **中低风险团队协作场景** 是可接受的，但它的安全边界必须被诚实描述：

- 它不是“强实名邮箱绑定邀请”
- 它是“带过期时间、带审计、带限流的 bearer token 邀请”

只要团队清楚这一点，后续无论是继续沿当前模型运营，还是升级到更强校验，都不会建立在错觉上。
