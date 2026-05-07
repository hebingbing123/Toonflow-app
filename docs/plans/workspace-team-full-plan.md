# 团队 Workspace 完整功能 — 任务总表（非 MVP）

**定位**：在 **个人路径（Personal Workspace）已落地** 的前提下，把 **enterprise 工作区、成员生命周期、权限、全站 API/前端/Harness/计费与观测** 做成 **可对外承诺的完整产品能力**，而不是「最小演示」。  
**个人与团队并存**：任何改动 **不得破坏** 现有 `personal` 唯一性、`ensure_personal_workspace` 默认行为与既有项目归属。

**关联**：[`harness-rust-flutter.md`](./harness-rust-flutter.md)（组织/工作区按阶段）、[`toonflow-platform-progress.md`](./toonflow-platform-progress.md) §1 基线、迁移 `supabase/migrations/*app_workspace*`。  
**门禁**：凡动 `backend/` / `frontend/` / OpenAPI / 迁移 / WS 文档，合并前 **`yarn refactor:check`**。

## 〇、全栈交付（适用于 W1–W11 全部条目）

- 与 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md) 一致：凡 **用户 / 运营可见** 的 REST、WS、设置项，**同一里程碑**须交付 **`backend/` + `frontend/`（`rust_api` + 主路径或内部控制台 UI）** + OpenAPI/WS 文档 + 测试；不得长期停留在「仅 Rust 合并」。
- **W6** 为 Flutter 体验收口 Phase，**不得晚于** W1–W4 相关 API 稳定版 **超过 1 个发布周期**；若 API 先上，须在 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 标 **debt** 与目标日期。
- **平台级通用能力**（应用内通知、全局搜索、API Key、出站 webhook、账户导出/删号等）见 [**`platform-capabilities-backlog.md`**](./platform-capabilities-backlog.md)；纳入本计划时在对应 Phase 增行并回链该表。

---

## 一、当前基线（已实现，本计划不重复造轮子）

- [x] `app_workspace`（`personal` | `enterprise`）、每人唯一 `personal`
- [x] `app_workspace_member`（`owner` | `admin` | `member`）
- [x] `app_user_profile.current_workspace_id`
- [x] `app_project.workspace_id` + 创建时写入 personal workspace
- [x] `GET /api/v1/me` 返回 `current_workspace`
- [x] Flutter `WorkspaceContextView` + `WorkspaceSummary`
- [x] Supabase RLS（workspace / member 表）；**须在后文 P9 与 Rust 连接方式对齐文档**

---

## 二、Phase W1 — Workspace 生命周期（企业空间本体）

> **全栈**：W1 每条须 **Rust + OpenAPI + `rust_api` + Flutter**（创建/列表/详情/编辑入口；归档须有 UI 确认）。

- [x] **W1.1** `POST /api/v1/workspaces`：创建 `enterprise`（名称、可选 **metadata** JSON object；slug 仍 **未做**）
- [x] **W1.2** `GET /api/v1/workspaces`：列出当前用户 **作为 member** 的全部 workspace（personal 优先排序 + enterprise）
- [x] **W1.3** `GET /api/v1/workspaces/{workspace_id}`：详情（仅 member 可读）
- [x] **W1.4** `PATCH /api/v1/workspaces/{workspace_id}`：改名、metadata（**owner/admin**）
- [x] **W1.5** 归档：`archived_at` + 列表默认过滤 + 归档时若命中 **current_workspace** 则重置到 **personal**（`PATCH` **`archive`**）
- [x] **W1.6** 企业空间 **数量上限**：每用户拥有的 **active enterprise** 上限（**`TOONFLOW_MAX_ENTERPRISE_WORKSPACES_PER_USER`**，默认 50；超限 **429**）；每空间成员上限仍待 W2+
- [x] **W1.7** OpenAPI + `pg_contract`（`workspaces_crud_roundtrip`，需迁移 DB **`#[ignore]`**）+ contract smoke（无 DB **503**）

---

## 三、Phase W2 — 成员与邀请（完整闭环）

- [x] **W2.1** `POST …/workspaces/{id}/members`：**直接添加** 已存在用户（`user_id` + `role`）；已落地 owner/admin 鉴权 + 角色限制（`admin/member`）+ Flutter 成员管理入口（查看 + 添加）
- [x] **W2.2** 邀请表 `app_workspace_invite`：`email` / `token` / `expires_at` / `role` / `invited_by` / 状态（pending/accepted/revoked）已迁移
- [x] **W2.3** `POST …/workspaces/{id}/invites`：生成邀请（当前先返回 token 链接形态；邮件发送待 W2.9 Runbook 补充）
- [x] **W2.4** `POST /api/v1/workspaces/invites/accept`：凭 token 加入 member（幂等 upsert + 过期/状态冲突校验）
- [x] **W2.5** `DELETE …/members/{user_id}` / `PATCH …/members/{user_id}`：移除、改角色（已加“最后一个 owner 不可降级/移除”保护；owner 转让流程另列后续）
- [x] **W2.6** 成员 **主动离开** workspace：`DELETE …/members/me` 已落地；`personal` 禁止离开、最后 owner 禁止离开、离开后命中 current workspace 自动回退 personal
- [x] **W2.7** 审计：新增 `app_workspace_audit` 并在成员/邀请关键动作写入 `workspace_id + actor + action + target_user + details + timestamp`
- [x] **W2.8** 速率限制：邀请/添加成员防滥用（基于 `app_workspace_audit` 的每 workspace 每小时上限，env：`TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR`）
- [x] **W2.9** OpenAPI + 契约测试 + **邮件/无邮件** 双路径说明写入 Runbook（见 [`workspace-invite-runbook.md`](./workspace-invite-runbook.md)）

---

## 四、Phase W3 — 当前上下文与「个人/团队」切换

- [x] **W3.1** `PATCH /api/v1/me/current-workspace`：切换 `current_workspace_id`（强校验 membership）；Flutter 团队工作区列表已加“切换到此”入口
- [x] **W3.2** 切换后 **全客户端状态**：项目列表、选中 project、Harness attach、短剧空间上下文统一刷新（通过 `onWorkspaceContextChanged` 收口）
- [x] **W3.3** 首次登录默认 workspace 规则：`/me` 优先读取 `current_workspace_id`（记忆上次）；若失效/非成员自动回退 personal 并修正 profile
- [x] **W3.4** 错误码：非成员切换返回明确 `403`（`forbidden`）
- [x] **W3.5** OpenAPI + integration：新增 `me_current_workspace_switch_roundtrip`（pg_contract `#[ignore]`）验证切换后 `/me.current_workspace` 回读一致

---

## 五、Phase W4 — 资源范围：项目为轴，扩展到全站

> 原则：**`workspace_id` 为空间边界**；`owner_user_id` 保留为「创建者/责任人」，**可见性与写权限**由 **workspace 角色 + 可选项目级 ACL** 决定（见 W5）。  
> **全栈**：每条 handler 变更须对应 **Flutter 工作台 / 项目编辑器** 与 **`rust_api`** 联调，禁止只改后端。

- [x] **W4.1** `GET /api/v1/projects`：默认按 `current_workspace_id` 过滤；若 profile 指向失效则回退 personal（同 workspace 视角可见项目）
- [x] **W4.2** `POST /api/v1/projects`：默认当前 workspace（含 personal 回退）；支持显式 `workspaceId` 且强校验 membership，非成员写入返回 `403`
- [x] **W4.3** `GET/PATCH/DELETE …/projects/{id}`：已改为按 **project.workspace_id + workspace member** 校验（移除 owner_user_id 单用户闸门）
- [ ] **W4.4** 剧本 / 分镜 / 小说 / 资产 / workbench **所有** `project_id` 路径 handler：统一走 **「project ∈ workspace + 成员权限」** 中间件或 helper（进行中：已抽 `require_project_workspace_member_scope` 并接入 `project/home`、`project/stats`、`project/style-config`、`project/overview`、`project/assets-overview`、`project/production-overview`、`project/short-video-assembly`、`project/short-video-export-check`、`project/short-video-readiness`；并将资产域公共 `ensure_owned_project_pk` 切为 workspace 成员校验，小说 `project_id` CRUD 与小说事件 `project_id` 列表/删除/批删/生成查询内联 owner 过滤已移除；资产 workbench 的 image-bundle/polling/save 查询内联 owner 过滤已移除）
- [ ] **W4.5** `app_generation_job`（及 payload）：是否挂 `workspace_id` 或由 `project_id` 派生 — **书面定稿** + 列表/取消/统计接口一致
- [ ] **W4.6** `GET /api/v1/usage/summary`、memory、skills、quality 等：**定义**是否按 workspace 聚合或保持 user；**实现与 OpenAPI 一致**
- [ ] **W4.7** Parity：[ `electron-node-parity.md`](./electron-node-parity.md) 更新「多用户可见范围」与旧栈差异说明

---

## 六、Phase W5 — 权限矩阵（项目级可选，workspace 级必选）

- [ ] **W5.1** 文档化 **workspace 角色矩阵**：owner / admin / member 对「邀请、改计费、删空间、改全部项目」的布尔表
- [ ] **W5.2**（可选加强）**项目级角色**：`editor` / `viewer` 仅针对单项目 — 新表 `app_project_member` 或 JSON policy
- [ ] **W5.3** 默认策略：member 是否可 **创建** 项目、是否可 **删除他人项目** — 产品签字
- [ ] **W5.4** 与 **计费 `plan_tier`** 关系：按 user 还是按 workspace 计费 — **财务/产品** 结论驱动 schema（`app_workspace` 增加 `plan_tier` 等或维持 user）
- [ ] **W5.5** 单元测试覆盖矩阵边角（最后一个 owner、降级 admin 等）

---

## 七、Phase W6 — Flutter 产品面（完整 UX）

- [ ] **W6.1** Workspace **选择器**（抽屉或设置页）：列表、当前高亮、切换
- [ ] **W6.2** **创建企业空间** 流程（表单 + 错误提示）
- [ ] **W6.3** **成员管理页**：列表、搜索用户、改角色、移除、邀请 pending 列表
- [ ] **W6.4** **接受邀请** 深链 / 路由（Web + 桌面一致策略）
- [ ] **W6.5** 空状态：无 enterprise 时的引导；无项目时的团队引导
- [ ] **W6.6** `rust_api` 全量模型与生成/手写 client 与 OpenAPI **一致**（跑 `scripts/check_rust_api_consistency.sh`）
- [ ] **W6.7** a11y / 国际化字符串（若产品要求）

---

## 八、Phase W7 — Harness / WebSocket

- [ ] **W7.1** `HarnessContext`（或 attach payload）增加 **`workspace_id`**（UUID）与 **解析规则**（与 REST 一致）
- [ ] **W7.2** `docs/websocket-events.md`：attach / context 更新事件字段表
- [ ] **W7.3** 工具权限：`permissions` 模块按 workspace 成员校验 **读 production/script** 等 channel
- [ ] **W7.4** Flutter WS 客户端：切换 workspace 后 **重 attach** 或刷新 context
- [ ] **W7.5** 回归：`agent_workspaces` 相关测试 + 手工矩阵

---

## 九、Phase W8 — 计费、用量、任务配额（与空间绑定策略）

- [ ] **W8.1** 结论落地文档：`plan_tier` / `daily_job_quota` / `jobs_today` **按 user 还是按 workspace**（或 hybrid）
- [ ] **W8.2** 若按 workspace：`app_user_profile` vs `app_workspace` 字段迁移 + webhook 与 **`/me`** 响应形状变更策略（版本化）
- [ ] **W8.3** Billing 运营视图是否按 workspace 过滤 — 与 [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) WP-D 对齐
- [ ] **W8.4** 迁移与回填脚本 + 回滚 Runbook

---

## 十、Phase W9 — 安全：RLS、服务角色与双路径

- [ ] **W9.1** 文档：**Rust `DATABASE_URL`** 是否使用 **service role**；若绕过 RLS，**应用层**必须 100% 复现成员规则（对照清单）
- [ ] **W9.2** Supabase **直连客户端**（若有）与 RLS 策略一致性测试
- [ ] **W9.3** 敏感操作二次确认（删空间、转 owner）— 产品流程
- [ ] **W9.4** 安全评审：邀请 token 熵、过期、重放、速率限制

---

## 十一、Phase W10 — 观测与运维

- [ ] **W10.1** 结构化日志 / trace：`workspace_id` 贯穿 HTTP、job、Harness（与 [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md)、[`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F 对齐）
- [ ] **W10.2** 管理指标：每 workspace 成员数、项目数、活跃 jobs（脱敏）
- [ ] **W10.3** Runbook：成员无法访问、错误切换、数据修复 SQL 模板（只读/受控）

---

## 十二、Phase W11 — 发布、文档与门禁

- [ ] **W11.1** [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 按 Phase 更新状态与 commit
- [ ] **W11.2** [`roadmap-index.md`](./roadmap-index.md) 若拆出 `roadmap-workspace.md` 可再索引（当前以本文为真源）
- [ ] **W11.3** 破坏性变更：**客户端版本** / 迁移公告
- [ ] **W11.4** 全量 `yarn refactor:check` 纳入合并必跑

---

## 十三、建议实施顺序（依赖）

```text
W1 → W2 → W3 → W4（与 W7 尽量同一「大竖切」窗口内交替，防 REST/WS 断裂）
→ W5（可与 W4 后半并行）
→ W6（紧贴 W3/W4 API 稳定面）
→ W8（待 W5 计费策略定稿）
→ W9 / W10 / W11 贯穿各 Phase 文档与收口
```

---

## 十四、完成定义（整计划）

- [ ] **W1–W11** 各 Phase 勾选完成或明确 **「不做」** 并记录理由（产品签字）。
- [ ] 个人用户 **零回归**（personal workspace、单用户项目主路径）。
- [ ] `yarn refactor:check` 与 parity / WS 文档持续绿。
- [ ] **全栈**：无「仅后端已合并、Flutter 仍断」的开放项；[`full-stack-delivery-covenant.md`](./full-stack-delivery-covenant.md) 例外已书面登记。

---

## 十五、与平台能力补遗表的关系

主表 W1–W11 专注 **Workspace / 成员 / 权限 / 计费绑定**。[**`platform-capabilities-backlog.md`**](./platform-capabilities-backlog.md) 中的 **通知、搜索、API Key、出站 webhook、账户导出** 等与租户强相关项，在排期时 **并入 W2/W4/W8/W11** 或单独立项，并在本文件增加交叉引用行，避免平台级遗漏。

---

*维护：每完成一个可合并竖切，更新本文件勾选与 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md)。*
