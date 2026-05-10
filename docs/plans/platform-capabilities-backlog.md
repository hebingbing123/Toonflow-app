# 平台级能力补遗（全栈任务池，与路线图正交）

**用途**：主路线图（`harness-rust-flutter`、`roadmap-*`、[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)）已覆盖 **核心产品链**；本文件收集 **平台级** 常见能力，避免「文档里从未出现 → 团队以为不用做」。  
**交付**：每条默认 **Rust + OpenAPI（如适用）+ Flutter（或 Web 管理端）**；参见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

**状态**：`planned`（未排期）— 纳入某 Phase 时在对应主计划打勾并在此更新链接。

---

## A. 用户可感知与账户

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-A1 | **应用内通知中心**（任务完成、成员邀请、计费事件摘要） | 事件表或复用 WS + REST 列表 | 铃铛/列表、已读、深链跳转 | **tracked**：已新增 `app_notification`、`GET /api/v1/settings/notifications`、`POST /api/v1/settings/notifications/mark-read`、`POST /api/v1/settings/notifications/mark-all-read`，并接入 WS `settings.notification.created` / `settings.notification.updated`；当前生产者覆盖 skills 变更、jobs 终态、workspace invite 生命周期，Flutter 主导航已补「通知中心」pane 与未读计数 |
| P-A2 | **全局搜索**（跨项目标题、剧本、资产元数据） | 搜索 API + 索引策略（PG `tsvector` 或外包） | 统一搜索框、结果分组 | **tracked**：现有 `/api/v1/search` 已覆盖 project / script / asset / novel / novel_event 全文搜索、结果分组、历史记录与高级筛选；Flutter 搜索结果页现补齐结果类型 header chips、可复制 `/product/search?q=...&type=...&timeFrom=...&timeTo=...` 深链、从深链恢复 type/time filter，以及基于本机 `SharedPreferences` 的保存视图 / 视图回放；保存视图现已带最近使用排序、`useCount` / `lastUsedAt` 展示、同名覆盖更新、workspace-aware 默认命名，以及近 7 天 / 项目近 30 天 / 剧本近 30 天 / 资产近 30 天模板；搜索栏聚焦下拉现已分层展示 **固定视图 / 最近常用视图 / 快捷模板 / 最近搜索 / 实时建议**，并按当前 workspace 优先排序 pinned/recent 视图，同时支持在入口直接 **重命名 / 固定或取消固定 / 删除** 视图，并按 workspace 打二级分组，权限继续按 workspace 生效 |
| P-A3 | **账户：导出数据 / 删除账号**（合规） | 异步导出 job + 下载链接；删号 CASCADE 策略 | 设置页危险操作 + 二次确认 | **tracked**：已新增 `POST /api/v1/settings/account/export`、`GET /api/v1/settings/account/exports`、`GET /api/v1/settings/account/exports/{job_id}/file`、`POST /api/v1/settings/account/delete`；账户导出复用 `app_generation_job` 生成 zip，当前覆盖 profile / workspace / project / script / storyboard / asset / novel / jobs / usage / memory / vendor credential metadata / notification 等用户域数据，并在 Flutter 主导航补齐「账户」pane、导出历史、下载到本机与强确认删号 |
| P-A4 | **功能开关 / 远程配置**（按 plan 或 workspace） | 配置 API + 缓存 | 客户端拉取与 UI 灰显 | **tracked**：已新增 `GET/POST /api/v1/settings/platform-config` 与 Flutter「平台配置」产品面；当前 `effective` 已按 `defaults <- plan override <- current workspace override <- user override` 合成，其中 plan override 来自 `TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON`，workspace override 复用 `app_workspace.metadata.platform_config`，并支持 `has*Override` / `reset=true` 的显式继承回退；运维配置约定见 [`platform-config-plan-overrides.md`](./platform-config-plan-overrides.md) |

---

## B. 集成与自动化（「平台」对外接口）

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-B1 | **用户级或 workspace 级 API Key**（只读/读写 scope） | 签发、哈希存储、轮换、审计 | 设置页管理 keys、展示一次明文 | **tracked**：本轮先落 **用户级** API key（`tfk_*`），新增 `app_api_key` / `app_api_key_audit`、`GET /api/v1/settings/api-keys`、`GET /api/v1/settings/api-keys/audit`、`POST /api/v1/settings/api-keys`、`POST /{id}/rotate|revoke|activate`、`DELETE /{id}`；secret 仅创建/轮换时回显一次，服务端以 HMAC 哈希保存，并把 `last_used_*` / `use_count` 与生命周期审计落库；认证链已支持 `X-API-Key` 用于用户域 REST 自动化，`read_only` key 仅允许 `GET/HEAD/OPTIONS`，速率限制按 `public_id` 分桶；轮换现保持 `public_id` 稳定、支持 `expiresAtAction = preserve|clear|set`，列表直接返回 `isExpired` / `isUsable`；Flutter 主导航已补「API 密钥」pane，覆盖创建、一次性明文复制、过期策略、轮换、撤销/恢复、删除与审计查看 |
| P-B2 | **出站 Webhook**（项目状态、任务完成 → 客户 URL） | 注册 URL、签名校验、重试、死信 | 配置 UI + 测试投递按钮 | **tracked**：Flutter [`帮助 / 出站 Webhook`](../../frontend/lib/shell/build_sections_product.dart) 已补平台级治理面，覆盖 settings CRUD、可选自定义 secret、可配置 test `eventType`、列表搜索、最近创建凭据回显、删除确认、最近测试结果与本地操作活动流；并复用 `GET /api/v1/webhooks/billing/events` 补齐 billing webhook 审计筛选 / 摘要 / 导出 / drilldown |
| P-B3 | **公开只读 Status / Health 页**（非鉴权或弱鉴权） | 聚合 `/health`、队列深度、依赖项 | 静态页或 Flutter Web 路由 | **tracked**：已新增 Flutter `/status` 页，公开聚合 `/health` / `/api/v1/health` / `/api/v1/ready` / `/api/v1/version`，并在带 `INTERNAL_OPS_TOKEN` 时附加队列统计；见 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) WP-E |

---

## C. 运营与治理

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-C1 | **管理台扩展**（超越 billing events 列表） | 用户/空间只读、封禁、配额调整 API | 内部路由或独立 build | **tracked / 当前能力族已收口**：**用户 / workspace / project 治理可写**（含归档、内部备注、workspace context 修复、成员 remediation、ownership remediation），并继续补齐 **ACL 读模型 + 批量治理视图**。统一复用 `TOONFLOW_INTERNAL_OPS_TOKEN` / `X-Toonflow-Internal-Token` 门禁，已落 `GET /api/v1/internal/admin/search`、用户与 workspace、project 详情 GET，以及 `POST .../users/{id}/governance`、`POST .../users/{id}/workspace-context`、`POST .../workspaces/{id}/governance`、`POST .../workspaces/{id}/members/remediation`、`POST .../workspaces/{id}/owner-transfer`、`POST .../projects/{id}/governance`、`POST .../projects/batch-governance`、`POST .../projects/{id}/owner-transfer`。用户侧：`app_user_profile` + `app_user_governance_audit`；workspace 侧：`app_workspace.archived_at`、`metadata.internalOps`、`app_workspace_governance_audit`（个人 workspace 禁止归档，internal ops 可直接补成员/改角色/移除成员，移除时自动回退 `current_workspace_id` 并清理该 workspace 下残留的 `app_project_member` ACL，也可直接修复 owner，目标成员升为 owner、原 owner 自动降为 admin，并返回 project ACL 摘要 / role breakdown 便于批量治理）；project 侧：`app_project.archived_at`、`metadata.internalOps`、`app_project_governance_audit`（当前 project governance 本身仍是归档 + 内部备注；owner remediation 通过独立 `owner-transfer` 入口完成，目标用户必须已是所属 workspace 成员，若项目已启用 ACL 且旧 owner 仍为普通 member，则自动补 `editor` 访问以保留协作连续性，同时详情直接返回显式 ACL 成员与 workspace 候选成员）。Flutter「管理台」已挂到 Ops and debug 壳层，支持上述写入、ACL 摘要与批量治理查看 |
| P-C2 | **内容与合规队列**（举报、人工审核） | 表 + 工作流 API | 审核台 UI | **tracked**：新增 `app_content_compliance_report`、`app_content_compliance_audit` 与 `POST /api/v1/content/reports`、`GET /api/v1/internal/compliance/reports`、`GET /api/v1/internal/compliance/reports/{id}/audit`、`POST /api/v1/internal/compliance/reports/{id}/claim`、`POST /api/v1/internal/compliance/reports/{id}/resolve`、`POST /api/v1/internal/compliance/reports/batch-mutate`；用户可按 `project|script|storyboard|asset|novel|user` 提交举报，服务端自动解析关联 `workspace_id` / `project_id` 并校验 workspace membership；internal ops 侧按 `pending -> claimed -> resolved|dismissed` 状态机处理，resolve 已支持 `none|archive_project|suspend_user` disposition 模板，并把 `reported / claimed / resolved|dismissed / disposition_applied` 写入不可变 audit 时间线；`GET /api/v1/internal/compliance/reports` 现同步返回 SLA 摘要与 workspace 热点汇总，Flutter `ContentComplianceSection` 作为独立 pane 已补举报入口、审核队列摘要、workspace 维度热点筛选、批量 claim/resolve/dismiss、target/report UUID 复制、audit 时间线弹窗，以及跳回项目详情 / 管理台上下文的联动入口 |
| P-C3 | **审计日志用户可见切片**（「谁改了我的项目」） | 读模型 API | 项目设置 / 活动时间线 | **tracked**：已新增 `app_project_audit` 与 `GET /api/v1/projects/{project_id}/audit`，当前覆盖项目创建 / 基础信息修改 / 删除，以及项目 ACL `viewer` / `editor` 增删改；Flutter 项目编辑器已补 [`ProjectAuditPanel`](../../frontend/lib/project_editor/project_audit_panel.dart) 活动时间线，支持动作过滤、搜索、分页追加与刷新 |

---

## D. 体验与国际化

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-D1 | **产品文案 i18n 收口**（中英至少） | 错误码 `message` 多语言可选 | `l10n` 全覆盖主路径 | 与 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) 联动 |
| P-D2 | **应用内帮助 / 文档 Hub** | 深链或 CDN 文档 URL 配置 | 帮助抽屉、外链 WebView | **tracked**：Flutter [`帮助`](../../frontend/lib/shell/build_sections_product.dart) 已从最小平铺链接扩到可检索知识入口，覆盖 env 驱动 links + settings endpoint、title/id/url 搜索、分类摘要、空态提示，以及单链接 / 标题+链接 handoff 复制 |
| P-D3 | **429 / 配额耗尽统一 UX** | 统一 `code` + `Retry-After` | 全局拦截器 + Snackbar/对话框 | **tracked**：已接入共享 `rust_api_feedback` 处理层与 Projects / Jobs / Task Center / Team Workspaces / System Probes 主路径；见 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) WP-D |

---

## E. 纳入主计划的提示

将上表某行 **排入迭代** 时：

1. 在对应 **`roadmap-*`** 或 **`workspace-team-full-plan`** 增加 WP 或子节；  
2. 本表该行列状态改为 **`tracked`** 并写上 **文档锚点**；  
3. 合并仍须满足 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

---

*审阅节奏：每季度扫一遍本表与 `harness-rust-flutter` 正文 §，补漏不重复造轮子。*
