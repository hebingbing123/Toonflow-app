# Requirements Document

## Introduction

本文档定义 Openflow 平台 Phase 1 最后两个竖切的需求:资产与生产竖切、质量与发布最小闭环竖切。这是从 Electron/Node 到 Rust+Flutter 架构重构的关键里程碑,完成后将具备完整的端到端制作流程。

**背景**: 当前已完成 Workspace 基础、项目立项、内容接入、改写与上游结构四个竖切。接下来需要补齐资产管理与生产工作台的完整闭环,以及质量评审与发布门禁机制。

**技术栈**:
- Backend: Rust (Axum, SQLx, Supabase PostgreSQL)
- Frontend: Flutter (Desktop + Web)
- API: REST `/api/v1/*` + WebSocket `/api/v1/ws`
- 验证: `cargo test` + `flutter test` + `flutter analyze` + `yarn refactor:check`

## Glossary

- **System**: Openflow 平台后端服务 (Rust)
- **Frontend**: Flutter 客户端 (Desktop + Web)
- **Asset_Manager**: 资产管理子系统
- **Production_Workbench**: 生产工作台子系统
- **Quality_Gate**: 质量门禁子系统
- **Vertical_Slice**: 前后端一并落地的可提交增量
- **Contract_Test**: 契约测试 (无 DB 烟雾测试 + PG 集成测试)
- **Refactor_Check**: 门禁脚本 `yarn refactor:check`

## Requirements

### Requirement 1: 资产工作台完整性

**User Story:** 作为制作人员,我希望在资产工作台中完成资产的全生命周期管理,以便高效组织和使用制作素材。

#### Acceptance Criteria

1. WHEN 用户打开资产工作台, THE Frontend SHALL 显示当前项目的资产列表摘要 (包含 role/scene/tool 分类统计)
2. WHEN 用户筛选资产类型或名称, THE System SHALL 返回符合条件的资产列表 (支持 `asset_type`/`name`/`script_legacy_id` 组合过滤)
3. WHEN 用户查看资产详情, THE Frontend SHALL 显示资产的历史图片列表 (包含 `state`/`numeric_image_id`/`file_path`)
4. WHEN 用户上传 Clip 资产, THE System SHALL 验证 base64 数据并入库到 `app_asset` (type=clip)
5. WHEN 用户关联资产到剧本, THE System SHALL 在 `app_script_asset` 中建立关联关系
6. WHEN 用户取消资产与剧本的关联, THE System SHALL 删除 `app_script_asset` 中的对应记录
7. FOR ALL 资产 CRUD 操作, THE System SHALL 验证用户对项目的归属权 (通过 `workspace_id` + RLS)

### Requirement 2: 资产出图工作流

**User Story:** 作为制作人员,我希望批量生成资产图片并轮询状态,以便快速完成素材制作。

#### Acceptance Criteria

1. WHEN 用户发起单个资产出图, THE System SHALL 创建 `asset.generate.image` 类型的 `app_generation_job` 并入队
2. WHEN 用户发起批量资产出图, THE System SHALL 创建 `asset.generate.batch` 类型的任务并入队
3. WHEN 用户发起 prompt 优化, THE System SHALL 创建 `asset.polish.prompt` 或 `asset.polish.batch` 类型的任务
4. WHEN 任务 worker 处理出图请求, THE System SHALL 调用配置的 LLM provider (OpenAI/compatible) 并将结果写入 `app_asset_image`
5. WHEN 用户轮询资产图片状态, THE System SHALL 返回当前 `state` (待生成/生成中/已完成/生成失败) 和可选的 `file_path`
6. WHEN 用户取消出图任务, THE System SHALL 将 queued/running 状态的任务标记为 cancelled 并更新 `app_asset_image.state` 为生成失败
7. IF 配置了 `OPENFLOW_LOCAL_ASSET_IMAGE_DIR`, THEN THE System SHALL 将生成的图片保存为本地 PNG 文件 (路径格式: `{user}/{image_id}.png`)
8. IF 未配置本地存储目录, THEN THE System SHALL 将 provider 返回的临时 URL 保存到 `file_path`
9. WHEN 用户访问 `GET /api/v1/projects/{project_id}/assets/{aid}/images/{id}/file`, THE System SHALL 返回图片内容 (本地文件返回 200 + image/png, https URL 返回 307 重定向)

### Requirement 3: 分镜工作台集成

**User Story:** 作为制作人员,我希望在分镜工作台中管理分镜图片和视频,以便完成完整的制作流程。

#### Acceptance Criteria

1. WHEN 用户打开分镜工作台, THE Frontend SHALL 显示当前剧本的分镜列表 (包含 `sb_index`/`name`/`prompt`)
2. WHEN 用户读取制作视图, THE System SHALL 返回 `get-flow-data` (包含 assets/scriptPlan/storyboardTable/storyboard 快照)
3. WHEN 用户保存制作视图, THE System SHALL 持久化 flow JSON 到 `app_agent_work_data` 并同步 `app_storyboard.sb_index`
4. WHEN 用户批量生成分镜图, THE System SHALL 调用 `generate_storyboard` 工具并更新对应分镜的预览图
5. WHEN 用户管理视频轨道, THE System SHALL 支持 add-track/delete-track 操作并更新 `app_storyboard_video_track`
6. WHEN 用户生成视频, THE System SHALL 创建 `storyboard.generate.video` 类型的任务并入队
7. WHEN 用户选择候选视频, THE System SHALL 更新 `app_storyboard` 的当前视频引用
8. WHEN 用户导出分镜 ZIP, THE System SHALL 收集所选分镜的图片并打包返回

### Requirement 4: Production Agent 域工具迁移

**User Story:** 作为系统,我需要将旧 Socket.IO 的 production 域工具迁移到 Harness WS,以便统一实时通信协议。

#### Acceptance Criteria

1. THE System SHALL 提供 `get_flowData` 工具 (读取 `app_agent_work_data` 并回填实时 script/assets/storyboard 快照)
2. THE System SHALL 提供 `add_deriveAsset` 工具 (添加衍生资产到 flow)
3. THE System SHALL 提供 `del_deriveAsset` 工具 (删除衍生资产)
4. THE System SHALL 提供 `generate_deriveAsset` 工具 (批量生成衍生资产图片)
5. THE System SHALL 提供 `generate_storyboard` 工具 (批量生成分镜图)
6. THE System SHALL 提供 `run_sub_agent_derive_assets` 编排工具 (运行衍生资产子代理)
7. THE System SHALL 提供 `run_sub_agent_generate_assets` 编排工具 (运行资产生成子代理)
8. THE System SHALL 提供 `run_sub_agent_director_plan` 编排工具 (运行导演计划子代理)
9. THE System SHALL 提供 `run_sub_agent_storyboard_gen` 编排工具 (运行分镜生成子代理)
10. THE System SHALL 提供 `run_sub_agent_storyboard_panel` 编排工具 (运行分镜面板子代理)
11. THE System SHALL 提供 `run_sub_agent_storyboard_table` 编排工具 (运行分镜表子代理)
12. FOR ALL production 域工具, THE System SHALL 通过 Harness WS 协议暴露 (而非 Socket.IO)

### Requirement 5: Frontend Production Workspace 完整性

**User Story:** 作为制作人员,我希望在 production workspace 中看到清晰的阶段看板和下一步建议,以便高效推进制作流程。

#### Acceptance Criteria

1. WHEN 用户打开 production workspace, THE Frontend SHALL 显示固定的阶段看板 (assets → scriptPlan → storyboardTable → storyboard)
2. WHEN 用户读取 `get_flowData`, THE Frontend SHALL 根据返回的快照自动生成下一步建议卡片
3. WHEN flow 中 assets 为空白, THE Frontend SHALL 建议"读取资产数据"或"切换到资产子代理"
4. WHEN flow 中 storyboard 待补图, THE Frontend SHALL 建议"批量生成分镜图"
5. WHEN 用户执行工具后, THE Frontend SHALL 自动刷新对应 flow key 并安全回写
6. WHEN 用户从 assets/storyboard 快照生成参数, THE Frontend SHALL 自动填充 `generate_deriveAsset`/`generate_storyboard` 的 `ids` 参数
7. WHEN 用户应用建议 key, THE Frontend SHALL 将快捷应用按钮的结果直接写回 flow

### Requirement 6: 质量评审工作台增强

**User Story:** 作为质量管理人员,我希望在质量评审工作台中筛选和统计评审数据,以便监控制作质量。

#### Acceptance Criteria

1. WHEN 用户打开质量评审工作台, THE Frontend SHALL 显示评审筛选面板 (支持 targetType/targetId/isBadCase 过滤)
2. WHEN 用户查看坏例, THE Frontend SHALL 显示 `isBadCase=true` 的评审列表
3. WHEN 用户查看统计, THE System SHALL 返回 `GET /api/v1/quality/stats` (总评审数/坏例数/通过率)
4. WHEN 用户查看阶段通过率, THE System SHALL 返回 `GET /api/v1/quality/stage-pass-rate` (按 stage 分组的通过率)
5. WHEN 用户查询评审详情, THE System SHALL 返回 `GET /api/v1/quality/reviews/{id}` (包含完整的评审元数据)
6. WHEN 用户手动创建评审, THE System SHALL 验证 `targetType`/`source`/`badCaseCategory` 枚举值并写入 `app_quality_review`

### Requirement 7: 发布门禁集成

**User Story:** 作为开发人员,我希望每次提交前自动运行完整的门禁检查,以便确保代码质量。

#### Acceptance Criteria

1. WHEN 开发人员修改 `backend/` 代码, THE System SHALL 在 commit 前运行 `cargo fmt --check` + `cargo clippy -D warnings` + `cargo test`
2. WHEN 开发人员修改 `frontend/` 代码, THE System SHALL 在 commit 前运行 `flutter pub get` + `flutter analyze` + `flutter test`
3. WHEN 开发人员修改 OpenAPI 相关文件, THE System SHALL 运行 `cargo run --bin export-openapi` 并验证 YAML 可解析
4. WHEN 开发人员修改 `supabase/migrations/`, THE System SHALL 验证迁移文件格式正确
5. WHEN 开发人员运行 `yarn refactor:check`, THE System SHALL 执行上述所有检查并返回统一的成功/失败状态
6. IF 任何检查失败, THEN THE System SHALL 输出清晰的错误信息并阻止提交

### Requirement 8: 既有 Analyzer 告警清理

**User Story:** 作为开发人员,我希望清理既有的 Flutter analyzer 告警,以便 `yarn refactor:check` 能够全绿通过。

#### Acceptance Criteria

1. THE System SHALL 修复 `frontend/lib/short_video_space/section_production.dart` 中的 analyzer 告警
2. THE System SHALL 修复 `frontend/lib/short_video_space/section_production_assembly.dart` 中的 analyzer 告警
3. THE System SHALL 修复 `frontend/lib/short_video_space/section_project.dart` 中的 analyzer 告警
4. THE System SHALL 修复 `frontend/lib/short_video_space/section_publish*.dart` 中的 analyzer 告警
5. WHEN 运行 `flutter analyze`, THE System SHALL 返回 0 个错误和 0 个警告

### Requirement 9: 契约测试覆盖

**User Story:** 作为开发人员,我希望为新增的 API 端点编写契约测试,以便确保接口行为符合预期。

#### Acceptance Criteria

1. THE System SHALL 为资产工作台 API 编写无 DB 烟雾测试 (验证 401/400/503 错误码)
2. THE System SHALL 为资产出图 API 编写 PG 集成测试 (验证完整的入队→worker→回写流程)
3. THE System SHALL 为分镜工作台 API 编写 PG 集成测试 (验证 flow 读写→分镜同步→视频生成流程)
4. THE System SHALL 为 production 域工具编写 Harness WS 测试 (验证工具调用→结果返回流程)
5. FOR ALL 新增的 REST 端点, THE System SHALL 在 OpenAPI 中补充完整的 schema 定义

### Requirement 10: 进度文档同步

**User Story:** 作为项目管理人员,我希望在每个竖切完成后更新进度文档,以便跟踪项目状态。

#### Acceptance Criteria

1. WHEN 资产与生产竖切完成, THE System SHALL 更新 `docs/plans/openflow-platform-progress.md` 中的状态为 `completed`
2. WHEN 质量与发布竖切完成, THE System SHALL 更新进度文档中的状态为 `completed`
3. WHEN 每个竖切完成, THE System SHALL 记录对应的 commit hash
4. WHEN 每个竖切完成, THE System SHALL 记录已验证的测试列表
5. WHEN Phase 1 全部完成, THE System SHALL 在进度文档中标记 Phase 1 状态为 `completed`

### Requirement 11: 与既有系统的集成

**User Story:** 作为系统,我需要与已完成的竖切保持一致性,以便形成完整的端到端流程。

#### Acceptance Criteria

1. THE Asset_Manager SHALL 复用既有的 `app_project`/`app_asset` schema (不引入新的数据库表)
2. THE Production_Workbench SHALL 复用既有的 `app_generation_job` 任务队列机制
3. THE Quality_Gate SHALL 复用既有的 `app_quality_review` 表和 REST API
4. THE Frontend SHALL 复用既有的 `rust_api` 生成代码 (通过 OpenAPI 自动生成)
5. THE System SHALL 遵循既有的鉴权机制 (Supabase JWT + RLS)
6. THE System SHALL 遵循既有的错误码约定 (401/400/404/503 等)
7. THE System SHALL 遵循既有的 API 版本前缀 (`/api/v1/*`)

### Requirement 12: 验证策略

**User Story:** 作为开发人员,我希望每个竖切都有明确的验证标准,以便确认功能正确性。

#### Acceptance Criteria

1. THE System SHALL 为每个竖切定义定向验证命令 (如 `cargo test <module>` + `flutter test <file>`)
2. THE System SHALL 在所有竖切完成后运行 `yarn refactor:check` 全量门禁
3. THE System SHALL 在每个竖切完成后执行 `git commit` (提交信息包含竖切名称和验证结果)
4. THE System SHALL 在进度文档中记录每个竖切的验证命令和结果
5. IF 定向验证失败, THEN THE System SHALL 修复问题后再提交
6. IF 全量门禁失败, THEN THE System SHALL 修复问题直到全绿

### Requirement 13: 成功标准

**User Story:** 作为项目管理人员,我希望明确 Phase 1 的完成标准,以便判断是否可以进入下一阶段。

#### Acceptance Criteria

1. THE System SHALL 完成资产与生产竖切 (包含资产工作台/出图工作流/分镜工作台/production 域工具)
2. THE System SHALL 完成质量与发布竖切 (包含质量评审工作台/发布门禁/analyzer 告警清理)
3. THE System SHALL 通过所有契约测试 (无 DB 烟雾测试 + PG 集成测试)
4. THE System SHALL 通过 `yarn refactor:check` 全量门禁
5. THE System SHALL 更新进度文档并记录所有 commit hash
6. THE Frontend SHALL 在 Desktop 和 Web 环境下均可正常运行
7. THE System SHALL 与既有的 4 个竖切形成完整的端到端流程 (Workspace → 项目立项 → 内容接入 → 改写 → 资产 → 生产 → 质量)

### Requirement 14: Parser 和 Serializer 要求

**User Story:** 作为系统,我需要确保所有数据解析和序列化逻辑都经过充分测试,以便避免数据损坏。

#### Acceptance Criteria

1. WHEN System 解析 flow JSON, THE System SHALL 使用 serde_json 并处理所有可能的错误情况
2. WHEN System 序列化 flow JSON, THE System SHALL 确保输出格式与输入格式一致
3. THE System SHALL 为 flow JSON 解析器编写 round-trip 测试 (parse → serialize → parse 结果等价)
4. THE System SHALL 为 OpenAPI YAML 解析器编写 round-trip 测试
5. IF 解析失败, THEN THE System SHALL 返回 400 错误并包含描述性错误信息

### Requirement 15: 配额与限流

**User Story:** 作为系统,我需要在资产出图和视频生成时检查用户配额,以便控制资源使用。

#### Acceptance Criteria

1. WHEN 用户发起出图任务, THE System SHALL 检查 `app_user_profile.plan_tier` 和当日任务数
2. IF 用户超出配额, THEN THE System SHALL 返回 429 错误并包含配额信息
3. WHEN 任务入队成功, THE System SHALL 增加 `app_usage_event` 记录
4. WHEN 用户查询用量, THE System SHALL 返回 `GET /api/v1/usage/summary` (包含近 7 天的事件统计)
5. THE System SHALL 在 worker 处理任务时再次验证配额 (防止并发竞争)

### Requirement 16: 可观测性

**User Story:** 作为运维人员,我希望在日志中看到清晰的请求追踪信息,以便排查问题。

#### Acceptance Criteria

1. WHEN 用户发起 API 请求, THE System SHALL 生成唯一的 `X-Request-Id` 并记录到日志
2. WHEN 发生错误, THE System SHALL 在响应 JSON 中包含 `request_id` 字段
3. WHEN 任务入队, THE System SHALL 记录任务 ID 和关联的 request ID
4. WHEN worker 处理任务, THE System SHALL 记录任务状态变更 (claimed → succeeded/failed)
5. THE System SHALL 在 Harness WS 事件中包含 session ID 和 tool invocation ID

### Requirement 17: 错误处理

**User Story:** 作为用户,我希望在操作失败时看到清晰的错误信息,以便知道如何修正。

#### Acceptance Criteria

1. WHEN 用户请求不存在的资源, THE System SHALL 返回 404 错误并包含资源类型和 ID
2. WHEN 用户提供无效的请求体, THE System SHALL 返回 400 错误并包含字段级别的验证信息
3. WHEN 数据库不可用, THE System SHALL 返回 503 错误并包含 `database_error` 错误码
4. WHEN LLM 未配置, THE System SHALL 返回 503 错误并包含 `llm_not_configured` 错误码
5. WHEN 用户无权访问资源, THE System SHALL 返回 403 错误并包含权限说明
6. FOR ALL 错误响应, THE System SHALL 使用统一的 JSON 格式 (`{ "error": { "code": "...", "message": "...", "request_id": "..." } }`)

### Requirement 18: 性能要求

**User Story:** 作为用户,我希望 API 响应速度快,以便流畅使用系统。

#### Acceptance Criteria

1. WHEN 用户查询资产列表 (≤100 条), THE System SHALL 在 500ms 内返回响应
2. WHEN 用户查询分镜列表 (≤50 条), THE System SHALL 在 300ms 内返回响应
3. WHEN 用户读取 flow 数据, THE System SHALL 在 1s 内返回响应 (包含实时快照回填)
4. WHEN 用户保存 flow 数据, THE System SHALL 在 2s 内完成持久化和索引同步
5. WHEN worker 处理出图任务, THE System SHALL 在 30s 内完成 (不包含 LLM 调用时间)
6. THE System SHALL 支持至少 10 个并发 worker 实例 (通过 `SKIP LOCKED` 实现)

### Requirement 19: 安全要求

**User Story:** 作为系统,我需要确保用户只能访问自己的数据,以便保护隐私。

#### Acceptance Criteria

1. THE System SHALL 在所有资产 API 中验证 `workspace_id` 归属
2. THE System SHALL 在所有项目 API 中验证 `workspace_id` 归属
3. THE System SHALL 使用 Supabase RLS 策略限制数据库访问
4. THE System SHALL 在 JWT 过期时返回 401 错误
5. THE System SHALL 在 JWT 签名无效时返回 401 错误
6. THE System SHALL 不在日志中记录敏感信息 (JWT token/密钥/用户密码)

### Requirement 20: 向后兼容性

**User Story:** 作为系统,我需要保持与既有 Flutter 代码的兼容性,以便平滑迁移。

#### Acceptance Criteria

1. THE System SHALL 保留 `postLegacy*` 兼容封装函数 (Dart 侧)
2. THE System SHALL 支持 `legacy_id` 和 UUID 两种 ID 格式
3. THE System SHALL 在响应中同时返回 `legacy_id` 和 `id` (UUID) 字段
4. THE System SHALL 支持旧的 `metadata` JSON 格式 (如 `assetsId`/`imageId`)
5. THE System SHALL 在迁移期间保留旧的探针入口 (在兼容性折叠区)
6. WHEN 旧 API 被调用, THE System SHALL 记录 deprecation 警告到日志

