# Workspace Release Checklist

**用途**：把 workspace 方向在 staging / 发布前必须做的验证收成一张清单，避免 W9.2 / W9.3 / W9.4 / W10.3 各自有文档、但值班时没人知道先后顺序。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。  
进度记录：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)。

## 1) 这张清单覆盖什么

每次满足以下任一条件，都建议至少过一遍本文：

- 改了 workspace / member / invite / current workspace 相关后端逻辑
- 改了 workspace 相关 Flutter 主路径或成员管理入口
- 调整了 Supabase policy、workspace migration、member 审计逻辑
- 准备把 workspace 相关改动推到 staging 或生产

默认情况下，本文验证的是 **workspace 协作 / 可见性 / 恢复 / 治理** 语义；除非本次发布明确重开 [`workspace-billing-future-workspace-scope.md`](./workspace-billing-future-workspace-scope.md) 所述迁移，否则**不**把 `plan_tier` / `daily_job_quota` / `jobs_today` 的 workspace-scope cutover 当作本清单的默认范围。

## 2) 预备信息

开始前先准备：

- 目标环境：`local` / `staging`
- 目标 `workspace_id`
- 三类测试身份：
  - owner
  - member
  - outsider
- 若做 Rust API 对照：
  - 三个 Bearer token
- 若做 RLS probe：
  - `DATABASE_URL` 或可访问的本地 Supabase DB 容器
- 结果落点：
  - 工单
  - 发布说明
  - 值班记录

## 3) 必过检查

### 3.1 RLS / Rust 语义核对

按 [`workspace-rls-validation-runbook.md`](./workspace-rls-validation-runbook.md) 跑一轮：

1. owner
2. member
3. outsider

若三类身份都已准备好，优先直接跑 [`scripts/workspace_rls_probe_matrix.sh`](../../scripts/workspace_rls_probe_matrix.sh) 收完整矩阵。
若同时想把原始输出和摘要一并产出，优先改跑 [`scripts/workspace_rls_probe_and_summarize.sh`](../../scripts/workspace_rls_probe_and_summarize.sh)。
若当前是在本地空库做最小验证，可直接先跑 [`scripts/workspace_rls_seed_and_probe_sample.sh`](../../scripts/workspace_rls_seed_and_probe_sample.sh)。
若需要附发布记录，建议同时加 `OUTPUT_DIR=".tmp/workspace-rls-<date>"` 保存三份原始 probe 输出。
若需要贴工单或发布说明，继续用 [`scripts/workspace_rls_summarize.sh`](../../scripts/workspace_rls_summarize.sh) 产出 Markdown 摘要。
若是固定 sample 回归，继续用 [`scripts/workspace_rls_assert_sample.sh`](../../scripts/workspace_rls_assert_sample.sh) 直接做 pass/fail 断言。
若是 staging / 手工环境验收，继续用 [`scripts/workspace_rls_assert_summary.sh`](../../scripts/workspace_rls_assert_summary.sh) 对 `summary.md` 做 pass/fail 断言。
若需要把结果回填到本清单或工单，继续用 [`scripts/workspace_rls_render_checklist_snippet.sh`](../../scripts/workspace_rls_render_checklist_snippet.sh) 从 `summary.json` / `assertion.json` 生成 Markdown 片段。
若需要把整组验证结果交给后续自动化或值班记录，可继续用 [`scripts/workspace_rls_write_artifact_manifest.sh`](../../scripts/workspace_rls_write_artifact_manifest.sh) 生成 JSON manifest。
现在若直接跑 [`scripts/workspace_rls_probe_and_summarize.sh`](../../scripts/workspace_rls_probe_and_summarize.sh)，会默认把 `checklist-snippet.md` 与 `artifact-manifest.json` 一并产出。

推荐至少保留这一组产物：

- `owner.txt`
- `member.txt`
- `outsider.txt`
- `summary.md`
- `summary.json`
- `assertion.json`
- `checklist-snippet.md`
- `artifact-manifest.json`

最低要求：

- 至少保留一份 owner/member/outsider 的 probe 结果摘要
- 能区分：
  - `match`
  - `expected mismatch`
  - `security bug`

放行标准：

- 不允许存在新的 `Rust deny / RLS allow`
- 若出现 `Rust allow / RLS deny`，必须能明确归类为当前已声明的 Rust-only 协作域

### 3.2 当前上下文与自动回退

按 [`workspace-operations-runbook.md`](./workspace-operations-runbook.md) 核对以下场景：

1. 成员能看到自己应看的 workspace / project
2. 非成员切换 `current_workspace` 返回 `403`
3. `current_workspace_id` 指向失效或已归档 workspace 时，会自动回退 personal
4. 成员被移除后，再读 `/api/v1/me` 不会残留错误上下文

最低记录：

- `/api/v1/me` 验证结果
- 至少一个 `403 forbidden` 例子
- 至少一个 fallback-to-personal 例子

### 3.3 敏感操作演练

按 [`workspace-sensitive-operations-runbook.md`](./workspace-sensitive-operations-runbook.md) 过一遍最小动作：

1. 移除一个非 owner 成员
2. 降级一个 admin 到 member（若环境样本具备）
3. 验证最后一个 owner 不能被移除/降级

最低要求：

- `app_workspace_audit` 有对应审计记录
- 不通过 SQL 绕过应用层保护

### 3.4 Invite 边界确认

按 [`workspace-invite-security-review.md`](./workspace-invite-security-review.md) 与 [`workspace-invite-runbook.md`](./workspace-invite-runbook.md) 核对：

1. owner/admin 才能创建 invite
2. invite role 不能直接发 owner
3. 过期 token 返回冲突态，不会被 accept 成功
4. 已接受 token 不会被重复 accept

最低要求：

- 保留一次正常 accept
- 保留一次过期或状态冲突 accept
- 在记录里明确当前 token 仍是短期 bearer secret，而非邮箱强绑定

## 4) 可选增强检查

如果本次改动触到了下列能力，建议补做：

- `GET /api/v1/workspaces/{workspace_id}/stats`
  - 用 internal ops token 读一遍，确认成员数 / 项目数 / active jobs 口径没漂
- Harness / WS attach
  - 验证 workspace 切换后 attach 上下文刷新正常
  - 验证 `projectUuid` / `scriptUuid` 主路径正常，legacy numeric 仅作兼容回退
- Notifications / product deep links
  - 验证 jobs / projects 通知点开后，产品壳能按 UUID-first scope 正确恢复 workspace / project 上下文
- Flutter workspace UI
  - 验证当前高亮、空状态、成员管理入口、invite 接受入口

## 5) 记录模板

```md
Date:
Environment:
Workspace:
Release / PR:

RLS validation:
- owner:
- member:
- outsider:
- verdict:

Current workspace / fallback:
- /me:
- forbidden switch:
- fallback case:

Sensitive operations:
- remove member:
- demote admin:
- last owner guard:

Invite:
- accept success:
- conflict / expired:
- notes:

Open follow-up:
```

## 6) 什么时候不能放行

出现以下任一情况，不应把 workspace 改动视为 ready：

- 存在新的 `Rust deny / RLS allow`
- `current_workspace` 失效后没有自动回退 personal
- 非成员切换没有返回 `403`
- 最后一个 owner 保护失效
- invite 状态机被绕过
- 运维排障只能靠手工 SQL 才能解释主路径行为

## 7) 当前定位

这张清单不是新产品需求，也不是新安全模型。  
它只是把当前已经存在的几份 workspace 文档按“真实发布 Gate”的顺序排好，方便 staging 演练、值班排障和发布收口。
