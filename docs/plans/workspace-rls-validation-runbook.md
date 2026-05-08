# Workspace RLS Validation Runbook（W9.2）

**目的**：把 [`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md) 里的“应当如何判读”变成一套可执行验证步骤，供本地 `supabase start` 或 staging 直接使用。  
关联：[`workspace-security-boundary.md`](./workspace-security-boundary.md)、[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W9、[`workspace-release-checklist.md`](./workspace-release-checklist.md)。

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

- `DATABASE_URL`（若主机已装 `psql`）
- 一个目标 `workspace_id`
- 三个测试用户：
  - `OWNER_USER_ID`
  - `MEMBER_USER_ID`
  - `OUTSIDER_USER_ID`
- 同三位用户对应的 Rust API Bearer token（若做 REST 对照）
- 一个**已迁移**的数据库：
  - staging 上的目标库，或
  - 已初始化 schema 的本地 `supabase start`

建议目标 workspace 具备这些样本：

- 至少 1 个 enterprise workspace
- 至少 1 个 owner + 1 个非 owner member
- 至少 1 个 `app_project`
- 至少 1 个 project 下的 script / asset / novel
- 至少 1 个带 `project_uuid` 或 `project_numeric_id` 的 generation job

## 3) RLS 直连探针

仓库已附带：

- 脚本：[`scripts/workspace_rls_probe.sh`](../../scripts/workspace_rls_probe.sh)
- 矩阵脚本：[`scripts/workspace_rls_probe_matrix.sh`](../../scripts/workspace_rls_probe_matrix.sh)
- 矩阵 + 摘要：[`scripts/workspace_rls_probe_and_summarize.sh`](../../scripts/workspace_rls_probe_and_summarize.sh)
- 样本种子：[`scripts/workspace_rls_seed_sample.sh`](../../scripts/workspace_rls_seed_sample.sh)
- 一键样本验证：[`scripts/workspace_rls_seed_and_probe_sample.sh`](../../scripts/workspace_rls_seed_and_probe_sample.sh)
- 汇总脚本：[`scripts/workspace_rls_summarize.sh`](../../scripts/workspace_rls_summarize.sh)
- 样本断言：[`scripts/workspace_rls_assert_sample.sh`](../../scripts/workspace_rls_assert_sample.sh)
- 摘要断言：[`scripts/workspace_rls_assert_summary.sh`](../../scripts/workspace_rls_assert_summary.sh)
- SQL：[`scripts/fixtures/workspace_rls_probe.sql`](../../scripts/fixtures/workspace_rls_probe.sql)

它做两件事：

1. 打印关键表的 RLS / policy 快照
2. 在模拟 `authenticated` + `auth.uid() = <probe user>` 的上下文里，输出目标 workspace 下的可见行数

脚本支持两种执行模式：

1. 主机已装 `psql`
   - 读取 `DATABASE_URL`
2. 主机没装 `psql`，但本地 Supabase DB 容器在跑
   - 自动 fallback 到 `docker exec ... psql`

如果目标数据库里连 `app_workspace` 都还不存在，脚本会直接失败并提示“先迁移 schema”，避免把空库误判成 RLS deny。

### 3.0 可选：先种一份本地最小样本

若本地库是空的，可先运行：

```bash
bash scripts/workspace_rls_seed_sample.sh
```

若只是想快速确认“本地当前 schema + 固定样本 + 三身份 probe”整条链路都通，也可直接运行：

```bash
bash scripts/workspace_rls_seed_and_probe_sample.sh
```

这条命令现在会自动产出：

- `owner.txt`
- `member.txt`
- `outsider.txt`
- `summary.md`
- `summary.json`

并继续断言固定 sample 的期望形状：

- `app_workspace` / `app_workspace_member`：owner=1, member=1, outsider=0
- `app_project` / `app_script` / `app_asset` / `app_novel` / `app_generation_job`：owner=1, member=0, outsider=0
- `app_agent_memory` / `app_art_style`：三者都为 0

它会插入固定 UUID 的三类用户：

- owner：`10000000-0000-0000-0000-000000000001`
- member：`10000000-0000-0000-0000-000000000002`
- outsider：`10000000-0000-0000-0000-000000000003`

以及一条 enterprise workspace：

- `20000000-0000-0000-0000-000000000010`

同时补一条 project / script / novel / asset / queued job，足够覆盖矩阵里的主要 mismatch 域。

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

### 3.3.1 一次性跑完整矩阵

若 owner/member/outsider 都已准备好，也可直接：

```bash
DATABASE_URL=... \
PROBE_WORKSPACE_ID="$WORKSPACE_ID" \
OWNER_USER_ID="$OWNER_USER_ID" \
MEMBER_USER_ID="$MEMBER_USER_ID" \
OUTSIDER_USER_ID="$OUTSIDER_USER_ID" \
bash scripts/workspace_rls_probe_matrix.sh
```

若想一步拿到原始输出 + Markdown/JSON 摘要，也可直接：

```bash
DATABASE_URL=... \
PROBE_WORKSPACE_ID="$WORKSPACE_ID" \
OWNER_USER_ID="$OWNER_USER_ID" \
MEMBER_USER_ID="$MEMBER_USER_ID" \
OUTSIDER_USER_ID="$OUTSIDER_USER_ID" \
bash scripts/workspace_rls_probe_and_summarize.sh
```

它会默认把结果落到 `.tmp/workspace-rls-<timestamp>/`，并对 `summary.md` 再跑一层摘要断言。

若想顺手保留原始输出，可再加：

```bash
OUTPUT_DIR=".tmp/workspace-rls-$(date +%Y%m%d-%H%M%S)" \
bash scripts/workspace_rls_probe_matrix.sh
```

会分别生成：

- `owner.txt`
- `member.txt`
- `outsider.txt`

若要把三份原始输出再整理成可贴工单的 Markdown，可继续运行：

```bash
INPUT_DIR=".tmp/workspace-rls-<date>" \
OUTPUT_FILE=".tmp/workspace-rls-<date>/summary.md" \
bash scripts/workspace_rls_summarize.sh
```

生成的摘要表会直接带一列 `Verdict`，把当前结果标成：

- `partial_match`
- `expected_mismatch`
- `match`
- `match_or_rls_widened`
- `review_needed`
- `security_bug`

并在表头上方再给出一条：

- `Overall Verdict: pass`
- `Overall Verdict: warning`
- `Overall Verdict: fail`

若要只对摘要做门槛断言，也可运行：

```bash
SUMMARY_FILE=".tmp/workspace-rls-<date>/summary.md" \
bash scripts/workspace_rls_assert_summary.sh
```

默认规则：

- 允许：`partial_match`、`expected_mismatch`、`match`
- 失败：`review_needed`、`security_bug`
- `match_or_rls_widened` 默认也失败；若本轮就是在验证 RLS 收口，可显式传 `ALLOW_MATCH_OR_RLS_WIDENED=1`

若想只对固定样本结果做门槛断言，也可运行：

```bash
INPUT_DIR=".tmp/workspace-rls-<date>" \
bash scripts/workspace_rls_assert_sample.sh
```

### 3.4 当前已验证的本地样本结论（2026-05-08）

基于 `scripts/workspace_rls_seed_sample.sh` 插入的固定样本，已在本地迁移完成库上跑过一轮 probe。  
当前观察结果可作为 staging 判读前的基线：

| 身份 | `app_workspace` | `app_workspace_member` | `app_project` / `app_script` / `app_asset` / `app_novel` / `app_generation_job` |
|------|------------------|------------------------|-----------------------------------------------------------------------------------|
| owner | 1 | 1 | 都可见 |
| member | 1 | 1 | 都不可见 |
| outsider | 0 | 0 | 都不可见 |

这说明当前本地样本下：

- workspace 基础表是 `partial_match`
- project / script / asset / novel / job 仍是典型 `Rust allow，RLS deny`
- staging 若出现更宽的 member 直连可见性，应先视为异常而不是默认“终于对了”

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

建议通过 `OUTPUT_DIR=".tmp/workspace-rls-<date>"` 让矩阵脚本自动落盘原始输出，再用 `workspace_rls_summarize.sh` 生成 Markdown 摘要；不要把环境数据直接提交进仓库。

## 7) 完成标准

W9.2 真正勾选完成，至少要满足：

1. 用这套 Runbook 在本地或 staging 跑过一轮 owner / member / outsider
2. 已确认哪些 mismatch 是预期 Rust-only
3. 若发现 Rust deny / RLS allow，必须先按安全 bug 处理
4. 将验证摘要回填到 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 或发布记录
5. 若准备进入 staging / 发布收口，再按 [`workspace-release-checklist.md`](./workspace-release-checklist.md) 串联敏感操作、invite 与 fallback 检查

## 8) 当前结论

这份 Runbook 只是把验证动作标准化，**不等于 W9.2 已完成**。  
W9.2 完成态仍需要至少一轮真实环境验证记录。
