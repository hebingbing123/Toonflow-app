# Workspace RLS Validation Runbook（W9.2）

**目的**：把 [`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md) 里的“应当如何判读”变成一套可执行验证步骤，供本地 `supabase start` 或 staging 直接使用。  
关联：[`workspace-security-boundary.md`](./workspace-security-boundary.md)、[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9。

## 1) 这份 Runbook 解决什么问题

W9.2 当前最大的缺口不是“不知道哪里 mismatch”，而是：

- 值班或开发同学临到 staging 才开始拼 SQL
- 容易把 Rust API 结果与 RLS 结果混在一起
- 没有统一格式记录 owner / member / outsider 三种身份的观察结果

这份 Runbook 把验证拆成三层：

1. **RLS policy snapshot**：数据库当前到底开了哪些 policy
2. **Supabase 直连可见性**：在 `authenticated + request.jwt.claim.sub` 语境下，用户能直接看到什么
3. **Rust API 对照**：同一身份走 REST 时能看到什么

## 2) 前置准备

至少准备以下信息：

- `DATABASE_URL`
- 一个目标 `workspace_id`
- 三个测试用户：
  - `OWNER_USER_ID`
  - `MEMBER_USER_ID`
  - `OUTSIDER_USER_ID`
- 同三位用户对应的 Rust API Bearer token（若做 REST 对照）

建议目标 workspace 具备这些样本：

- 至少 1 个 enterprise workspace
- 至少 1 个 owner + 1 个非 owner member
- 至少 1 个 `app_project`
- 至少 1 个 project 下的 script / asset / novel
- 至少 1 个带 `project_uuid` 或 `project_numeric_id` 的 generation job

## 3) RLS 直连探针

仓库已附带：

- 脚本：[`scripts/workspace_rls_probe.sh`](../../scripts/workspace_rls_probe.sh)
- SQL：[`scripts/fixtures/workspace_rls_probe.sql`](../../scripts/fixtures/workspace_rls_probe.sql)

它做两件事：

1. 打印关键表的 RLS / policy 快照
2. 在模拟 `authenticated` + `auth.uid() = <probe user>` 的上下文里，输出目标 workspace 下的可见行数

### 3.1 owner

```bash
DATABASE_URL=... \
PROBE_USER_ID="$OWNER_USER_ID" \
PROBE_WORKSPACE_ID="$WORKSPACE_ID" \
bash scripts/workspace_rls_probe.sh
```

### 3.2 member

```bash
DATABASE_URL=... \
PROBE_USER_ID="$MEMBER_USER_ID" \
PROBE_WORKSPACE_ID="$WORKSPACE_ID" \
bash scripts/workspace_rls_probe.sh
```

### 3.3 outsider

```bash
DATABASE_URL=... \
PROBE_USER_ID="$OUTSIDER_USER_ID" \
PROBE_WORKSPACE_ID="$WORKSPACE_ID" \
bash scripts/workspace_rls_probe.sh
```

## 4) Rust API 对照

至少核对下列接口：

- `GET /api/v1/me`
- `GET /api/v1/projects`
- 任选一个目标 project 的详情 / workbench 接口
- `GET /api/v1/jobs`

示例：

```bash
curl -sS \
  -H "Authorization: Bearer $OWNER_BEARER" \
  http://127.0.0.1:8666/api/v1/projects
```

```bash
curl -sS \
  -H "Authorization: Bearer $MEMBER_BEARER" \
  http://127.0.0.1:8666/api/v1/projects
```

```bash
curl -sS \
  -H "Authorization: Bearer $OUTSIDER_BEARER" \
  http://127.0.0.1:8666/api/v1/projects
```

## 5) 预期判读

按下表判：

| 现象 | 结论 |
|------|------|
| Rust allow，RLS deny | `expected mismatch`，前提是该域当前本来就声明为 Rust-only 协作 |
| Rust deny，RLS allow | `security bug` |
| Rust allow，RLS allow | `match` |
| Rust deny，RLS deny | `match` |

### 5.1 当前预期 mismatch

以下域在当前阶段出现 “Rust allow，RLS deny” 属于预期：

- `app_project`
- `app_script`
- `app_asset`
- `app_novel`
- `app_generation_job`

原因：这些域的 workspace 协作语义目前主要由 Rust API helper 承担，RLS 仍保留 owner-only 或 via owner 逻辑。

### 5.2 当前预期 match / partial match

- `app_workspace`：member 可见，预期大体 match
- `app_workspace_member`：通常只会看到“自己的 membership 行”，因此多为 `partial_match`
- `app_agent_memory` / `app_art_style`：本来就是 user-scope，预期 match

## 6) 记录模板

每轮验证至少记下下面这些信息：

```md
Date:
Environment:
Workspace:

Owner:
- Rust API:
- RLS probe:
- Verdict:

Member:
- Rust API:
- RLS probe:
- Verdict:

Outsider:
- Rust API:
- RLS probe:
- Verdict:

Unexpected allow paths:
Unexpected deny paths:
Follow-up:
```

建议把原始输出临时落在 `.tmp/workspace-rls-<date>/`，不要把环境数据直接提交进仓库。

## 7) 完成标准

W9.2 真正勾选完成，至少要满足：

1. 用这套 Runbook 在本地或 staging 跑过一轮 owner / member / outsider
2. 已确认哪些 mismatch 是预期 Rust-only
3. 若发现 Rust deny / RLS allow，必须先按安全 bug 处理
4. 将验证摘要回填到 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 或发布记录

## 8) 当前结论

这份 Runbook 只是把验证动作标准化，**不等于 W9.2 已完成**。  
W9.2 完成态仍需要至少一轮真实环境验证记录。
