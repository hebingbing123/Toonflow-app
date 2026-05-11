# Toonflow 平台执行进度

更新时间：2026-05-11

这个文件用于记录“平台实施落地计划（竖切执行版）”的实际落地进度。  
大路线图仍以 [`docs/plans/harness-rust-flutter.md`](./harness-rust-flutter.md) 为总蓝图；按工程方向拆分的跟踪表见 [`roadmap-index.md`](./roadmap-index.md)。可执行的竖切勾选清单：**[PG 队列观测](./tasks-pg-queue-observability.md)**、**[HTTP 收敛 B·其余域](./tasks-http-api-cleanup.md)**；团队 Workspace **完整功能**总表见 [**`workspace-team-full-plan.md`**](./workspace-team-full-plan.md)。**全栈约定**（禁止只合后端）：[**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)；**平台级补遗池**：[**`platform-capabilities-backlog.md`**](./platform-capabilities-backlog.md)。这里单独记录当前做到了哪一条、下一条是什么、还有哪些阻塞。

## 状态约定

- `completed`：已实现、已验证、已提交
- `in_progress`：当前正在实现
- `pending`：尚未开始
- `blocked`：有明确阻塞，需先清理依赖项

## 当前总览

- 当前阶段：`Phase 1 — 平台底座与最小主链`
- 当前执行策略：按“前后端一并落地”的竖切推进
- 当前验证策略：阶段内可跑定向验证；**一旦合并涉及 `backend/`、`frontend/`、OpenAPI、`docs/websocket-events.md`、workflow、迁移等（见仓库根 [`AGENTS.md`](../../AGENTS.md)），须在宣称可合并前跑通 `yarn refactor:check`**
- 当前最新完成竖切：团队 Workspace **W1.1–W1.7** — 创建/列表（含 **`include_archived`**）/详情/PATCH（改名、**归档/恢复**）、**active enterprise 配额**（env）、**current_workspace** 归档回落、Flutter **「团队工作区」**（含归档确认）、`pg_contract` + smoke；详见 [**`workspace-team-full-plan.md`**](./workspace-team-full-plan.md) Phase W1
- **下一大型竖切**（进行中）：**团队 Workspace 完整功能** — **Phase W2、W3 已收口**；**W4.1–W4.3 已落地**，**W4.4 进行中**（已抽 project workspace-membership helper 并接入 home/stats/style-config/overview/assets-overview/production-overview/short-video-assembly/short-video-export-check/short-video-readiness；资产域 `require_project_workspace_member_scope` 等与 `scope/mod.rs` script/storyboard/project 解析 helper 已切为 workspace 成员语义，小说 `project_id` CRUD + 小说事件 `project_id` 列表/删除/批删/生成查询已移除 owner 内联过滤，脚本导出/抽取轮询 `scripts/export-poll` 与小说抓取 schedule/observability 项目查询已切为 workspace 成员可见），见 [**`workspace-team-full-plan.md`**](./workspace-team-full-plan.md)
- **W4.5 已起步**：`app_generation_job` 先按 `project_id` 派生 workspace 可见范围，`GET /api/v1/jobs/page`、`GET /api/v1/jobs`、jobs 三个 summary 端点，以及 jobs 详情/取消/重试链路已统一到 owner 或同 workspace 项目成员可见（未传 `project_id` 的列表/汇总仍保留 owner 个人视图）；`POST /api/v1/jobs` 在 payload 带 project 字段时会做成员校验并规范化 `project_uuid`/`project_numeric_id`；本地 artifact 下载目录与更新通知已改按 `job.owner_user_id` 对齐；worker 侧 `video/voiceover/asset-image` 的项目写回查询已切到 workspace 成员校验；并完成书面定稿：`app_generation_job` 暂不新增 `workspace_id`，由规范化 `project_*` 派生 workspace 可见性
- **W4.6 已启动**：`GET /api/v1/usage/summary` 响应与 OpenAPI 已显式增加 `scope = user`，先固定用户聚合口径；memory / skills / quality 范围定义继续推进
- **W4.6 持续推进**：`GET /api/v1/skills/summary`、`GET /api/v1/agents/memory/cost-overview`、`GET /api/v1/quality/stats` 已显式返回 `scope=user`，与 usage 端点对齐为用户口径
- **W4.6 持续推进**：quality 其余聚合端点（`stage-pass-rate`、`stage-grade-distribution`、`scope-insights`、`token-efficiency`、`token-efficiency/samples`）已补 `scope=user`，`quality` 聚合口径统一为 user
- **W4.6 持续推进**：`POST /api/v1/agents/memory/query` 的 `MemoryHistoryItem` 已补 `scope=user`，memory 可见输出与 usage/skills/quality 口径对齐
- **最新补齐**：Workspace 计费口径 **W8.1** 已定稿 — 新增 [**`workspace-billing-scope-decision.md`**](./workspace-billing-scope-decision.md)，确认当前 `plan_tier` / `daily_job_quota` / `jobs_today` 维持 **user-scope**；workspace 继续解决协作与可见范围，不提前承担共享套餐/共享额度语义
- **最新补齐**：Workspace 权限/计费关系 **W5.4** 已收口 — `workspace-team-full-plan.md` 与 [`roadmap-workspace.md`](./roadmap-workspace.md) 已同步标明：当前 `plan_tier` 与 quota 仍按 **user-scope**，W8.2–W8.4 只在未来明确重开 workspace-scope billing 时再进入实现
- **最新补齐**：Workspace 默认项目权限策略 **W5.3** 已补档 — 新增 [**`workspace-project-permission-policy.md`**](./workspace-project-permission-policy.md)，把“member 可创建但不可删他人项目、admin/owner 可治理全部项目”的现行后端语义固定成书面真源，并明确 `W5.2` 仍是条件触发的可选增强
- **最新补齐**：Workspace observability 实现 **W10.1** 已落地 — `workspace_id` 已贯穿 `GET /api/v1/me` fallback / `PATCH /api/v1/me/current-workspace`、project workspace scope helper、job enqueue / `generation_job_phase`、Harness attach 链路；同时顺手修复当前分支上阻塞 `refactor:check` 的 Flutter analyzer 与两组前端测试用例
- **最新补齐**：Workspace observability 实现 **W10.2** 已落地 — 新增 internal-ops 只读端点 `GET /api/v1/workspaces/{workspace_id}/stats`，沿用 `TOONFLOW_INTERNAL_OPS_TOKEN` + `X-Toonflow-Internal-Token` 门禁，返回 `workspace_member_count` / `workspace_project_count` / `workspace_active_job_count`；其中 active jobs 仅统计 `queued` / `running` 且能由 job payload 解析到 project -> workspace 的任务；Flutter 团队工作区成员治理弹窗现已在 internal build 中直接展示这组三指标
- **最新补齐**：Workspace 运维 Runbook **W10.3** 已落地 — 新增 [**`workspace-operations-runbook.md`**](./workspace-operations-runbook.md)，覆盖 workspace / member / current_workspace / project 可见性排障、邀请 accept 冲突判读，以及只读核查 / 受控修复 SQL 模板；不引入新 REST / WS / schema，纯收口现有语义
- **最新补齐**：平台通知中心 **P-A1** 已落地 — 新增 `app_notification` 与 settings inbox API（`GET /api/v1/settings/notifications`、`POST /mark-read`、`POST /mark-all-read`），并通过 WS `settings.notification.created` / `settings.notification.updated` 把 skills 变更、jobs 终态、workspace invite 生命周期推到 Flutter 主导航「通知中心」pane；支持未读计数、列表筛选、已读回写与深链打开 jobs / team workspaces / projects
- **最新补齐**：账户导出 / 删号 **P-A3** 已落地 — 新增 `POST /api/v1/settings/account/export`、`GET /api/v1/settings/account/exports`、`GET /api/v1/settings/account/exports/{job_id}/file`、`POST /api/v1/settings/account/delete`；后端复用 `app_generation_job` 生成账户 zip 导出（profile / workspace / projects / scripts / storyboards / assets / novels / jobs / usage / memory / vendor credential metadata / notifications 等），并在 Flutter 主导航补齐「账户」pane、导出历史、下载到本机与强确认删号
- **最新补齐**：用户级 API Key **P-B1** 已落地并补齐平台级细节 — 新增 `app_api_key` / `app_api_key_audit`，以及 `GET /api/v1/settings/api-keys`、`GET /api/v1/settings/api-keys/audit`、`POST /api/v1/settings/api-keys`、`POST /api/v1/settings/api-keys/{id}/rotate|revoke|activate`、`DELETE /api/v1/settings/api-keys/{id}`；secret 仅创建/轮换时一次性回显、服务端以 HMAC 哈希保存，并将 `last_used_at/path/method/ip/user_agent` 与 `use_count` 回写；认证链已支持 `X-API-Key` 调用用户域 REST，`read_only` key 只允许 `GET/HEAD/OPTIONS`，限流按 key `public_id` 分桶；轮换已修正为沿用原 `public_id` 并支持 `expiresAtAction = preserve|clear|set`，列表新增 `isExpired` / `isUsable` 便于产品面直接判断；Flutter 主导航已补「API 密钥」pane，覆盖创建、一次性明文复制、过期策略、轮换、撤销/恢复、删除与审计查看
- **最新补齐（文档收口）**：管理台扩展 **P-C1** 的 project 治理语义已按代码真源更正 — 当前 `POST /api/v1/internal/admin/projects/{project_id}/governance` 仍是 **project 归档 / 解档 + `metadata.internalOps.opsNote`**，并写入 `app_project_governance_audit`；project owner 异常补救不再混入 governance 语义，而是走独立 internal-only `POST /api/v1/internal/admin/projects/{project_id}/owner-transfer`
- **最新补齐**：管理台扩展 **P-C1** 已继续补到 workspace 成员 remediation — 在既有 internal-only REST `GET /api/v1/internal/admin/search`、用户与 workspace / project 详情 GET、`POST /api/v1/internal/admin/users/{user_id}/governance`、`POST /api/v1/internal/admin/users/{user_id}/workspace-context`、`POST /api/v1/internal/admin/workspaces/{workspace_id}/governance`、`POST /api/v1/internal/admin/projects/{project_id}/governance` 之外，再新增 `POST /api/v1/internal/admin/workspaces/{workspace_id}/members/remediation`，继续统一复用 `TOONFLOW_INTERNAL_OPS_TOKEN` / `X-Toonflow-Internal-Token` 门禁；后端支持 internal ops 直接补成员、改角色、移除成员，移除时会自动把该用户 `current_workspace_id` 回退到 personal，并清理该 workspace 下失效的 `app_project_member` ACL 残留，同时把 remediation 轨迹写入 `app_workspace_governance_audit`；Flutter internal build 下的「管理台」pane 现已支持 workspace 成员修复按钮与审计查看
- **最新补齐**：管理台扩展 **P-C1** 已补齐 ownership remediation — 在既有 internal-only REST `GET /api/v1/internal/admin/search`、用户 / workspace / project 详情 GET、`POST /api/v1/internal/admin/users/{user_id}/governance`、`POST /api/v1/internal/admin/users/{user_id}/workspace-context`、`POST /api/v1/internal/admin/workspaces/{workspace_id}/governance`、`POST /api/v1/internal/admin/workspaces/{workspace_id}/members/remediation`、`POST /api/v1/internal/admin/projects/{project_id}/governance` 之外，再新增 `POST /api/v1/internal/admin/workspaces/{workspace_id}/owner-transfer` 与 `POST /api/v1/internal/admin/projects/{project_id}/owner-transfer`，继续统一复用 `TOONFLOW_INTERNAL_OPS_TOKEN` / `X-Toonflow-Internal-Token` 门禁；workspace owner 修复直接复用既有 owner transfer 语义：目标成员升为 owner、原 owner 自动降为 admin，并写入 `app_workspace_governance_audit`；project owner 修复要求目标用户已是所属 workspace 成员，若项目已启用 ACL 且旧 owner 仍为普通 member，会自动补 `editor` 访问保障协作连续性，并写入 `app_project_governance_audit`；Flutter internal build 下的「管理台」pane 已支持这两条 ownership 补救入口与审计摘要查看
- **最新补齐**：管理台扩展 **P-C1** 已补齐 ACL 读模型与批量治理视图 — workspace 详情现在直接返回 `workspaceRoleBreakdown` 与 `projectAclSummaries`，project 详情直接返回 `projectAclMode`、显式 ACL 计数、`aclMembers` 与 `workspaceMemberCandidates`，并新增 `POST /api/v1/internal/admin/projects/batch-governance` 供 internal ops 对同 workspace 下选中的多个 project 批量 archive / restore / 写内部备注；Flutter `AdminConsoleSection` 已补 ACL 摘要、批量选择与批量治理入口，同时这块 UI 现已正式挂到 `Ops and debug` 壳层，不再只是仓库里的孤儿代码
- **最新补齐**：内容与合规队列 **P-C2** 已补到改派与导出 — 新增 internal-only `POST /api/v1/internal/compliance/reports/reassign`，支持把 `pending|claimed` 开放举报批量改派给新的 reviewer，并把 `reassigned` 写入 audit；此前补上的 `claimedByLabel` / `slaBucket` 过滤现已真正接通到队列查询。Flutter `ContentComplianceSection` 现可对选中的开放项批量改派 reviewer，并把当前筛选结果一键复制成 CSV，运营 handoff 不再只能口头转单
- **最新补齐**：全局搜索 **P-A2** 已把入口视图治理补到完整闭环 — 搜索栏下拉里的 pinned/recent 视图现在支持直接 **重命名 / 固定或取消固定 / 删除**，并按 **当前 workspace / 其他 workspace** 打二级分组；入口层不再只是排序与回放，而是具备完整 saved view 轻量治理能力
- **下一条平台治理竖切候选**：继续把 **P-C2** 往 reviewer capacity policy / staged escalation 推进，或回到 **P-A2** 做服务端保存视图与跨端同步
- **最新补齐**：Workspace 路线图索引 **W11.2** 已落地 — 新增 [**`roadmap-workspace.md`**](./roadmap-workspace.md) 作为团队 Workspace 方向入口；`workspace-team-full-plan.md` 继续保留为 W1–W11 勾选真源
- **最新补齐**：Workspace 安全边界文档 **W9.1** 已落地 — 新增 [**`workspace-security-boundary.md`**](./workspace-security-boundary.md)，明确 Rust `DATABASE_URL` 直连 Postgres 时以应用层授权为真源、Supabase RLS 为直连客户端补充护栏，并列出 workspace / project / jobs / Harness 需显式复用的门禁 helper
- **最新补齐**：Workspace RLS 一致性矩阵 **W9.2** 已落地 — 新增 [**`workspace-rls-consistency-matrix.md`**](./workspace-rls-consistency-matrix.md)，明确当前 Rust workspace 协作语义与 Supabase 直连客户端 owner-only RLS 之间的主要 mismatch，避免误把 Rust 可见性等同于直连可见性；本轮先补矩阵，不声称 staging 一致性验证已完成
- **最新补齐**：Workspace RLS 验证包 **W9.2** 已补一层执行落地 — 新增 [**`workspace-rls-validation-runbook.md`**](./workspace-rls-validation-runbook.md) 与 `scripts/workspace_rls_probe.sh` / `scripts/fixtures/workspace_rls_probe.sql`，把 owner/member/outsider 三身份的 policy snapshot、RLS 直连可见性和 Rust API 对照步骤固定下来；仍未声称 staging 验证已完成
- **最新验证**：Workspace RLS 本地 seeded 样本已跑通 — 基于 `scripts/workspace_rls_seed_sample.sh` 的固定 workspace 数据，本地 probe 已确认 owner 能看见 project / script / asset / novel / job，member 只看见 workspace 基础表与自己的 membership，outsider 全 deny；与文档声明的 `partial_match` / `expected mismatch` 一致
- **最新补齐**：Workspace RLS 矩阵脚本已补齐 — 新增 `scripts/workspace_rls_probe_matrix.sh`，把 owner/member/outsider 三身份 probe 串成一次执行，减少 staging 演练时手工漏跑或贴错 `PROBE_USER_ID`
- **最新补齐**：Workspace 本地一键样本验证已补齐 — 新增 `scripts/workspace_rls_seed_and_probe_sample.sh`，把 seed sample 与三身份矩阵 probe 串成一条命令，方便本地空库快速确认 W9.2 验证链路可用
- **最新补齐**：Workspace RLS 原始输出落盘已补齐 — `scripts/workspace_rls_probe_matrix.sh` 现支持 `OUTPUT_DIR`，可把 owner/member/outsider 三份 probe 原始结果自动落到 `.tmp/workspace-rls-*`，便于 staging 验证归档
- **最新补齐**：Workspace RLS Markdown 汇总已补齐 — 新增 `scripts/workspace_rls_summarize.sh`，可把 `owner.txt` / `member.txt` / `outsider.txt` 自动整理成发布记录可复用的表格摘要
- **最新补齐**：Workspace RLS 摘要 verdict 列已补齐 — `workspace_rls_summarize.sh` 现会按当前 workspace 基础表 / 项目域 / user-scope 预期形状自动标出 `partial_match`、`expected_mismatch`、`match_or_rls_widened`、`review_needed` 等结论，减少 reviewer 手工判读
- **最新补齐**：Workspace RLS overall verdict 已补齐 — `summary.md` 现在会额外给出 `Overall Verdict: pass|warning|fail`，`workspace_rls_assert_summary.sh` 会优先按这条总结果做门禁判断
- **最新补齐**：Workspace RLS JSON 摘要已补齐 — `workspace_rls_summarize.sh` 现支持同时输出 `summary.json`，`workspace_rls_probe_and_summarize.sh` 会默认把 Markdown 与机器可读 JSON 一起落盘
- **最新补齐**：Workspace RLS assertion JSON 已补齐 — `workspace_rls_assert_summary.sh` 现支持输出 `assertion.json`，`workspace_rls_probe_and_summarize.sh` 默认会把 gate 结果也落盘，方便后续接 CI 或自动汇总
- **最新补齐**：Workspace RLS checklist 片段生成已补齐 — 新增 `scripts/workspace_rls_render_checklist_snippet.sh`，可把 `summary.json` 与 `assertion.json` 直接整理成发布清单 / 工单可贴的 Markdown 段落
- **最新补齐**：Workspace RLS wrapper 现已直接产出 checklist 片段 — `workspace_rls_probe_and_summarize.sh` 默认会连同 `summary.md` / `summary.json` / `assertion.json` 一起落出 `checklist-snippet.md`，把 staging 验证结果直接推到发布清单格式
- **最新补齐**：Workspace RLS artifact manifest 已补齐 — 新增 `scripts/workspace_rls_write_artifact_manifest.sh`，`workspace_rls_probe_and_summarize.sh` 现会同时产出 `artifact-manifest.json`，把 owner/member/outsider、workspace、环境标签与整组产物路径固定下来
- **最新补齐**：Workspace RLS 摘要断言已补齐 — 新增 `scripts/workspace_rls_assert_summary.sh`；`workspace_rls_probe_and_summarize.sh` 现在会对 `summary.md` 再跑一层 Gate，默认允许 `partial_match` / `expected_mismatch` / `match`，并把 `review_needed` / `security_bug` 直接视为失败
- **最新补齐**：Workspace RLS staging 包装脚本已补齐 — 新增 `scripts/workspace_rls_probe_and_summarize.sh`，可在 owner/member/outsider 参数已知时一步产出三份原始 probe 输出与 `summary.md`，减少 staging 演练时手工拼命令
- **最新补齐**：Workspace RLS 样本断言已补齐 — 新增 `scripts/workspace_rls_assert_sample.sh`，可对固定 local sample 的 owner/member/outsider 期望计数做直接断言；`workspace_rls_seed_and_probe_sample.sh` 也已串上这层 pass/fail 检查
- **最新补齐**：Workspace 发布检查单已补齐 — 新增 [**`workspace-release-checklist.md`**](./workspace-release-checklist.md)，把 W9.2 的 owner/member/outsider 验证、W9.3 敏感操作确认、W9.4 invite 边界核对，以及 W10.3 的 `current_workspace` fallback / `403` 排障点串成一套 staging / 发布前固定 Gate
- **最新补齐**：Workspace 项目级 ACL **W5.2** 已补齐全栈基线 — 新增 `app_project_member`，项目开始配置显式 ACL 后普通 member 会按 `viewer` / `editor` 收敛到读写权限；同时补了 `/api/v1/projects/{project_id}/members*` 管理端点、项目列表/摘要可见性过滤、publish 写接口的 editor 门禁、`ProjectRow.project_access_*` 有效权限回显，以及 `rust_api/project/members.dart`、Flutter 项目编辑器 `ProjectMembersPanel` 与项目列表限制态徽标
- **最新补齐**：平台体验补遗 **P-D3** 已进入 tracked 并落地主路径 — 复用现有 `quota_exceeded` / `Retry-After` / `retry_after_ms` 协议，在 [`frontend/lib/platform/rust_api_feedback.dart`](../../frontend/lib/platform/rust_api_feedback.dart) 增加共享解释与 Snackbar 层，并把 Projects / Jobs / Task Center / Team Workspaces / System Probes 等入口统一接到同一套 429 / 配额耗尽 UX
- **最新补齐**：平台公开状态页 **P-B3** 已进入 tracked 并可直接打开 — 新增 Flutter [`/status`](../../frontend/lib/status_page.dart) 页面，公开聚合 `/health`、`/api/v1/health`、`/api/v1/ready`、`/api/v1/version`，并在注入 `INTERNAL_OPS_TOKEN` 时附加 `GET /api/v1/jobs/queue/stats` 内部队列统计
- **最新补齐**：Billing webhook 审计产品面已补最小可用 UI — 复用既有 `GET /api/v1/webhooks/billing/events`，在 Flutter [`帮助 / 出站 Webhook`](../../frontend/lib/shell/build_sections_product.dart) 入口新增 provider / informational / `event_type` / raw/provider event id 及 prefix / `event_created_*` + `created_*` 时间窗筛选与分页列表，运营不再只靠 probe 或手工拼 query
- **最新补齐**：出站 Webhook 治理面已从“可用”收紧到“可运营” — Flutter [`帮助 / 出站 Webhook`](../../frontend/lib/shell/build_sections_product.dart) 现已补齐自定义 secret、可配置 test `eventType`、列表搜索、最近创建凭据回显、删除确认、最近测试结果、本地操作活动流，以及 billing webhook 审计摘要 / 查询摘要 / 当前查询 URL / 当前页与多页 CSV 导出 / 行级 drilldown，运营 handoff 不再只靠口述步骤
- **最新补齐**：质量评审产品面已从“字符串摘要”扩到“主界面运营看板” — Flutter [`质量评审`](../../frontend/lib/quality_reviews/section.dart) 现已补齐一键刷新质量看板、复制看板摘要，以及基于既有 quality 聚合接口的目标类型通过率、阶段等级分布、scope 榜单、坏例热点、token 效率主面展示；工作台继续承接深筛选与详情读写
- **最新补齐**：帮助 / 文档 Hub 已从“平铺链接”扩到“可检索知识入口” — Flutter [`帮助`](../../frontend/lib/shell/build_sections_product.dart) 现已补齐 title/id/url 搜索、分类摘要、空态提示，以及单链接 / 标题+链接复制，运营 handoff 不再只能逐条手找 URL
- **最新补齐**：质量主面板读模型已收口成单接口 — 后端新增 `GET /api/v1/quality/dashboard`，以主面板所需的 stats / stage / scope / bad case / token 五组轻量聚合一次返回；Flutter [`质量评审`](../../frontend/lib/quality_reviews/section.dart) 已改走该 dashboard 读模型，不再为主面板并发触发多路 quality 聚合请求
- **最新补齐**：质量主面板读模型已补齐持久化刷新链路 — 新增 Supabase migration `app_quality_dashboard_review_fact` 物化视图，后端 `POST /api/v1/quality/dashboard` 可显式 `REFRESH MATERIALIZED VIEW CONCURRENTLY` 并带 advisory lock 防并发刷新；Flutter [`质量评审`](../../frontend/lib/quality_reviews/section.dart) 已补“刷新底层读模型”入口与最近刷新状态，主面板不再只能直接扫原始质量表
- **最新补齐**：质量主面板读模型 freshness 已补成可观测能力 — 新增 `app_dashboard_refresh_state` 元数据表；`GET /api/v1/quality/dashboard` 现在直接返回 `refreshedAt` / `ageSeconds` / `stale` / `staleReason` / source max created_at / snapshot row count，Flutter 主面板会展示当前快照新鲜度，不再只能靠人工猜测是否需要 refresh
- **最新补齐**：质量主面板 refresh 已补“只在陈旧时执行”的受控模式 — `POST /api/v1/quality/dashboard?onlyIfStale=true` 现会在快照仍然 fresh 时返回 `skipped_fresh_snapshot` 而不是盲目重刷；Flutter 主面板刷新入口已默认走这条守护路径
- **最新补齐**：平台配置 / Feature Flags **P-A4** 已补成可回退的三层 override — `GET/POST /api/v1/settings/platform-config` 现在会返回 `effective` / `planTier` / `planOverride` / `workspaceOverride` / `userOverride` / `currentWorkspace` / `has*Override`，并按 `defaults <- plan override <- current workspace override <- user override` 合成；plan override 来自 `TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON`，支持 `plan_tier` 精确匹配、小写匹配、`default` 与 `*` fallback，`POST` 同时支持 `reset=true` 撤销 user / workspace 覆盖层回退到继承链，Flutter [`平台配置`](../../frontend/lib/shell/build_sections_product.dart) 已同步补齐三层状态展示与 user/workspace 保存重置，导航 / 质量看板 / jobs 等入口会跟随共享配置即时收敛；运维示例见 [`platform-config-plan-overrides.md`](./platform-config-plan-overrides.md)
- **最新补齐**：项目审计可见性 **P-C3** 已进入 tracked 并落地主治理面 — 新增 `app_project_audit` 与 `GET /api/v1/projects/{project_id}/audit`，当前记录项目创建 / 修改 / 删除，以及项目 ACL `viewer` / `editor` 增删改；Flutter 项目编辑器已补 [`ProjectAuditPanel`](../../frontend/lib/project_editor/project_audit_panel.dart)，可直接按动作过滤、搜索 actor/target/字段，并分页查看“谁改了我的项目”
- **最新补齐**：Workspace 审计可见性 **W2.7** 已从“仅写入”扩到“可读活动记录” — 新增 `GET /api/v1/workspaces/{workspace_id}/audit` 分页读模型，并把 Flutter 团队工作区成员管理弹窗扩成包含活动记录的治理面，owner/admin 可直接查看成员 / 邀请关键动作时间线
- **最新补齐**：Workspace owner transfer **W2.10 / W9.3** 已落地 — 新增 `POST /api/v1/workspaces/{workspace_id}/owner-transfer`，仅允许当前 primary owner 发起，目标用户必须已是 member，提交后 `app_workspace.owner_user_id` 切换到目标成员且原 owner 自动降为 `admin`；Flutter 成员管理弹窗已补确认式“转让 owner”入口，审计新增 `workspace_owner_transferred`
- **最新补齐**：Workspace 安全操作文档 **W9.3/W9.4** 已落地 — 新增 [**`workspace-sensitive-operations-runbook.md`**](./workspace-sensitive-operations-runbook.md) 与 [**`workspace-invite-security-review.md`**](./workspace-invite-security-review.md)，分别固定成员移除/降级/归档等敏感操作的确认流程，以及当前 invite token 的真实安全边界、风险等级与后续加强项
- **最新补齐**：Workspace 发布文档 **W11.3–W11.4** 已落地 — 新增 [**`workspace-migration-notice.md`**](./workspace-migration-notice.md) 说明客户端/迁移侧行为差异，并把 `yarn refactor:check` 的必跑门禁正式锚定到仓库根 `AGENTS.md` 与 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)
- **最新补齐**：Workspace observability spec **W10.1/W10.2** 已落地 — 新增 [**`workspace-observability-spec.md`**](./workspace-observability-spec.md)，明确 `workspace_id` 在 HTTP / jobs / Harness 的统一日志字段与 trace join 约定，并锁定 workspace 成员数 / 项目数 / 活跃 jobs 的管理指标口径；本轮只补规格，不声称实现已完成

## 执行中：PG 队列观测（[`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md)）

- **Q1–Q3**（ops-only，平台级可观测 + Runbook）：**已完成** — 扩展 `QueueStats` / `job_queue_metrics` 日志字段；[**`jobs-pg-queue-runbook.md`**](./jobs-pg-queue-runbook.md)（扩容、SQL、Gate、与 trace 关联）；代码 `backend/src/jobs/queue/pg.rs`、`worker/mod.rs`。
- **Q4**：**Backend + Runbook** 已落地 — **`observe::generation_job`** 结构化 **`event = generation_job_phase`**（**`job_id`** / **`kind`** / **`worker_id`** 等）；**`X-Request-Id` → `payload.client_request_id`** 已由 **`POST /api/v1/jobs`** 与主要 HTTP 入队路径自动写入；与 harness span / Flutter 可见 trace 的 **WP-F 尾部**仍 open（见 **`tasks-pg-queue-observability.md`**）。

- **HTTP 收敛 H0**：[**`http-api-cleanup-h0-inventory.md`**](./http-api-cleanup-h0-inventory.md) 已落盘（`rg` 基线 + parity 读法）。**H1**（`agent_memory` / `clear-agent-memories`：**`projectUuid`** 优先 + legacy **`projectId`**）已合。**H2**（`asset_extract`）已合。**H3**（**`assets-generate`** 入队 payload **v2**）已合 — [**`assets-generate-job-payload-v2.md`**](./assets-generate-job-payload-v2.md)。**H4**（Harness WS **`projectUuid`** / **`scriptUuid`** + legacy **`project_id`** / **`script_id`**；矩阵 [**`harness-ws-context-matrix.md`**](./harness-ws-context-matrix.md)；Flutter `agent_workspaces` 双写）已合。**H5·C0–C3**：C0–C2 见 **`tasks-http-api-cleanup.md`** H5；**C3**：`cargo clippy --all-targets --all-features -D warnings` 清洁批次（**`b306fe98`**）。**H5·D kickoff** 已完成首轮盘点：`production`/`task_center`/`agent_workspaces` 与 jobs payload、`import_staging` / `promote_import_snapshots()`、`pg_contract_tests` 仍大量依赖整型兼容语义，因此继续保留为 **独立 schema 窗口**，暂不与普通功能 PR 混做。其后续前端首刀已落在 **task center**：失败任务 deep-link 与产品壳跳转现已透传 `project_uuid` / `workspace_id`，为后续移除“仅靠 numeric 项目号恢复上下文”的链路先清一段路；随后 **agent workspaces** 也开始在项目切换时主动清空未显式提供的旧 `scriptId/scriptUuid`，避免旧 numeric/script scope 残留到新的 Harness attach；`short video space` 选项目时同步到产品壳的也不再只是 `projectNumericId`，而是 `ShortVideoProjectScope(projectNumericId, projectUuid, workspaceId)`；此前 `WorkspaceWritebackController.writeBackScriptWorkspaceResult()` 已改为优先使用 `projectUuidController`，`writeBackScriptPlanWorkspaceResult()` / `writeBackProductionFlowResult()` 也能在缺少 numeric `projectId` 时先从 `projectUuidController` 解析 `project.numericId`；最近又把 `system_probes/models_catalog` 的 production probe、script-agent probe，以及 `assets-generate` 的 generate/polish/batch probe 全部接上当前 project scope，不再默认写死 `projectId: 1`；这轮继续把 probe 的假资源号往后推了一层，新增 `projectUuid + scriptId -> asset/storyboard numeric id` 解析 helper，让 production probe、storyboard polling/export、typed production probe、`assets-generate` probe 与 `script-agent/update-data` 优先复用当前 workspace/project/script 上下文，而不是继续固定 `1`；顺手把 `account` probe 里的 `clear-agent-memories` 也收口到当前 workspace 输入，避免它再默认抓“第一个项目”或裸回退 `1`；再往前补一格后，`settings` probe 里的 `agent-deploy/deploy-model` 也改为先读 `agent-deploy/list` 解析真实 deploy id，不再固定 `id: 1`；最新五刀则把小说 workbench / events compat wrapper 改成 `projectUuid` 优先，项目编辑器已有 UUID 的调用面不再多绕一次 `projectIdForNumericId()`，并把 `delete-novel` / `update-novel` compat 调用也收口到可直传 `projectUuid`，避免继续扫描全项目列表；`project/compat.dart` 里的 `compat updateProject`、`edit-project` 与 `delete-project` 也开始接受调用方直传 `projectUuid`，让 project editor general/project probes 的更新与删除路径复用现成 UUID，而不是每次再扫一遍项目列表；紧接着又把 `scripts/extract-assets` 这一组 caller 收口到纯 UUID-first，project editor / script editor / probe / workbench 在已有 `projectUuid` 时不再继续双传 `projectNumericId`，并补了请求体 helper 测试来锁住 “UUID 优先、numeric 仅 legacy fallback” 语义。

## Phase 1 进度

### 1. Workspace 基础竖切

状态：`completed`

已完成：

- personal workspace 自动创建
- `workspace/project` 基础作用域落库
- `GET /api/v1/me` 返回当前 workspace
- 项目创建/读取带 `workspace_id`
- 前端显示 workspace / project 上下文栏

已提交：

- `9335f826` — personal workspace foundation + current workspace/project context

已验证：

- `cargo test me_ok_without_pool_with_jwt`
- `flutter test test/workspace_context_view_test.dart`
- 触达文件 `flutter analyze` 通过

备注：

- `yarn refactor:check` 已执行
- backend 通过
- frontend 全量仍被仓库既有 `short_video_space/*` analyzer 告警卡住，不是该竖切新增问题

### 2. 项目立项 + 项目首页竖切

状态：`completed`

已完成：

- `app_project.project_brief` / `app_project.brand_bible` 落库
- `GET /api/v1/projects/{project_id}/home` 项目首页读模型
- `readiness score` / onboarding / `style_bible_ready` 基础版
- 项目创建弹窗补 `project_brief` / `brand_bible`
- 现有项目详情入口补“项目首页驾驶舱”卡片与保存回写
- 顺带修复 `ProjectRow` 查询列不完整导致的潜在运行时映射错误

已提交：

- `b6e26d63` — complete project-home slice on existing project detail surfaces

已验证：

- `cargo test brief_ready_requires_three_meaningful_fields --lib`
- `cargo test parse_json_object_patch --lib`
- `flutter test test/projects_section_test.dart`
- 触达文件 `flutter analyze` 通过

备注：

- `yarn refactor:check` 已执行
- OpenAPI drift / rust_api consistency 通过
- 当前卡在工作区既有脏改动触发的 `cargo fmt --check` 差异：
  - `backend/src/publish/nine_platform_acceptance_tests/mod.rs`
  - `backend/src/publish/nine_platform_acceptance_tests/tests/metrics.rs`
  - `backend/src/publish/nine_platform_acceptance_tests/tests/registry.rs`
- 这些差异不属于本竖切新增代码

### 3. 内容接入竖切（主路径）

状态：`completed`

专项计划：

- [novel-intake-crawler-plan.md](./novel-intake-crawler-plan.md)

当前增量（含小说爬虫四阶段收口）：

- 章节工作台新增“整本导入”入口
- 前端支持整本正文本地预解析（按章节标题自动切章）
- 支持预解析预览与按批次写入既有章节 API
- 前端支持 `crawler_client` 首版：按 URL 抓网页、抽标题与正文、回填到整本导入区
- 为后续 `manual` / `whole-book import` / `crawler_client` 共用落库契约做统一入口
- 后端 `novels` create/get/list/patch 契约补齐 `intake_source` / `intake_source_url` / `intake_status` / `intake_note`
- 前端手动录入、整本导入、`crawler_client` 三条入口统一写入 intake source/status
- 章节编辑区支持查看和更新准入状态、来源 URL、准入备注
- 工作台摘要增加 admitted/pending/rejected/crawler 统计
- 列表接口支持按 `intake_status` / `intake_source` 过滤
- 工作台搜索区支持准入状态 / 来源筛选与一键清空筛选
- 工作台支持批量更新章节准入状态与准入备注，便于处理 pending/rejected 队列
- 整本导入预解析结果支持逐条修正：改标题、改正文、删除误切章节、补充漏切章节
- 导入前会自动重排章节序号，并拦截空正文章节，避免错误批量入库
- 整本导入支持显式指定导入后的 `intake_status` 与共享 `intake_note`，方便先入 `pending_review` 再批量准入
- 新增 server 侧小说爬虫：
  - `POST /api/v1/projects/{project_id}/novels/crawl-preview`（托管预览，单本自适应 TOC/分页/单页）
  - `POST /api/v1/projects/{project_id}/novels/crawl-import`（托管导入，server 端抓取+切章+质量门+落库）
  - `POST /api/v1/projects/{project_id}/novels/crawl-import-batch`（批量托管导入，多 URL 结果+汇总）
- novels 工作台支持“抓取执行端”切换：以 `client` 为主，`server` 用于托管预览 + 托管导入（增值）
- novels 工作台新增：
  - “托管导入（增值）”单 URL 按钮（尊重原有前端预解析+编辑主路径）
  - “批量托管导入（增值）”多 URL 按钮
  - “托管抓取计划”创建（延迟+重复间隔）与“查看托管计划”入口
  - “刷新托管统计”入口：展示按 intake source/status 的章节分布、最近 server 导入样本、托管 crawl jobs 状态
- server 托管导入写回 `intake_note` 时附带抓取审计摘要（模式/页数/候选章节链接数/正文字数）
- novel crawl 质量门后移到后端共享实现：整体字数、章节均值、重复率等不达标会被拦截
- 托管调度基于现有 `app_generation_job`：
  - worker 仅在 `run_at_ms` 到点时 claim 对应 `novel.crawl.import_batch` 任务
  - 支持 `repeat_interval_ms` 自动续约下一次抓取计划
  - 调度任务可在任务中心统一观察、取消、重试
- 新增 `GET /api/v1/projects/{project_id}/novels/crawl-observability`：
  - 返回本项目章节总数、按 `intake_source`/`intake_status` 聚合计数
  - 最近 `crawler_server` 导入样本（含 `intake_note` 审计）
  - 本项目 `novel.crawl.import_batch` jobs 的状态分布

本轮定向验证：

- `flutter test test/novel_import_parser_test.dart`
- `cargo test narrative::novels --lib`
- `flutter test test/novel_workbench_support_test.dart`
- `yarn refactor:check`（含 OpenAPI drift / Rust clippy / Flutter analyze & test）已全绿

已提交（按时间序约略）：

- `76232801` — add whole-book intake preview + batch import on top of the existing chapter API
- `c986cabf` — add crawler extraction regression coverage on the shared import path
- `7a7bb497` — preserve explicit nulls in intake PATCH bodies for admission editing
- `91170746` — unify intake source/admission metadata on the shared novel rail
- `2cb8fd5e` — add intake filtering and batch admission actions on the shared workbench
- `2aa14b75` — add editable import correction plus explicit import admission targeting
- `ffb8c272` — add hosted batch novel crawl import（托管批量导入 API + 前端入口）
- `bed5a42c` — add scheduled hosted novel crawl jobs（基于 jobs/worker 的定时与重复托管抓取）
- `18c1d524` — add crawl observability endpoints（来源/状态/job 级统计与前端展示）
- `c9557011` — harden scheduled novel crawl jobs（run_at_ms 防御、schedule 幂等键与稳定 error_code）

### 4. 改写与上游结构竖切

状态：`in_progress`

当前增量：

- 项目剧本区新增“骨架工作台”入口
- 前端可读取并编辑 `storySkeleton` / `adaptationStrategy`
- 前端兼容 `script-agent/get-plan-data` 当前两种返回结构，避免首次读取和已有计划读取形状不一致
- 保存走既有 `script-agent/set-plan-data` 契约，项目内可直接维护上游结构页
- 骨架工作台联动当前小说章节 / 事件数据，展示事件覆盖摘要
- 可用现有事件和章节生成“故事骨架草稿 / 改编策略草稿”，先用确定性模板压缩后续 AI 改写输入
- 可用现有事件 / 章节 / 骨架 / 策略生成“剧本初稿包”，先走确定性模板减少无效 token 消耗
- 骨架工作台新增剧本初稿预览与一键写入，复用既有 `script-agent/set-plan-data` 将同名剧本覆盖更新、缺失剧本自动创建
- script workspace 默认先消费 `planData.script` 里的计划剧本草稿，再按需补事件或章节窗口，避免上来整包回读小说正文
- 骨架工作台新增“结构化改写 guidance”生成与预览，把章节压缩、事件改写、人物情绪推进与去 AI 味约束整理成可执行 guidance，供后续 script 子代理或人工改稿消费
- script workspace 的“上下文快照 / 结果摘要”现在会把 `get_planData` 派生为“改写约束”卡，明确下游先消费计划剧本草稿、再补最少事件与章节正文，避免 guidance 只停留在计划侧
- production workspace 在读取 `scriptPlan` 时，会额外展示“改写约束下沉”卡，并在 flow 摘要中标记“已承接改写约束”，让导演计划、后续分镜与素材核对明确继承上游改写意图
- production workspace 在读取 `scriptPlan` 后，recipe 会新增“继续导演计划”动作，并自动继承 scriptPlan 已点名的关键资产范围，让后续导演计划、分镜和素材动作优先围绕改写约束收束，而不是重新扩读整包上下文
- production workspace 的资产补图与分镜补帧 prompt 现在会继承 scriptPlan 提炼出的短版执行提示，把情绪递进、画面意图和去生硬约束压缩进动作提示，在不扩读大上下文的前提下提升画面与表演自然度
- production workspace 的阶段卡与建议卡现在会直接展示本次子代理将使用的执行提示，用户无需先点应用再检查，即可判断本轮动作是否仍遵守改写约束、情绪递进和最小上下文读取策略

本轮定向验证：

- `flutter test test/script_agent_plan_data_test.dart test/project_script_plan_workbench_view_test.dart test/project_script_plan_workbench_support_test.dart`
- `flutter test test/script_workspace_support_test.dart`
- `flutter test test/project_script_plan_workbench_support_test.dart test/project_script_plan_workbench_view_test.dart test/script_agent_plan_data_test.dart`
- `flutter test test/script_workspace_support_test.dart`
- `flutter test test/agent_workspaces_section_test.dart --plain-name "Script pane renders planData and tool context snapshots"`
- `flutter test test/production_context_snapshot_test.dart test/production_workspace_support_test.dart`
- 触达文件 `flutter analyze` 通过

已提交：

- `e863fe13` — add project-level plan workbench for story skeleton and adaptation strategy
- `77b545b7` — seed skeleton and strategy drafts from current novel events before spending model tokens
- `0070f3ef` — bridge deterministic script draft packets into preview and writeback on top of the existing script-agent plan rail
- `79272d92` — teach script workspaces to prefer planData draft packets before wider chapter reads
- `72166473` — add structured rewrite guidance generation and preview on top of the plan workbench
- `c0e6acb2` — surface plan-derived rewrite constraints inside the script workspace snapshot and result summary
- `ec304994` — surface rewrite-constraint landing inside production scriptPlan snapshots and summaries
- `c90ce32a` — prioritize rewrite-constrained director-plan follow-ups in production recipes
- `5e5f6ea2` — distill scriptPlan rewrite intent into production asset/storyboard execution hints
- `4b253161` — surface production execution prompts inline on stage and recipe cards

### 5. 资产与生产竖切

状态：`in_progress`

当前增量：

- production workspace 的 flow 摘要与阶段文案现在会显式给出 readiness / gap 信息，而不只显示“是否有数据”
- assets flow 会显示主资产已就绪数、主资产待补数、衍生缺口数，便于判断当前是否真能推进出图
- storyboard flow 会显示画面结果已就绪数、待补帧数、纯文本镜头数，避免误把纯文本镜头当成缺帧
- storyboardTable flow 会显示已读取行数 / 总行数 / 待展开行数，便于决定是否继续抽样还是进入修订
- 这些 readiness / gap 摘要同时下沉到 production stage detail 与结果摘要中，帮助用户在最少点击下判断当前阻塞点
- production stage board 顶部会额外给出“当前卡点”总览，直接指出主链里第一个未解决的阶段，避免用户在平台视角下逐卡寻找阻塞点
- production stage 现在会显式给出主链阻断态：没有 `scriptPlan` 时，assets / storyboardTable / storyboard 会显示“等待导演计划”；有 `scriptPlan` 但还没有 `storyboardTable` 时，storyboard 会显示“等待分镜表”，避免下游阶段错误暗示可以直接出图
- production stage 现在进一步区分“有导演计划”与“导演计划是否够完整”：薄的 `scriptPlan` 会显示“待完善”，下游阶段会显示“等待导演计划完善”，要求至少补到基础规划维度后再放行，避免为了省 token 过早进入素材和分镜链导致质量变差
- production stage 现在进一步区分“已有 storyboardTable”与“storyboardTable 是否足够完整可推进”：仅抽样或覆盖不足的分镜表会让 storyboard 显示“等待分镜表完善”，要求先扩读或补齐关键镜头表，再推进出图
- production stage 的 storyboardTable 卡片现在也同步表达推进语义：覆盖不足时显示“待扩读”，覆盖已够时才保留“已抽样”，减少用户在阶段卡之间来回推断
- production stage 现在继续区分“分镜表覆盖不足”背后的原因：如果 `scriptPlan` 虽然过了基础完整度，但还缺少足够明确的分场景情绪/画面意图，则 storyboardTable 与 storyboard 会优先显示“回补导演计划”，而不是盲目继续扩读分镜表
- production recipe 现在与 stage gate 保持一致：当 `scriptPlan` 已够完整但仍缺少分场景意图时，scriptPlan 侧不再继续推荐“先看分镜表落地”，而是直接推荐“补足分场景意图”，把最省点击的下一步前置出来
- production 顶部 blocker headline 现在也会直接解释卡点原因：对 `待扩读` 与 `回补导演计划` 这两类状态输出定制短句，不再只是裁剪卡片详情，用户在最上层就能知道应该扩读分镜表还是先细化导演计划
- production stage / recipe 卡片的动作按钮文案现在也跟随 reason code 变化：例如 `待扩读` 会显示“扩读分镜表”，`回补导演计划` 会显示“细化导演计划”，减少用户把泛化按钮文案再翻译一遍的成本
- production 的“下一步建议”面板现在也会在卡片列表上方给一句总述：当首要建议是扩读分镜表或先细化导演计划时，用户无需逐卡扫描标题，就能先知道当前系统推荐的最低成本路径
- production 在“应用建议 / 应用阶段”后的状态反馈现在也会同步解释下一步：例如应用 `补足分场景意图` 后会明确提示“下一步先细化导演计划”，应用 `待扩读` 阶段动作后会提示“下一步先扩读关键分镜表窗口”，避免确认提示仍然停留在泛化标题回显
- production 对“建议刷新”类 stage 动作的按钮文案现在也按范围细化：会区分“刷新导演计划 / 回读受影响资产 / 回读局部分镜表 / 回读缺帧状态”，减少用户在局部回读场景里还要自己判断读取范围
- production 的 refresh-stage detail 文案现在也跟按钮词保持一致：例如会明确写“刷新分镜结果”“回读局部分镜表行”“回读本次镜头的缺帧状态”，减少按钮和正文之间的语义偏差

本轮定向验证：

- `flutter test test/production_workspace_support_test.dart`
- 触达文件 `flutter analyze` 通过

已提交：

- `9b675231` — turn production flow snapshots into explicit readiness and gap summaries
- `08c608ef` — surface the first unresolved production blocker above the stage board
- `f1947716` — enforce blocker states between scriptPlan, storyboardTable, and storyboard
- `f1b3154b` — require a minimally complete scriptPlan before downstream stages can advance
- `00637900` — require storyboardTable coverage to be sufficiently complete before storyboard can advance
- `cc5c9abc` — surface storyboardTable sampled-vs-advance-ready states directly on the stage card
- `f52fb74f` — split storyboardTable under-coverage into expand-table vs refine-scriptPlan paths
- `0fe27522` — align scriptPlan recipes with storyboardTable fallback routing
- `e9bb4938` — teach blocker headline to explain storyboardTable expand vs refine-plan reasons
- `4d4e926a` — align stage/recipe action button copy with storyboardTable fallback reasons
- `0bf2ab20` — add a diagnosis headline above recipes for the current cheapest production path
- `f983ccd4` — align applied feedback copy with storyboardTable fallback reasons
- `fc55433e` — specialize refresh-stage button labels by scope
- `c61c7f2f` — align refresh-stage detail copy with scoped refresh verbs

### 6. 质量与发布最小闭环竖切

状态：`completed`

已完成：

- 项目编辑器对话框新增“发布”入口：可直接跳转到「短剧空间 → 发布」工作台，并自动同步项目上下文
- 轻量发布总览读取（`GET …/publish/overview`）可在项目对话框内快速确认 drafts/jobs 是否存在

本轮定向验证：

- `yarn refactor:check` 全绿（backend fmt/clippy/test + frontend analyze/test + OpenAPI drift）

## 下一阶段：团队 Workspace 完整功能（`in_progress`）

**目标**：个人与团队 **双路径长期并存**；团队侧交付 **enterprise 全生命周期、邀请与成员、权限矩阵、全站资源与 Harness/计费/安全/观测** — 不以 MVP 为范围，以 [**`workspace-team-full-plan.md`**](./workspace-team-full-plan.md) **Phase W1–W11** 勾选为完成定义。

**进度**：**Phase W1–W7 已在总表收口**；其中 **W6 Flutter 产品面** 已完成 workspace 选择/切换、企业空间创建、成员与邀请管理、接受邀请深链、空状态引导、`rust_api` 一致性，以及 W6.7 的 a11y / 文案收口；**W11.1** 已同步更新阶段状态与里程碑 commit；**W8–W11** 其余条目仍以计费口径、安全与观测收口为主。在 `workspace-team-full-plan.md` 与各 Phase 内勾选；本文件仅记录 **当前主攻 Phase** 与 **里程碑 commit**。

| 跟踪项 | 状态 |
|--------|------|
| 总表 `workspace-team-full-plan.md` | Phase **W1–W7** `completed`；**W8–W11** `pending` |
| Phase W1–W4 核心 API + 项目范围 | `completed` |
| Phase W5–W7 权限 / Flutter / Harness | `completed` |
| Phase W8 计费口径与迁移策略 | `pending` |
| Phase W9–W11 安全 / 观测 / 发布文档 | `pending` |

近期里程碑 commit：

- `6a06d0e9` — 首页邀请 deep link 自动跳转回归测试 + 短视频草稿管理 analyze 收口
- `a9c1e1af` — 配音参数对话框抽成可测组件并补齐交互测试
- `40280055` — 团队 workspace 邀请管理弹窗（筛选 / 分页 / 批量复制）
- `e0848031` — 接受邀请深链与命中后自动跳转“团队工作区”
- `6e08da49` — 团队 workspace / 项目区空状态引导
- `0ea77e62` — `rust_api` / OpenAPI 一致性收口（metrics / ErrorBody / prompting quality paths）
- `623c42ce` — W6.7 a11y / 文案收口（统一字符串入口、workspace 语义标签、关键 tooltip）

## 当前阻塞与注意事项

### 当前门禁状态

- `yarn refactor:check` 当前已恢复全绿（OpenAPI drift、`rust_api` 一致性、backend `fmt/clippy/test`、frontend `analyze/test`）。
- 团队 workspace 竖切相关的 W6 / W7 / W11.1 文档与前端回归测试已和当前实现重新对齐。

### 合约测试环境注意

- 需要 `DATABASE_URL`
- 需要 `SUPABASE_JWT_SECRET`

没有这两个环境变量时，需 PG 的 `#[ignore]` 合约测试无法本地完整验证。

## 更新规则

后续每完成一个“可提交竖切增量”，这里都要同步更新：

1. 当前阶段
2. 当前竖切状态
3. 已完成内容
4. 定向验证结果
5. 对应 commit
6. 下一条要做的竖切
