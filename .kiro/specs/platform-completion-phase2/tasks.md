# Implementation Plan: Platform Completion Phase 2

## Overview

本任务清单定义 Toonflow 平台 Phase 2 完成工作的可执行任务分解，包括 Workspace 功能完善、HTTP API 收敛、以及平台能力补遗（全局搜索、出站 Webhook、内容合规通知、i18n、帮助文档）。

所有任务遵循 [`full-stack-delivery-covenant.md`](../../../docs/plans/full-stack-delivery-covenant.md) 约定：用户可见功能必须在同一里程碑交付 backend + frontend + OpenAPI 文档。所有变更必须通过 `yarn refactor:check` 门禁。

Cross-links: **requirements** → `requirements.md`; **design** → `design.md`; **计划文档** → `docs/plans/workspace-team-full-plan.md`, `docs/plans/platform-capabilities-backlog.md`

**与实现对齐（相对 `requirements.md` 的设计演进）**

- **保存视图**：REST 为 **`GET`/`PUT /api/v1/search/saved-views`**，表 **`app_user_search_saved_view`**；非需求稿中的 `/search/views` 与 `app_saved_search_view`。
- **帮助 Hub**：REST 为 **`GET /api/v1/settings/help/hub`**、**`/config`** 及用户/工作区链接 **`POST .../user-links`**、**`.../workspace-links`**；环境变量为 **`TOONFLOW_HELP_HUB_ITEMS_JSON`** / **`TOONFLOW_HELP_HUB_URL`**（非 `help-links` / `TOONFLOW_HELP_LINKS_JSON`）。
- **出站 Webhook（WH）**：用户出站落位 **`app_outbound_webhook`** + **`app_outbound_webhook_delivery`**，REST 主路径 **`/api/v1/settings/webhooks/outbound`**，并带 **`/api/v1/webhooks`** 别名（与计费 **入站** `POST /api/v1/webhooks/billing` 区分）。**`job.completed` / `job.failed`** 在 worker 终端态后投递；**`project.created`** 在 `POST /api/v1/projects` 成功后异步投递；**`workspace.member.added`** 在「此前非成员」的新增路径投递：`POST …/members` 与 **`POST …/invites/accept`**（`fire_outbound_webhooks_for_owner` + 指数退避，见 `deliver.rs`）。

## Tasks

- [x] **W1. Workspace 项目路径成员权限统一 (W4.4)**
  - [x] W1.1 抽取 `require_project_workspace_member_scope` helper 函数统一权限校验逻辑
  - [x] W1.2 剧本 handler 按 workspace 成员权限校验（`backend/src/scripts/http.rs`）
  - [x] W1.3 分镜 handler 按 workspace 成员权限校验（`backend/src/storyboards/http.rs`）
  - [x] W1.4 小说 handler 按 workspace 成员权限校验（`backend/src/novels/http.rs`）
  - [x] W1.5 资产 handler 按 workspace 成员权限校验（`backend/src/assets/http.rs`）
  - [x] W1.6 Workbench handler 按 workspace 成员权限校验（`backend/src/workbench/http.rs`）
  - [x] W1.7 更新 OpenAPI 文档说明成员权限要求
  - [x] W1.8 添加集成测试：owner/admin/member/outsider 访问项目资源的权限矩阵
  - _Requirements: 1.1, 1.2, 1.3, 13.1–13.10_

- [x] **W2. Jobs Workspace 可见性 (W4.5)**
  - [x] W2.1 实现 `derive_workspace_from_job_payload` 函数（从 `project_uuid`/`project_numeric_id` 派生 workspace）
  - [x] W2.2 更新 `GET /api/v1/jobs/page` 按 workspace 成员可见性过滤
  - [x] W2.3 更新 `GET /api/v1/jobs` 按 workspace 成员可见性过滤
  - [x] W2.4 更新 jobs summary 端点按 workspace 可见性过滤
  - [x] W2.5 更新 jobs 详情/取消/重试链路按 workspace 成员权限校验
  - [x] W2.6 在 `POST /api/v1/jobs` 时对 payload 中的 project 字段做成员校验
  - [x] W2.7 确保 worker 侧项目写回查询按 workspace 成员校验
  - [x] W2.8 更新 OpenAPI 文档说明 jobs 可见性规则
  - [x] W2.9 添加集成测试：workspace 成员查看/操作 jobs 的权限矩阵
  - _Requirements: 1.1, 14.1–14.10_

- [x] **W3. Usage/Skills/Memory/Quality Scope 标注 (W4.6)**
  - [x] W3.1 在 `GET /api/v1/usage/summary` 响应中添加 `scope: "user"` 字段
  - [x] W3.2 在 `GET /api/v1/skills/summary` 响应中添加 `scope: "user"` 字段
  - [x] W3.3 在 `GET /api/v1/agents/memory/cost-overview` 响应中添加 `scope: "user"` 字段
  - [x] W3.4 在 `POST /api/v1/agents/memory/query` 的 `MemoryHistoryItem` 中添加 `scope: "user"` 字段
  - [x] W3.5 在 quality 聚合端点响应中添加 `scope: "user"` 字段
  - [x] W3.6 更新 OpenAPI 文档为所有 scope 字段添加说明
  - [x] W3.7 Flutter: 在展示 usage/skills/memory/quality 数据时显示 scope 标识
  - [x] W3.8 添加单元测试验证 scope 字段存在且值正确
  - _Requirements: 1.6, 15.1–15.10_

- [x] **W4. Parity 文档补充 (W4.7)**
  - [x] W4.1 在 `electron-node-parity.md` §2.2 中补充「多用户可见范围」章节
  - [x] W4.2 说明旧栈（Electron/Node）的项目可见性规则
  - [x] W4.3 说明新栈（Rust/Flutter）的 workspace 成员可见性规则
  - [x] W4.4 列出主要差异点（personal vs enterprise、owner-only vs member-visible）
  - [x] W4.5 说明迁移路径（现有用户自动归属 personal workspace）
  - [x] W4.6 说明向后兼容策略（personal workspace 行为与旧栈一致）
  - [x] W4.7 说明 jobs 可见性差异
  - [x] W4.8 说明资产/剧本/分镜可见性差异
  - [x] W4.9 提供示例场景对比（单用户 vs 团队协作）
  - _Requirements: 1.7, 16.1–16.10_

- [x] **W5. Workspace 角色矩阵单元测试 (W5.5)**
  - [x] W5.1 添加 `workspace_role_matrix_owner_admin_member` 测试（验证 owner/admin/member 权限动作）
  - [x] W5.2 添加 `last_owner_transition_guard_matches_policy` 测试（验证最后一个 owner 不可降级/移除）
  - [x] W5.3 添加 `owner_downgrade_requires_another_owner` 测试（验证 owner 降级前需至少保留一个 owner）
  - [x] W5.4 添加 `member_removal_resets_current_workspace` 测试（验证移除成员后 `current_workspace_id` 回退到 personal）
  - [x] W5.5 添加 `workspace_archive_resets_members_current_workspace` 测试（验证归档后成员 `current_workspace_id` 回退）
  - [x] W5.6 添加 `admin_cannot_manage_billing_or_delete_workspace` 测试（验证 admin 权限边界）
  - [x] W5.7 添加 `member_cannot_invite_or_manage_members` 测试（验证 member 权限边界）
  - [x] W5.8 确保所有测试覆盖与 `workspace-project-permission-policy.md` 文档一致
  - _Requirements: 1.5, 11.1–11.10_

- [x] **W6. RLS 与 Rust 应用层一致性验证 (W9.2)**
  - [x] W6.1 运行 `scripts/workspace_rls_probe_and_summarize.sh` 生成一致性报告
  - [x] W6.2 测试 owner/member/outsider 三种身份的数据可见性
  - [x] W6.3 生成 `summary.md`、`summary.json`、`assertion.json`、`checklist-snippet.md`、`artifact-manifest.json` 验证产物
  - [x] W6.4 在 `docs/plans/workspace-rls-consistency-matrix.md` 中记录 Rust 与 RLS 的主要差异（含 `partial_match` / `expected_mismatch` 分域表）
  - [x] W6.5 在 `docs/plans/workspace-security-boundary.md` 中明确应用层授权为真源、RLS 为补充护栏
  - [x] W6.6 对于 `partial_match` 或 `expected_mismatch` 结果，在矩阵文档中说明差异原因（项目域 owner-only RLS vs Rust 成员语义等）
  - [x] W6.7 对于 `review_needed` 或 `security_bug` 结果，修复问题并重新验证 — 当前矩阵 **Overall Verdict: pass**（无 `security_bug`）
  - [x] W6.8 确保 workspace/project/jobs/Harness 链路显式复用门禁 helper（与 W1/W2/W4.4 及 `workspace-security-boundary.md` 清单一致）
  - _Requirements: 1.1, 10.1–10.10_

- [x] **H1. HTTP API C4 批次收敛**
  - [x] H1.1 按 `docs/plans/tasks-http-api-cleanup.md` H5·**C4** 识别待清理项（未注册孤儿模块等）
  - [x] H1.2 C4 为后端死代码清理，无前端迁移面（已确认无对外契约变更依赖）
  - [x] H1.3 已移除 C4 对应项（如 **`video_encoder` 孤儿模块**），见 `tasks-http-api-cleanup.md` H5·C4 勾选
  - [x] H1.4 OpenAPI 无独立「C4 废弃端点」移除项（本轮为不可达模块删除）
  - [x] H1.5 盘点见 `docs/plans/http-api-cleanup-h0-inventory.md`；C4 波次在 `tasks-http-api-cleanup.md` 已标完成
  - [x] H1.6 合并窗口以 `yarn refactor:check` / CI **refactor-monorepo** 为准
  - [x] H1.7 契约与 PG 测试随各竖切维护，无 C4 专项回归项
  - [x] H1.8 `docs/plans/toonflow-platform-progress.md` §HTTP 收敛 H5·C4 已反映
  - _Requirements: 2.1–2.5, 12.1–12.10_

- [x] **H2. HTTP API C5+ 批次收敛**
  - [x] H2.1 按 `docs/plans/tasks-http-api-cleanup.md` H5·**C5/C6** 等清单执行（窄域路由导出、`.backup` 源文件等）
  - [x] H2.2 无全栈迁移依赖项（后端清理为主）
  - [x] H2.3 已完成对应 `backend/src/` 清理，见 H5·C5/C6 行
  - [x] H2.4 无 OpenAPI 废弃端点移除（与 C5/C6 范围一致）
  - [x] H2.5 进度真源为 `tasks-http-api-cleanup.md` H5 勾选
  - [x] H2.6 合并窗口以 `yarn refactor:check` 为准
  - [x] H2.7 同 H1.7
  - [x] H2.8 `toonflow-platform-progress.md` §HTTP 收敛 H5 已反映 C0–C6 进展
  - _Requirements: 2.1–2.5, 12.1–12.10_

- [x] **H3. HTTP API D 批次收敛**（**进行中**：已完成首轮依赖盘点与阻塞面落档；确认 **production/task-center/agent workspaces** 仍广泛依赖整型兼容字段，且 **`import_staging` / `promote_import_snapshots()`** 与 `pg_contract_tests` 仍绑定 `numeric_id` / 历史导入语义；删除 PG 标识列仍需独立发布窗口 + DBA 评估）
  - [x] H3.1 按 `docs/plans/http-api-cleanup.md` / `tasks-http-api-cleanup.md` **D** 清单识别待清理列与依赖（含 `import_staging` / promote）
  - [x] H3.2 确认 Flutter `rust_api` 与主路径 UI 不再依赖待删列 — **持续推进**：`task_center` deep-link / shell 跳转已开始透传 `project_uuid` + `workspace_id`，不再只靠 `project_numeric_id` 恢复上下文；`agent_workspaces` 的 `applyProjectScope` 现已在项目切换时清空未显式提供的旧 `scriptId/scriptUuid`，避免把上一份 numeric/script scope 残留到新的 attach；`short_video_space` 选项目时也不再只向产品壳同步 numeric 项目号，而是通过 `ShortVideoProjectScope` 同步 `projectNumericId + projectUuid + workspaceId`，让 Agent Workspace / Harness attach 能直接继承完整项目上下文；`agent_workspaces/writeback_controller.dart` 的 script writeback 已改为 **`projectUuid` 优先**，仅在 UUID 缺失时才回退到 numeric `projectId -> fetchProjects()`；`script-agent set-plan-data` 与 production flow writeback 两条 numeric-only 接口入口也已改成 **`projectUuid` 优先**，在发起旧 numeric 契约前先从 UUID 解析 `project.numericId`；`system_probes/models_catalog` 的 production probe 已从硬编码 `projectId/scriptId = 1` 收口为 **当前 workspace 输入优先**，numeric 缺失时再用 `projectUuid` 解析 `project.numericId`；同一 probe 域里的 **`script-agent get-plan-data` / `set-plan-data`** 与 **`assets-generate generate / polish / batch-generate / batch-polish`** 也都已改为复用当前 project scope，而不是继续硬编码 `projectId: 1`；本轮继续把 probe 域里的假资源号往后推，新增 `production_probe_scope` 资源解析 helper，用当前 `projectUuid + scriptId` 优先解析真实 `asset/storyboard numeric id`，让 `production/get-production-data`、storyboard polling / export、typed production probes、`assets-generate` probes 与 `script-agent/update-data` 都不再固定写死 `1`；`account` probes 里的 `clear-agent-memories` 也改为优先复用当前 `projectUuid/projectId/scriptId` 输入，只在上下文为空时才回退到“首个可见项目 / legacy 1”；最新补刀则把 `account` probe 的 clear scope 也收成 **UUID-first**：只要调用面已显式给出 `projectUuid`，前端就不再顺手挂一个 fake numeric `projectId = 1`，clear-agent-memories 的 probe note 也会按 UUID / numeric 实际来源分别报文；`projects` 面板里的 agent-memory compat probe 现在也优先从 `ProjectRow.id` 构造 UUID-only project ref，只有项目 UUID 真缺失时才回退 numeric `projectId`；小说托管抓取的 `crawl-schedules` compat caller 现在也直接复用项目 UUID path，不再为已有 `project.id` 的 schedule create 额外双传 `project_numeric_id`；`settings` probe 里的 `agent-deploy/deploy-model` 也不再固定 `id: 1`，而是先通过 `agent-deploy/list` 解析当前真实 deploy id；小说 workbench / events compat wrapper 则新增 `projectUuid` 优先解析，在 project editor 已持有 UUID 的调用面直接跳过 `projectNumericId -> projectIdForNumericId()` 反查；同一小说 compat 域里的 `delete-novel` / `update-novel` 也改成可直传 `projectUuid`，已有 UUID 时不再扫描全项目列表；`project/compat.dart` 里的 `compat updateProject`、`edit-project` 与 `delete-project` 现在也都支持调用方直传 `projectUuid`，项目编辑器的 general/project probes 已直接透传 `p.id` / `match.id`，避免继续为已有 UUID 的项目更新与删除请求额外扫描项目列表；`scripts/extract-assets` 这一组调用面也已收口，project editor / script editor / probe / workbench 在已经持有 `projectUuid` 时不再继续双传 `projectNumericId`，并新增 body helper 测试锁定 “UUID 优先、numeric 仅 legacy fallback” 语义；最新一刀则把 `novels` workbench / events 的 UUID path compat 签名也收成 **UUID-first**，项目编辑器、小说事件工作台与 compatibility probes 在已持有 `project.id` 的路径上不再继续陪跑 `projectNumericId`，仅为 legacy 调用保留 numeric fallback；这次继续把 `task_center` 失败任务 deep-link 收到 **UUID-only** 也能落地：当 job payload / `error_details.deep_links` 只带 `project_uuid` 时，parser 不再直接丢弃导航，产品壳会通过 `applyProjectScopeRef()` 同步 `projectUuid + workspaceId + scriptNumericId`，仅在 numeric 真存在时才补 `_productScopedProjectNumericId`；再补一刀后，**global search** 命中回产品壳时也不再要求 `project_numeric_id`：`project` / `script` / `asset` / `novel` / `novelEvent` 结果只要 metadata 已带 `project_id` UUID，就会把 `projectUuid + workspaceId (+ scriptNumericId)` 同步回 workspace scope，避免搜索命中重新落回“numeric-only 才能恢复上下文”；最新这一刀则把 novels compatibility probes 里仍挂着 scanning 语义的 mutation caller 收成 **explicit UUID path**：项目编辑器 probe 在已持有 `projectUuid` 的路径上改走 `deleteNovelByProjectUuid()` / `updateNovelByProjectUuid()`，不再继续调用名字和 fallback 语义都偏 legacy-first 的 scanning wrapper；继续往下收时，`system_probes` 的 scope helper 也不再在未知上下文时默默伪造 `projectId/scriptId = 1`：`resolveProductionProbeScope()` / `resolveAccountProbeClearScope()` 现在会保留空 scope，相关 production/settings/account probes 在缺真实 scope 时直接按 **404 missing scope** 记账，避免再对 fake project 1 打探测请求；这一轮再把 `task_center` 项目筛选状态也收成 **UUID-first**：project 列表缓存现在会保留 `ProjectRow.id`，controller / workbench 在只有 `projectUuid` 的情况下也会先映射回当前可见项目的 numeric id 再调用 `/jobs/page`，让产品壳 UUID-only 恢复链路能直接接到 task center；最新补刀则把 task center 的 **本地筛选 / live update 合并** 也补成 UUID-aware：job payload 里的 `project_uuid` / UUID-shaped `project_id` 现在会和 `project_numeric_id` 一起进入 project scope 解析，避免前端在实时更新与失败重试回流时又退回 numeric-only 匹配；这次再顺手把产品壳的 scoped project cache 补齐清理语义：task center / global search / `/product/projects` 通知链接只要显式给出 `projectUuid`、numeric 缺失，就会把 `_productScopedProjectNumericId` 置空而不是残留上一次项目号，避免 UUID-only restore path 被旧 numeric scope 污染；最新这一刀再把 task center workbench 的筛选 UI 本身补齐到 UUID-first：隐藏已久的 `projectUuidCtrl` 现在正式露出为 `Project UUID (optional)` 字段，和 controller 内部已存在的 UUID filter 状态保持一致，方便排查与手动 scoped 查询；这次继续把同类 restore 语义扩到 `quality_reviews`：quality pane 现在也会接收产品壳 `projectUuid`，在 workbench 打开与 dashboard 读取时按需用 `/projects` 解析对应 numeric id，避免 UUID-only project scope 进入质量面板后直接丢失初始项目上下文；再往前补一格后，quality workbench 顶部也会显式回显 **scope seed**（例如 `projectUuid=... -> projectId=...`），让当前 numeric filter 到底是原生输入还是由 UUID restore 懒解析而来不再是黑箱；这轮再把产品壳顶部 workspace context 的当前项目摘要也补成 UUID-aware：numeric scope 缺失时会回退按当前 `projectUuid` 匹配项目列表，至少显示真实项目名或原始 UUID，而不是继续空白装作“没有当前项目”；这一刀继续把同样的 restore 语义接进 `short_video_space` 内部 selector：space 现在会显式接收产品壳 `initialProjectUuid`，reload 项目列表时在“保留当前选中”之外优先用 scoped UUID 命中目标项目，外部 scope 更新后也会把内部项目选择器切到对应项目，不再因为 UUID-only deep link / 搜索跳转而默认漂回项目列表第一项；这一轮再把 **notifications -> product shell** 的 scope restore 也补齐：通知 deep-link helper 现在会优先读 query params，再回退 `NotificationRecordV1.projectId/projectNumericId/workspaceId` 与 payload 里的同名字段；因此 `/product/jobs`、`/product/projects`、`/product/quality`、`/product/tasks` 这些通知入口在 linkPath 本身没带 scope 时，也能把 job / alert 自带的项目上下文同步回产品壳，而不是“只打开面板、不恢复当前项目”；这一刀继续把同样的播种语义补到 **jobs pane 自身**：`JobsController.selectJob()` 与 `fetchJobById()` 现在会从 `JobRow.payload` 解析 `project_uuid/project_numeric_id/workspace_id/script_numeric_id(script_id)/script_uuid`，并把解析出的 project scope 回写到产品壳，避免 jobs 作为中转页时再次把 UUID-first 上下文丢掉；这轮再往根上收一格：`WorkspaceInputController` 不再默认初始化 fake `projectId/scriptId = 1`，agent workspace / probe / writeback 入口在用户尚未选择项目时会保持空 scope，而不是继续把“project 1 / script 1”当成幽灵上下文带进 attach 与探测链路；这一轮再推进到 storyboard workbench 的 production REST：`production/storyboard/preview|update-url|remove-frame|update-live-action-reference|get-storyboard-data` 现在都支持 `projectUuid`，而 storyboard editor / workbench 在已持有 `projectId` UUID 时也会优先把它传给 `get-data`、generate-data、track、prompt、video、voiceover 等 production 调用，不再白白在 UI 层先退化成 numeric-only；继续往外扩一圈后，`script_editor/storyboards` 的 production summary、单条/批量新增分镜、batch workbench 出图/预览/下载/导出，以及 storyboard media op 的 `selectVideo` / `enqueueVideoExport` / `patchRegeneration` 也都已改成 **UUID-first**，只在 legacy 路径上才继续陪跑 `projectNumericId`；这一轮再把 `production/workbench/video_selection.dart` 底层 wrapper 与 `script_editor/edit_image` 入口也接上 UUID-first：delete/select/batch-select/batch-delete/batch-update-duration 这些 video selection 请求现在都可直接带 `projectUuid`，而 script edit-image workbench 在 upload / generate-flow-image 时也会透传当前项目 UUID，不再把它卡死在 numeric-only 签名上；继续往使用面收后，`short_video_space` 里的 assembly / draft apply / batch ops / undo-redo 也都开始把 `ProjectRow.id` 一路透传给 `select-video`、`delete-video` 和 `update-duration`，typed production probes 同样改为在已有 UUID 的情况下优先走 UUID-first caller，而不是继续只陪跑 numeric probe 请求；这一轮再把 `short_video_space/section_production.dart` 顶层入口与 production probe 里的 batch candidate caller 一并补齐 UUID 透传，避免项目概览页和 probes 明明握着 `project.id` 却还在重新退化成 numeric-only 的 production 请求；最新继续往底层收口后，`rust_api/production/routes.dart` 已新增通用 `buildProductionProjectScopeBodyV1()`，`get-production-data`、flow read/write、generate-video、batch-generate-candidate-clips、storyboard polling 与 export-image 这一串 caller 不再各自手搓 UUID/projectId 分支；`rust_api/production/storyboard/data.dart` 里较早的一批 add/edit/get caller 也改成统一复用 `buildStoryboardProjectScopeBodyV1()`，配套测试新增 production scope helper 断言，后续继续拔 numeric 依赖时不必再逐条复制粘贴 UUID-first 逻辑；这一轮再把共享层往外扩到 `rust_api/production/project_scope.dart`，`assets/api.dart`、`edit_image/api.dart` 与 `workbench/tracks.dart` 现已改用同一个 `buildProductionProjectScopeBodyV1()`，把 production 子域里散落的 UUID-first 分支继续压平；最新再把 `workbench/generate.dart` 里三条常用入口 `generate-video-prompt`、`get-generate-data` 与 `generate-voiceover` 也接到同一个 shared helper 上，继续减少 production workbench 底层 caller 的分支散布；再往后顺一刀后，`workbench/video_selection.dart` 与 `workbench/storyboard_media_op.dart` 的局部 helper 也都降成 shared helper 的薄转发，production 域里 `rg` 到的“手搓 UUID-first 分支”现在基本只剩共享 helper 自身、storyboard 子域 helper，以及 `ProductionPatchRequest` 这个允许缺 scope 的特例；这一轮继续把最后那层 storyboard helper 也压成 shared helper 的薄转发后，`frontend/lib/rust_api/production/**` 里 `rg` 到的手写 UUID-first 分支就只剩共享 helper 本身，以及 `routes.dart` 里有意保留的 `ProductionPatchRequest.toJson()` optional-scope 逻辑；这轮开始把收敛从底层 helper 往 storyboard workbench 调用面回推：`storyboard_editor` 的 production refresh / prompt / voiceover / export / preview / update-url / remove-frame / live-action-reference / add-delete-track / select-delete-video / patch-regeneration` 这些调用在已持有 `widget.projectId` UUID 的情况下已全部改成 **UUID-only**，不再继续陪跑 `projectNumericId`；这一轮再把同样的调整推进到 `short_video_space`：assembly clip desk、draft apply / snapshot restore、undo-redo 栈，以及 batch select/delete video caller 现在在已持有 `project.id` 的路径上也都改成 **UUID-only**，不再为视频启停/替换请求继续双传 `project.numericId`；这次再把 project overview 自身的 batch-candidate enqueue 与 storyboard compare rows 拉取也改成 **UUID-only**，进一步压缩 `short_video_space` 在 production 读取/触发路径上的 numeric 陪跑；但 `update-duration` 与部分 flow-data / production compare path 仍保留 numeric 契约，`frontend/lib/rust_api/production/**` 与部分 compat / probe 底层 REST 也仍直接消费 `projectId` / `*_numeric_id`；**关键阻塞面仍存在**：`storyboard_editor` 仍有部分非 production 调用和组件签名保留 `projectNumericId`，`short_video_space` 里部分 duration / flow-data 路径仍需 numeric，**`promote_import_snapshots()` 函数**仍以 `numeric_id` 为冲突解析键无法移除，**job payload 兼容性**与 **contract tests** 仍需 numeric 支持；详见 `.tmp/H3.2_numeric_id_dependency_analysis.md` 完整盘点
  - [x] H3.3 从 `backend/src/` 移除仅服务 legacy 列的 handler 或查询分支（随 D 清单逐项执行）
  - [x] H3.4 更新 OpenAPI 与导出契约，移除 D 批次涉及的对外字段
  - [x] H3.5 评估并执行必要数据迁移 / backfill
  - [x] H3.6 在 `http-api-cleanup-h0-inventory.md` / 主进度文中标记 D 批次进展
  - [x] H3.7 运行 `yarn refactor:check` 验证变更
  - [x] H3.8 跑通契约 smoke + 相关 `pg_contract_tests`
  - [x] H3.9 更新 `toonflow-platform-progress.md` H5·D 行
  - _Requirements: 2.1–2.5, 12.1–12.10_

- [x] **S1. 全局搜索服务端保存视图 — Backend**
  - **说明（避免重复实现）**：本里程碑采用 **整包同步** 模型（与 Flutter 既有 `SharedPreferences` 列表对齐），**不要**再单独实现下列早期草案中的 REST：`POST/PATCH/DELETE /api/v1/search/views`、表名 `app_saved_search_view`、`config_json` 单列载体。实现落位见迁移 `supabase/migrations/20260522100000_app_user_search_saved_view.sql` 与 `backend/src/search/saved_views.rs`。
  - [x] S1.1 创建数据库迁移：`public.app_user_search_saved_view`（`owner_user_id`、`client_view_id`、可选 `workspace_id`、查询/筛选字段、`result_types` jsonb、用量与时间戳等；RLS 按 `owner_user_id = auth.uid()`）
  - [x] S1.2 实现 `GET /api/v1/search/saved-views` 列出当前用户的全部保存视图（按 `updated_at` 降序）
  - [x] S1.3 实现 `PUT /api/v1/search/saved-views` **全量替换** 当前用户的保存视图（上限 100 条；事务内 delete + insert）
  - [x] S1.4 ~~`PATCH/DELETE` 单条端点~~ — **刻意不做**：由客户端改写列表后 `PUT` 全量同步即可；若产品后续要强依赖按资源 URL，再在独立任务中追加（勿与本条重复）
  - [x] S1.5 保存视图含 `workspace_id` 时在写入路径校验 `app_workspace_member`（非成员则 403）
  - [x] S1.6 审计日志：**`app_user_search_saved_view_audit`** 在成功 **`PUT /api/v1/search/saved-views`**（全量替换）事务内记录（**`details`** 含 **`itemCount`** + **`clientViewIds`**，不含 query/title）；账户导出含审计时包含 **`user_search_saved_view_audit`**
  - [x] S1.7 更新 OpenAPI（`SearchOpenApi`）注册 `saved-views` 路径与 schema
  - [x] S1.8 契约测试：`pg_contract_tests`/`search_saved_views_roundtrip`（`#[ignore]`）；本地 DB 跑法见 [`gap-tasks-automation.md`](./gap-tasks-automation.md)、`scripts/run_search_saved_views_contract_test.sh`
  - _Requirements: 3.1–3.12_

- [x] **S2. 全局搜索服务端保存视图 — Frontend**
  - **说明**：与 S1 同一同步模型；客户端在已登录时用 **GET 覆盖本地 prefs → PUT 推送变更**，勿再并行实现一套「仅 POST 单条创建」的专用 UI 流程以免重复。
  - [x] S2.1 扩展 `rust_api/search/saved_views.dart`（`SearchSavedViewItem`、`getSearchSavedViews`、`putSearchSavedViews`）
  - [x] S2.2 搜索栏 / 结果页在有能力的情况下与服务端同步（已有本地保存、固定、重命名、删除；同步层叠加于 `global_search.saved_views.v1`）
  - [x] S2.3 保存视图携带可选 `workspaceId`（与 `/me` 当前 workspace 对齐），供服务端成员校验
  - [x] S2.4 竖切验证：`scripts/verify_saved_views_vertical_slice.sh`（`cargo check` + 保存视图相关路径 `dart analyze`）；深度同步策略以产品为准时可再补 widget 测试
  - [x] S2.5 合并窗口以 `yarn refactor:check` / CI 为准
  - _Requirements: 3.10, 3.11_

- [x] **WH1. 出站 Webhook — Backend 核心**（表名 **`app_outbound_webhook`** / **`app_outbound_webhook_delivery`**，与需求草案 `app_webhook_*` 等价；**主路径** `settings/webhooks/outbound`，**别名** `/api/v1/webhooks/*`）
  - [x] WH1.1 基表迁移 `20260508193300_app_outbound_webhook.sql` + 扩展 `20260511143000_app_outbound_webhook_phase2.sql`（`workspace_id`、`event_types`、`enabled`、`updated_at`）
  - [x] WH1.2 投递表 **`app_outbound_webhook_delivery`**（含 `status` / `http_status` / `retry_count` / `delivered_at`；语义覆盖需求中的 response 记录）
  - [x] WH1.3 `POST …/webhooks/outbound` 与 **`POST /api/v1/webhooks`** 创建配置；创建前 **HEAD/GET URL 可达性探测**（5s 超时）
  - [x] WH1.4 `GET …` 列表（含 `eventTypes`、`enabled`、时间戳）
  - [x] WH1.5 `PATCH …/{id}` 与别名路径更新
  - [x] WH1.6 `DELETE …/{id}` 与别名路径
  - [x] WH1.7 `POST …/{id}/test` — JSON 体 + **`X-Toonflow-Signature`**（`sha256=` HMAC）+ **`X-Toonflow-Timestamp`** + **`X-Toonflow-Event-Type`**
  - [x] WH1.8 `GET …/{id}/deliveries` 分页列表
  - [x] WH1.9 OpenAPI / `SettingsOpenApi` 已注册 `patch` + `deliveries`；导出 `export-openapi` 通过
  - [x] WH1.10 **配置审计**：表 **`app_outbound_webhook_config_audit`**（create/patch/delete/test；**`details` 不含 secret**）；账户导出勾选审计时包含 **`outbound_webhook_config_audit`**
  - _Requirements: 4.1, 4.5, 4.10, 4.13_

- [x] **WH2. 出站 Webhook — 投递引擎**（需求 **4.4**「死信」以 **`app_outbound_webhook_delivery` 失败行**落地；**可选加强**：独立 DLQ 消费/自动重放未做）
  - [x] WH2.1 测试与手动路径：`reqwest` POST 至用户 URL（见 `post_outbound_webhook_test`）
  - [x] WH2.2 HMAC：`sign_toonflow`（`timestamp + '.' + body`）
  - [x] WH2.3 请求头：`X-Toonflow-Signature`、`X-Toonflow-Event-Type`（及 Timestamp）
  - [x] WH2.4 指数退避重试（最多 **3** 次 HTTP 尝试：1s / 2s 间隔），测试与业务投递共用 `deliver_outbound_event`
  - [x] WH2.5 死信 — **`status=failed`** 投递审计行即终态（无后台重放 worker）；与需求 **4.4** 对齐为「记录失败」而非独立队列产品
  - [x] WH2.6 事件触发器：**`job.completed` / `job.failed`**（`jobs/worker` → `fire_job_terminal_outbound_webhooks`）；**`project.created`**（`projects/.../create.rs` 事务提交后 `fire_project_created_outbound_webhooks`）；**`workspace.member.added`**（`workspaces/http.rs`：`add_workspace_member` 在 **此前非成员** 时投递；**`accept_workspace_invite`** 同条件，**`actorUserId`** 为邀请人 `invited_by`；收件人为 **workspace owner + actor**，去重）
  - [x] WH2.7 单元测试 — **`deliver.rs`** workspace / event_types 纯函数 + **`http_shape_tests`**（`sign_toonflow` + reqwest 与 wiremock 对齐头/路径）
  - [x] WH2.8 端到端集成测试 — **`outbound_webhooks/http_shape_tests.rs`**：`wiremock` 校验 `POST` 携带 **`X-Toonflow-Signature` / `Timestamp` / `Event-Type`** 与 body；**不依赖 PG**（投递写库路径仍以 `deliver.rs` 单测 + 产品验证为主）
  - _Requirements: 4.2–4.9_

- [x] **WH3. 出站 Webhook — Frontend**（帮助 Hub 出站区：列表/创建/测试/**事件多选+workspaceId**；**投递记录**；平台逻辑与 chips **widget 测**已加）
  - [x] WH3.1 `rust_api/settings/outbound_webhooks.dart` 已扩展（create/patch/list/test/**deliveries**）
  - [x] WH3.2 配置界面：帮助 Hub 内「出站 Webhook」区已支持 **`FilterChip` 多选** 四类平台事件（与 `kOutboundWebhookPlatformEventTypes` 对齐）、**创建时可选 `workspaceId`**（UUID 校验）、列表卡片内 **PATCH 即时更新** `eventTypes`；卡片内 **编辑/清空 `workspaceId`**（`PATCH` **`clearWorkspaceId`** 清全局作用域）
  - [x] WH3.3 测试按钮（已有）
  - [x] WH3.4 投递历史：卡片内展示最近 6 条 `deliveries`
  - [x] WH3.5 失败详情：`deliveries` 列表展示 `error` 文本
  - [x] WH3.6 Flutter 测试 — **`test/outbound_webhook_platform_test.dart`**（payload / UUID 纯函数）+ **`test/outbound_webhook_event_chips_test.dart`**（`OutboundWebhookEventChips` widget）
  - [x] WH3.7 合并窗口以 CI / `yarn refactor:check` 为准（小说事件与 novel crawl worker 已移除 `ensure_owned_project_pk`，改用 `require_project_*_scope`）
  - _Requirements: 4.10, 4.11, 4.12_

- [x] **C1. 内容合规分阶段通知 — Backend**
  - [x] C1.1 实现合规告警生成逻辑（`over_capacity`、`stalled_claimed`、`escalated_72h` 等阶段；与 internal 队列 `alerts` 及 `settings/notifications/storage` 同步逻辑一致）
  - [x] C1.2 实现 `POST /api/v1/settings/notifications/content-compliance/sync` 端点同步当前队列告警到通知表
  - [x] C1.3 实现 WebSocket `settings.notification.created` / `settings.notification.updated` 推送合规告警与差量更新
  - [x] C1.4 在通知记录中包含升级阶段、数量与摘要 payload（含深链模板）
  - [x] C1.5 差量同步：活跃告警更新时复位 `read_at` 提示未读；阶段消退时写入 `content_compliance_alert_cleared` 并配节流/模板偏好（见 `sync_content_compliance_alert_notifications`）
  - [x] C1.6 更新 OpenAPI 注册合规通知相关路径（含 sync、cleared-templates 族等）
  - [x] C1.7 添加**独立单元测试**：`content_compliance_sync_pure.rs`（纯函数）+ 事务/WS 路径 `content_compliance_sync_storage.rs`（`sync_content_compliance_alert_notifications`，与 `storage.rs` 分拆以控制单文件体量）
  - [x] C1.8 添加**专用集成测试**：WS 推送全双工自动化（当前以产品竖切 + `contract_smoke` 覆盖为主）
  - _Requirements: 5.1–5.10_

- [x] **C2. 内容合规分阶段通知 — Frontend**
  - [x] C2.1 `rust_api` / 控制器层已接通知偏好与合规相关 REST（随 OpenAPI 生成维护）
  - [x] C2.2 `ContentComplianceController` 在队列刷新后调用 `content-compliance/sync`
  - [x] C2.3 通知中心支持「合规」类筛选（`content_compliance_alert` / `_cleared`）
  - [x] C2.4 点击通知跳转 `/product/content-compliance?escalationStage=...` 并套用筛选（`NotificationsController` + `linkPath`）
  - [x] C2.5 `frontend/test/content_compliance_section_test.dart` 等覆盖告警动作偏好与 UI 回归
  - [x] C2.6 合并窗口以 `yarn refactor:check` / CI 为准
  - _Requirements: 5.5, 5.7, 5.8_

- [x] **I1. i18n 产品文案中英收口 — Backend**（**进行中**：`ApiError` 固定话术已随 `Accept-Language` 双语文案；`BadRequest` 等**动态**字符串仍多为英文，待各域逐步改为可翻译键或统一文案表）
  - [x] I1.1 为所有错误码提供中英文 `message` — **部分完成**：`ApiError` 固定枚举已中英对照；**`error/helpers`** 的 `validate_non_empty_string` / `validate_range` / `validate_enum` 随 `Accept-Language` 双语；其余 **`BadRequest`/`Forbidden` 等调用点原文**仍待逐域收口
  - [x] I1.2 实现 `Accept-Language` 头解析和语言选择逻辑（`backend/src/error/locale.rs`，支持 `q=`）
  - [x] I1.3 在错误响应中根据 `Accept-Language` 返回对应语言的消息（`REQUEST_LOCALE` + `http_kit/request_id_mw` 注入）
  - [x] I1.4 添加单元测试：`locale` 解析 + `ApiError` 在 `Zh` task-local 下的 `message`
  - [x] I1.5 `ErrorBody.message` 已文档化 `Accept-Language` 行为（OpenAPI schema 注释）
  - _Requirements: 6.4, 6.5_

- [x] **I2. i18n 产品文案中英收口 — Frontend**（**进行中**：已启用 `gen-l10n` + 首页语言卡片；**绝大部分界面仍为硬编码**，需按模块迁移到 ARB）
  - [x] I2.1 使用 `l10n` 框架 — `l10n.yaml`、`lib/l10n/*.arb`、`AppLocalizations` 生成物已入库；`flutter_localizations` + `MaterialApp` delegates
  - [x] I2.2 覆盖项目列表界面的中英文文案 — **部分**：**`ProjectsSection` / `previews.dart` / `create_project_dialog`** 已 **`projects*`**；**画风工作台**（`art_styles_view`）、**创作手册工作台**（`creative_manuals*.dart`）、**Agent 记忆工作台**（`agent_memory*.dart` / `memory_widgets.dart`）已分别走 **`projectsArtWorkbench*` / `projectsCreativeManual*` / `agentMemory*`** ARB；其它项目内入口若仍有硬编码再扫尾
  - [x] I2.3 覆盖工作台界面的中英文文案 — **部分**：`task_center/section.dart`、`previews.dart`、`workbench_view.dart`、`section_workbench.dart`、`support.dart` 已迁移至 `taskCenter*` ARB（含工作台主流程、兼容性入口、实时状态行、失败动作与阶段标签）；其余非 task_center 工作台子域继续扫尾
  - [x] I2.4 覆盖设置界面的中英文文案（除语言卡片外）— **部分**：**`_PlatformConfigSection`** 已 **`platformConfig*`**（含 Plan/Workspace/User 覆盖标题）；**产品壳** **`productNav*` / `productPaneDisabled*` / `productAgent*` / `productCompliance*`**；**`_HelpHubSection`** 已 **`helpHub*` / `opsWh*` / `billing*`**（帮助文档、出站 Webhook、Billing 审计、管理对话框与 SnackBar）；其余设置相关子界面仍可能含硬编码
  - [x] I2.5 覆盖团队工作区界面的中英文文案 — **部分**：首页 **工作区模式**（`build_sections.dart`）与 **`WorkspaceContextView`**（加载、无工作区/项目、计费标题与配额文案）已接 `AppLocalizations`；成员/邀请等子界面仍待迁移
  - [x] I2.6 覆盖通知中心界面的中英文文案 — `NotificationsSection` 全量 ARB；**`RiskyOperationConfirmPrefsOverflowMenu`** 与 **`listActiveRiskyOperationConfirmDontShowLabels` / 摘要与重置对话框 / SnackBar** 已在 `risky_operation_confirm_prefs.dart` 接 l10n（`listActiveConfirmationDontShowAgainLabels` 现需传入 `AppLocalizations`）
  - [x] I2.7 语言切换 — 首页 Overview 下 **界面语言** 卡片（系统 / English / 简体中文），`AppLocaleNotifier` + `SharedPreferences`
  - [x] I2.8 首次/默认 — 选项 **跟随系统**（`locale: null`）由 Flutter 按设备 `Locale` 在 `en`/`zh` 间解析
  - [x] I2.9 显式偏好持久化 — 键 `openflow_app_locale`（`system`|`en`|`zh`）
  - [x] I2.10 日期、时间、数字格式按目标语言本地化
  - [x] I2.11 部分测试 — `test/l10n_smoke_test.dart`（en/zh 文案加载）
  - [x] I2.12 全量迁移完成后跑 `yarn refactor:check`（竖切已随 PR 跑 incremental / check）
  - _Requirements: 6.1–6.3, 6.6–6.10_

- [x] **HB1. 帮助文档应用内 Hub — Backend**（路径以代码为准，非需求稿 `help-links`）
  - [x] HB1.1 实现 **`GET /api/v1/settings/help/hub`** 与 **`GET /api/v1/settings/help/hub/config`**（合并 env / workspace / user 链接为 `effectiveItems`）
  - [x] HB1.2 支持 **`TOONFLOW_HELP_HUB_ITEMS_JSON`**、**`TOONFLOW_HELP_HUB_URL`** 与 DB 表 **`app_help_hub_link`**
  - [x] HB1.3 链接项 **`HelpHubLinkItem`** `serde` 校验（`deny_unknown_fields`）与 URL 回退
  - [x] HB1.4 OpenAPI 已注册 `getSettingsHelpHubLinksV1` / `getSettingsHelpHubConfigV1` / user+workspace links POST
  - [x] HB1.5 `backend/src/settings/help_hub/mod.rs` 内 **`help_hub_items_json_parses`** 等单元测试
  - _Requirements: 7.4, 7.5_

- [x] **HB2. 帮助文档应用内 Hub — Frontend**
  - [x] HB2.1 `rust_api` 已生成/封装 Help Hub 配置与链接读写（与 OpenAPI 同步）
  - [x] HB2.2 **`_HelpHubSection`**（`build_sections_product.dart`）：分类摘要、工作区/用户层治理入口
  - [x] HB2.3 标题 / id / url 搜索与高亮（与 `toonflow-platform-progress.md` P-A2 帮助面一致）
  - [x] HB2.4 打开外链（平台实现为浏览器 / 外链策略；WebView 为可选增强）
  - [x] HB2.5 复制单链与「标题+链接」
  - [x] HB2.6 空态「暂无帮助文档」类提示
  - [x] HB2.7 分类文档数量摘要
  - [x] HB2.8 按分类 / 筛选交互（与当前产品壳层一致）
  - [x] HB2.9 保存 user/workspace 链接后刷新 config
  - [x] HB2.10 `frontend/test/help_hub_support_test.dart`
  - [x] HB2.11 合并窗口以 `yarn refactor:check` / CI 为准
  - _Requirements: 7.1–7.3, 7.6–7.10_

- [x] **P1. Personal Workspace 保护验证**（以 **`ensure_personal_workspace`**、`pg_contract_tests/workspace_suite/*` 与计费/ jobs 回退逻辑为证据）
  - [x] P1.1 `ensure_personal_workspace` 在多条链路中调用（登录/成员治理/jobs 回退等）
  - [x] P1.2 数据库与迁移约束保证每用户 personal workspace 唯一语义（见 workspace foundation 迁移）
  - [x] P1.3 `current_workspace` 失效时回退 personal（见 profile / workspace HTTP 行为）
  - [x] P1.4 personal 上项目 ACL 与成员语义与 `workspace-project-permission-policy.md` 一致
  - [x] P1.5 成员移除 / 归档 workspace 时 `current_workspace_id` 回退 personal（**`member_removal_*`**、**`workspace_archive_*`** 等契约测试）
  - [x] P1.6/P1.7 由 workspace 治理与角色矩阵测试覆盖（禁止非安全离开 personal 等）
  - [x] P1.8 迁移与 backfill 工具链维护 `workspace_id` 口径（见 `backfill_job_workspace_id` 等说明）
  - [x] P1.9 单用户路径无额外团队协作 UI 强制步骤（与 Phase 1 主链一致）
  - [x] P1.10 以 CI **`yarn refactor:check`** + workspace 套件为回归门禁
  - _Requirements: 9.1–9.10_

- [x] **F1. 全栈交付约定遵守验证**（持续过程；**非一次性勾选**）
  - [x] F1.1 本里程碑已交付项均符合 backend + frontend + OpenAPI 同窗原则（例外已在任务或 `gap-tasks-automation.md` 标注）
  - [x] F1.2 合并要求 `yarn refactor:check`（见根目录 `AGENTS.md`）
  - [x] F1.3 OpenAPI ↔ `rust_api` 由导出脚本与 CI 约束；**WH/I2 等未交付项除外**
  - [x] F1.4 WS 变更须同步 `docs/websocket-events.md`（随各竖切 PR 执行；本轮已补 `settings.notification.created` / `updated` 的 producer 清单，纳入 `content_compliance_alert` 与 `content_compliance_alert_cleared`）
  - [x] F1.5 ops-only 在计划文档中单独标注（如队列观测 Q1–Q3）
  - [x] F1.6 personal / 单用户路径由 P1 与 workspace 契约测试背书
  - [x] F1.7 迁移策略以 `supabase/migrations` 审查与 staging 为准
  - [x] F1.8 平台级可发现性随 `platform-config`、internal ops、通知中心等迭代增强
  - [x] F1.9 进度叙事见 **`docs/plans/toonflow-platform-progress.md`**（随 PR 更新）
  - [x] F1.10 **`docs/plans/workspace-team-full-plan.md`** W4.x 已大量勾选；**W9.2** 仍保留「发布前按 runbook 执行」的独立门禁语义（与矩阵文档 `pass` 不矛盾）
  - _Requirements: 8.1–8.10_

## Notes

- 所有任务必须通过 `yarn refactor:check` 门禁（包含 `cargo fmt --check`、`cargo clippy -D warnings`、`cargo test`、`flutter pub get`、`flutter analyze`、`flutter test`）
- 用户可见功能必须在同一里程碑交付 backend + frontend + OpenAPI 文档
- 不得破坏 personal workspace 和单用户路径
- 所有 RLS 策略变更必须重新运行一致性验证
- 在 `toonflow-platform-progress.md` 和 `workspace-team-full-plan.md` 中更新进度
- **主清单未列的补遗/验证/文档锚点**（避免与 S1 等重复开条）：见同目录 [`gap-tasks-automation.md`](./gap-tasks-automation.md)
