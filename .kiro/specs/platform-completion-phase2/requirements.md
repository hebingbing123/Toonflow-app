# Requirements Document

## Introduction

本规格定义 Toonflow 平台 Phase 2 完成工作的需求，目标是完成平台剩余关键能力，包括 Workspace 功能完善、HTTP API 收敛、以及平台能力补遗（全局搜索服务端保存视图、出站 Webhook、内容合规分阶段通知、i18n 收口、帮助文档完善）。

本规格与 [`workspace-team-full-plan.md`](../../../docs/plans/workspace-team-full-plan.md)、[`platform-capabilities-backlog.md`](../../../docs/plans/platform-capabilities-backlog.md)、[`full-stack-delivery-covenant.md`](../../../docs/plans/full-stack-delivery-covenant.md) 保持一致，遵循全栈交付约定（backend + frontend + OpenAPI 同一里程碑），所有变更必须通过 `yarn refactor:check`。

**验收路径说明**：部分需求条目的 REST 路径或表名在落地时已有等价替换（例如保存视图、帮助 Hub）；以 **`tasks.md` 顶部「与实现对齐」** 与 **`design.md` 真源锚点** 为准做验收映射，避免重复实现两套 API。

## Glossary

- **Workspace**: 工作空间，包括 `personal`（个人）和 `enterprise`（企业）两种类型
- **Workspace_Member**: 工作空间成员，角色包括 `owner`、`admin`、`member`
- **Project**: 项目，归属于某个 Workspace
- **RLS**: Row Level Security，Supabase 行级安全策略
- **HTTP_API**: REST API 端点
- **OpenAPI**: API 规范文档
- **Flutter**: 前端框架
- **Rust_Backend**: 后端服务
- **Saved_View**: 保存的搜索视图
- **Webhook**: 出站 Webhook，用于事件通知
- **Compliance_Report**: 内容合规举报
- **i18n**: 国际化（Internationalization）
- **Help_Hub**: 应用内帮助文档中心
- **ACL**: Access Control List，访问控制列表
- **Parity**: 新旧栈功能对等性

## Requirements

### Requirement 1: Workspace 功能完善

**User Story:** 作为平台开发者，我希望完成 Workspace 剩余关键工作，以便团队协作功能达到可对外承诺的完整状态。

#### Acceptance Criteria

1. WHEN W4.4-W4.7 任务执行时，THE System SHALL 统一所有 `project_id` 路径的 workspace 成员权限校验
2. WHEN W4.4 执行时，THE System SHALL 确保剧本/分镜/小说/资产/workbench 所有 handler 按「project ∈ workspace + 成员权限」校验
3. WHEN W4.5 执行时，THE System SHALL 确保 jobs workspace 可见性按 payload 中 `project_uuid` + `project_numeric_id` 派生
4. WHEN W4.6 执行时，THE System SHALL 在 usage/skills/memory/quality 端点响应中显式标注 `scope = user`
5. WHEN W4.7 执行时，THE System SHALL 在 `electron-node-parity.md` 中补充多用户可见范围差异说明
6. WHEN W5.5 执行时，THE System SHALL 补齐 workspace 角色矩阵单元测试覆盖（最后一个 owner、降级 admin 等边角场景）
7. WHEN W9.2 执行时，THE System SHALL 完成 RLS 与 Rust 应用层一致性测试矩阵验证

### Requirement 2: HTTP API 收敛

**User Story:** 作为平台开发者，我希望完成 HTTP API 收敛工作，以便清理遗留 API 并统一接口规范。

#### Acceptance Criteria

1. WHEN H5 C4+ 批次执行时，THE System SHALL 完成 C4 及后续 C 批次的 API 清理
2. WHEN H5 D 批次执行时，THE System SHALL 完成 D 批次的 API 收敛
3. WHEN API 清理执行时，THE System SHALL 确保所有变更通过 `yarn refactor:check`
4. WHEN API 变更时，THE System SHALL 同步更新 OpenAPI 文档
5. WHEN 遗留 API 清理时，THE System SHALL 确保不破坏 personal workspace 和单用户路径

### Requirement 3: 全局搜索服务端保存视图与跨端同步

**User Story:** 作为用户，我希望在服务端保存搜索视图并跨设备同步，以便在不同客户端使用相同的搜索配置。

#### Acceptance Criteria

1. WHEN 用户保存搜索视图时，THE Backend SHALL 将视图配置持久化到 `app_saved_search_view` 表
2. WHEN 用户在不同设备登录时，THE Backend SHALL 返回该用户的所有保存视图
3. WHEN 用户修改保存视图时，THE Backend SHALL 更新视图配置并同步到所有客户端
4. WHEN 用户删除保存视图时，THE Backend SHALL 从数据库删除该视图
5. WHEN 保存视图包含 workspace 上下文时，THE Backend SHALL 按 workspace 成员权限过滤可见性
6. THE Backend SHALL 提供 `GET /api/v1/search/views` 端点列出用户的保存视图
7. THE Backend SHALL 提供 `POST /api/v1/search/views` 端点创建保存视图
8. THE Backend SHALL 提供 `PATCH /api/v1/search/views/{id}` 端点更新保存视图
9. THE Backend SHALL 提供 `DELETE /api/v1/search/views/{id}` 端点删除保存视图
10. THE Flutter_Client SHALL 在搜索界面展示服务端保存的视图列表
11. THE Flutter_Client SHALL 支持从保存视图快速恢复搜索条件
12. FOR ALL 保存视图操作，THE System SHALL 记录审计日志（创建/修改/删除时间、操作者）

### Requirement 4: 出站 Webhook 完整实现

**User Story:** 作为用户，我希望配置出站 Webhook 接收平台事件通知，以便集成到外部系统。

#### Acceptance Criteria

1. WHEN 用户配置 Webhook 时，THE Backend SHALL 验证目标 URL 的可达性
2. WHEN 平台事件触发时，THE Backend SHALL 向配置的 Webhook URL 发送 HTTP POST 请求
3. WHEN Webhook 投递失败时，THE Backend SHALL 按指数退避策略重试（最多 3 次）
4. WHEN Webhook 投递失败超过重试次数时，THE Backend SHALL 将事件记录到死信队列
5. WHEN 用户查看 Webhook 投递历史时，THE Backend SHALL 返回最近投递记录（成功/失败状态、响应码、重试次数）
6. THE Backend SHALL 为每个 Webhook 请求生成 HMAC 签名（使用用户配置的 secret）
7. THE Backend SHALL 在 Webhook 请求头中包含 `X-Toonflow-Signature` 签名
8. THE Backend SHALL 在 Webhook 请求头中包含 `X-Toonflow-Event-Type` 事件类型
9. THE Backend SHALL 支持以下事件类型：`job.completed`、`job.failed`、`project.created`、`workspace.member.added`
10. THE Flutter_Client SHALL 提供 Webhook 配置界面（URL、secret、事件类型选择）
11. THE Flutter_Client SHALL 提供 Webhook 测试按钮（发送测试事件）
12. THE Flutter_Client SHALL 展示 Webhook 投递历史和失败详情
13. FOR ALL Webhook 配置，THE System SHALL 记录审计日志

### Requirement 5: 内容合规分阶段通知

**User Story:** 作为运营人员，我希望按合规队列升级阶段接收通知，以便及时处理高优先级举报。

#### Acceptance Criteria

1. WHEN 合规举报进入 `over_capacity` 阶段时，THE Backend SHALL 生成 `content_compliance_alert` 通知
2. WHEN 合规举报进入 `stalled_claimed` 阶段时，THE Backend SHALL 生成 `content_compliance_alert` 通知
3. WHEN 合规举报进入 `escalated_72h` 阶段时，THE Backend SHALL 生成 `content_compliance_alert` 通知
4. WHEN 生成合规告警通知时，THE Backend SHALL 通过 WebSocket `settings.notification.created` 推送到通知中心
5. WHEN 用户点击合规告警通知时，THE Flutter_Client SHALL 跳转到 `/product/content-compliance?escalationStage=...` 并自动套用对应筛选
6. THE Backend SHALL 提供 `POST /api/v1/settings/notifications/content-compliance/sync` 端点同步当前队列告警到通知表
7. THE Flutter_Client SHALL 在合规队列刷新后自动调用同步接口
8. THE Flutter_Client SHALL 在通知中心支持按"合规"类型过滤
9. WHEN 合规告警已处理时，THE Backend SHALL 自动标记对应通知为已读
10. FOR ALL 合规告警通知，THE System SHALL 包含升级阶段、举报数量、workspace 热点等摘要信息

### Requirement 6: i18n 产品文案中英收口

**User Story:** 作为国际用户，我希望平台支持中英文切换，以便使用母语操作平台。

#### Acceptance Criteria

1. WHEN 用户切换语言时，THE Flutter_Client SHALL 更新所有界面文案为目标语言
2. THE Flutter_Client SHALL 使用 `l10n` 框架管理所有用户可见文案
3. THE Flutter_Client SHALL 覆盖主路径所有界面的中英文文案（项目列表、工作台、设置、团队工作区、通知中心）
4. THE Backend SHALL 在错误响应中支持 `Accept-Language` 头返回对应语言的错误消息
5. THE Backend SHALL 为所有错误码提供中英文 `message`
6. WHEN 用户首次登录时，THE System SHALL 根据浏览器语言或系统语言自动选择界面语言
7. WHEN 用户显式设置语言偏好时，THE System SHALL 持久化该偏好到用户配置
8. THE Flutter_Client SHALL 在设置页面提供语言切换选项（中文/English）
9. FOR ALL 新增功能，THE System SHALL 同步提供中英文文案
10. THE System SHALL 确保所有用户可见的日期、时间、数字格式按目标语言本地化

### Requirement 7: 帮助文档应用内 Hub 完善

**User Story:** 作为用户，我希望在应用内快速查找帮助文档，以便解决使用问题。

#### Acceptance Criteria

1. WHEN 用户打开帮助中心时，THE Flutter_Client SHALL 展示文档分类列表（入门指南、功能说明、API 文档、常见问题）
2. WHEN 用户搜索帮助内容时，THE Flutter_Client SHALL 按标题、关键词、URL 匹配并高亮结果
3. WHEN 用户点击帮助链接时，THE Flutter_Client SHALL 在应用内 WebView 或外部浏览器打开文档
4. THE Backend SHALL 提供 `GET /api/v1/settings/help-links` 端点返回帮助文档配置
5. THE Backend SHALL 支持通过环境变量 `TOONFLOW_HELP_LINKS_JSON` 配置帮助链接
6. THE Flutter_Client SHALL 支持复制单个链接或"标题+链接"组合
7. THE Flutter_Client SHALL 在空态时展示"暂无帮助文档"提示
8. THE Flutter_Client SHALL 展示每个分类的文档数量摘要
9. WHEN 帮助链接配置更新时，THE Flutter_Client SHALL 自动刷新帮助中心内容
10. THE Flutter_Client SHALL 支持按分类筛选帮助文档

### Requirement 8: 全栈交付约定遵守

**User Story:** 作为平台开发者，我希望所有功能遵循全栈交付约定，以便确保前后端同步上线。

#### Acceptance Criteria

1. WHEN 实现用户可见功能时，THE System SHALL 在同一里程碑交付 backend + frontend + OpenAPI 文档
2. WHEN 提交代码变更时，THE System SHALL 通过 `yarn refactor:check` 验证
3. WHEN 修改 OpenAPI 时，THE System SHALL 同步更新 `rust_api` 客户端代码
4. WHEN 修改 WebSocket 协议时，THE System SHALL 同步更新 `docs/websocket-events.md`
5. WHEN 实现 ops-only 功能时，THE System SHALL 在任务文档中显式标注 `(ops-only)` 并说明原因
6. THE System SHALL 确保所有 API 变更不破坏 personal workspace 和单用户路径
7. THE System SHALL 确保所有数据库迁移向后兼容
8. WHEN 功能分多个 PR 实现时，THE System SHALL 确保最后一笔 PR 合并时已满足全栈交付要求
9. WHEN 功能延期超过 1 个发布周期时，THE System SHALL 在 `toonflow-platform-progress.md` 标记为 debt 并记录目标日期
10. FOR ALL 平台级功能，THE System SHALL 确保可发现性（设置可配）、可观测（错误码可读）、可运营（管理视图）

### Requirement 9: Personal Workspace 和单用户路径保护

**User Story:** 作为现有用户，我希望平台升级不影响我的个人工作区和项目，以便继续使用现有功能。

#### Acceptance Criteria

1. WHEN 实现 workspace 功能时，THE System SHALL 保持 `personal` workspace 的唯一性
2. WHEN 用户首次登录时，THE System SHALL 自动创建 personal workspace（`ensure_personal_workspace`）
3. WHEN 用户切换 workspace 时，THE System SHALL 确保 personal workspace 始终可访问
4. WHEN 实现成员权限时，THE System SHALL 确保 personal workspace 的项目仅所有者可见
5. WHEN 用户离开 enterprise workspace 时，THE System SHALL 自动回退到 personal workspace
6. THE System SHALL 禁止删除或归档 personal workspace
7. THE System SHALL 禁止用户离开自己的 personal workspace
8. THE System SHALL 确保现有项目的 `workspace_id` 正确指向所有者的 personal workspace
9. WHEN 实现新功能时，THE System SHALL 确保单用户路径（无团队协作）的用户体验不受影响
10. FOR ALL workspace 相关变更，THE System SHALL 通过回归测试验证 personal workspace 功能完整性

### Requirement 10: RLS 与 Rust 应用层一致性

**User Story:** 作为平台开发者，我希望 RLS 策略与 Rust 应用层权限校验保持一致，以便确保数据安全。

#### Acceptance Criteria

1. WHEN 执行 W9.2 验证时，THE System SHALL 运行 `scripts/workspace_rls_probe_and_summarize.sh` 生成一致性报告
2. WHEN 验证 RLS 策略时，THE System SHALL 测试 owner/member/outsider 三种身份的数据可见性
3. WHEN 验证结果为 `partial_match` 或 `expected_mismatch` 时，THE System SHALL 在文档中说明差异原因
4. WHEN 验证结果为 `review_needed` 或 `security_bug` 时，THE System SHALL 阻止发布并要求修复
5. THE System SHALL 生成 `summary.md`、`summary.json`、`assertion.json`、`checklist-snippet.md`、`artifact-manifest.json` 验证产物
6. THE System SHALL 在 `workspace-rls-consistency-matrix.md` 中记录 Rust 与 RLS 的主要差异
7. THE System SHALL 在 `workspace-security-boundary.md` 中明确应用层授权为真源、RLS 为补充护栏
8. WHEN Rust 使用 service role 绕过 RLS 时，THE System SHALL 在应用层 100% 复现成员规则
9. THE System SHALL 确保 workspace/project/jobs/Harness 链路显式复用门禁 helper
10. FOR ALL RLS 策略变更，THE System SHALL 重新运行一致性验证并更新文档

### Requirement 11: Workspace 角色矩阵单元测试

**User Story:** 作为平台开发者，我希望通过单元测试覆盖 workspace 角色矩阵边角场景，以便确保权限逻辑正确。

#### Acceptance Criteria

1. WHEN 测试 owner 角色时，THE System SHALL 验证 owner 可执行所有权限动作（邀请成员、管理成员、管理计费、删除空间、删除任意项目）
2. WHEN 测试 admin 角色时，THE System SHALL 验证 admin 可邀请成员、管理成员、删除任意项目，但不可管理计费或删除空间
3. WHEN 测试 member 角色时，THE System SHALL 验证 member 可创建项目，但不可邀请成员、管理成员、删除他人项目
4. WHEN 测试最后一个 owner 时，THE System SHALL 验证最后一个 owner 不可被降级或移除
5. WHEN 测试 owner 降级时，THE System SHALL 验证至少保留一个 owner 后才允许降级
6. WHEN 测试成员移除时，THE System SHALL 验证移除后该成员的 `current_workspace_id` 自动回退到 personal
7. WHEN 测试 workspace 归档时，THE System SHALL 验证归档后所有成员的 `current_workspace_id` 若指向该 workspace 则自动回退
8. THE System SHALL 在 `backend/src/workspaces/http.rs` 中补充 `workspace_role_matrix_owner_admin_member` 测试
9. THE System SHALL 在 `backend/src/workspaces/http.rs` 中补充 `last_owner_transition_guard_matches_policy` 测试
10. FOR ALL 角色矩阵测试，THE System SHALL 确保测试覆盖与 `workspace-project-permission-policy.md` 文档一致

### Requirement 12: HTTP API C4+ 和 D 批次收敛

**User Story:** 作为平台开发者，我希望完成 HTTP API C4+ 和 D 批次的收敛工作，以便清理遗留接口。

#### Acceptance Criteria

1. WHEN 执行 C4 批次时，THE System SHALL 按 `tasks-http-api-cleanup.md` 中的 C4 清单清理对应 API
2. WHEN 执行 C5+ 批次时，THE System SHALL 按 `tasks-http-api-cleanup.md` 中的 C5+ 清单清理对应 API
3. WHEN 执行 D 批次时，THE System SHALL 按 `tasks-http-api-cleanup.md` 中的 D 清单清理对应 API
4. WHEN 清理 API 时，THE System SHALL 确保前端已迁移到新接口
5. WHEN 清理 API 时，THE System SHALL 更新 OpenAPI 文档移除废弃端点
6. WHEN 清理 API 时，THE System SHALL 在 `http-api-cleanup-h0-inventory.md` 中标记为已完成
7. THE System SHALL 确保所有 API 清理通过 `yarn refactor:check`
8. THE System SHALL 确保所有 API 清理不破坏现有集成测试
9. WHEN API 清理涉及数据库表时，THE System SHALL 评估是否需要数据迁移
10. FOR ALL API 清理，THE System SHALL 在 `toonflow-platform-progress.md` 中更新进度

### Requirement 13: Workspace 项目路径成员权限统一

**User Story:** 作为团队成员，我希望在 workspace 内访问项目相关资源时权限一致，以便顺畅协作。

#### Acceptance Criteria

1. WHEN 访问剧本资源时，THE System SHALL 按 workspace 成员权限校验（而非仅 owner）
2. WHEN 访问分镜资源时，THE System SHALL 按 workspace 成员权限校验
3. WHEN 访问小说资源时，THE System SHALL 按 workspace 成员权限校验
4. WHEN 访问资产资源时，THE System SHALL 按 workspace 成员权限校验
5. WHEN 访问 workbench 资源时，THE System SHALL 按 workspace 成员权限校验
6. THE System SHALL 抽取 `require_project_workspace_member_scope` 等 helper 函数统一权限校验逻辑
7. THE System SHALL 确保生产/质量/发布/脚本/小说等后续批次已按成员可见性收敛
8. WHEN 项目启用 ACL 时，THE System SHALL 进一步按 `viewer`/`editor` 角色细化权限
9. WHEN 成员无权限访问资源时，THE System SHALL 返回 `403 Forbidden` 错误
10. FOR ALL 项目路径 handler，THE System SHALL 确保权限校验逻辑与 `workspace-project-permission-policy.md` 一致

### Requirement 14: Jobs Workspace 可见性

**User Story:** 作为团队成员，我希望看到 workspace 内项目相关的任务，以便了解团队工作进度。

#### Acceptance Criteria

1. WHEN 查询 jobs 列表时，THE System SHALL 按 payload 中 `project_uuid` + `project_numeric_id` 派生 workspace 可见性
2. WHEN job payload 不包含 project 信息时，THE System SHALL 按 `owner_user_id` 个人视图过滤
3. WHEN job payload 包含 project 信息时，THE System SHALL 按「owner 或同 workspace 成员」判定读写权限
4. THE System SHALL 确保 `GET /api/v1/jobs/page`、`GET /api/v1/jobs`、jobs summary 端点按 workspace 可见性过滤
5. THE System SHALL 确保 jobs 详情/取消/重试链路按 workspace 成员权限校验
6. THE System SHALL 在 `POST /api/v1/jobs` 时对 payload 中的 project 字段做成员校验并规范化 `project_uuid`/`project_numeric_id`
7. THE System SHALL 确保 worker 侧 `video/voiceover/asset-image` 的项目写回查询按 workspace 成员校验
8. THE System SHALL 确保本地 artifact 下载目录与更新通知按 `job.owner_user_id` 对齐
9. WHEN job 关联的 project 被归档或删除时，THE System SHALL 仍允许 owner 查看该 job
10. FOR ALL jobs 可见性逻辑，THE System SHALL 确保与 W4.5 决策定稿一致（不新增 `workspace_id` 列，由 project 派生）

### Requirement 15: Usage/Skills/Memory/Quality Scope 标注

**User Story:** 作为用户，我希望明确了解 usage/skills/memory/quality 统计的范围，以便理解数据口径。

#### Acceptance Criteria

1. WHEN 调用 `GET /api/v1/usage/summary` 时，THE Backend SHALL 在响应中包含 `scope: "user"` 字段
2. WHEN 调用 `GET /api/v1/skills/summary` 时，THE Backend SHALL 在响应中包含 `scope: "user"` 字段
3. WHEN 调用 `GET /api/v1/agents/memory/cost-overview` 时，THE Backend SHALL 在响应中包含 `scope: "user"` 字段
4. WHEN 调用 `POST /api/v1/agents/memory/query` 时，THE Backend SHALL 在 `MemoryHistoryItem` 中包含 `scope: "user"` 字段
5. WHEN 调用 quality 聚合端点时，THE Backend SHALL 在响应中包含 `scope: "user"` 字段
6. THE System SHALL 在 OpenAPI 文档中为所有 scope 字段添加说明（当前为用户级聚合，workspace 级汇总待产品定稿）
7. THE Flutter_Client SHALL 在展示 usage/skills/memory/quality 数据时显示 scope 标识
8. WHEN 未来实现 workspace 级汇总时，THE System SHALL 通过 scope 字段区分用户级和 workspace 级数据
9. THE System SHALL 确保 scope 标注与 `workspace-billing-scope-decision.md` 中的用户级计费口径一致
10. FOR ALL scope 相关变更，THE System SHALL 更新 OpenAPI 文档和前端展示

### Requirement 16: Parity 文档补充

**User Story:** 作为平台开发者，我希望在 parity 文档中说明多用户可见范围差异，以便理解新旧栈行为差异。

#### Acceptance Criteria

1. WHEN 更新 parity 文档时，THE System SHALL 在 `electron-node-parity.md` §2.2 中补充「多用户可见范围」章节
2. THE Parity_Document SHALL 说明旧栈（Electron/Node）的项目可见性规则
3. THE Parity_Document SHALL 说明新栈（Rust/Flutter）的 workspace 成员可见性规则
4. THE Parity_Document SHALL 列出主要差异点（personal vs enterprise、owner-only vs member-visible）
5. THE Parity_Document SHALL 说明迁移路径（现有用户自动归属 personal workspace）
6. THE Parity_Document SHALL 说明向后兼容策略（personal workspace 行为与旧栈一致）
7. THE Parity_Document SHALL 说明 jobs 可见性差异（旧栈仅 owner、新栈支持 workspace 成员）
8. THE Parity_Document SHALL 说明资产/剧本/分镜可见性差异
9. THE Parity_Document SHALL 提供示例场景对比（单用户 vs 团队协作）
10. FOR ALL parity 差异，THE System SHALL 确保文档与实际实现一致

