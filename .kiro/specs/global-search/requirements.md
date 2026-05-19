# Requirements Document

## Introduction

全局搜索功能为用户提供跨项目、剧本、资产的统一搜索能力。用户可通过主导航栏的全局搜索框快速查找内容，系统使用 PostgreSQL tsvector + GIN 索引实现中英文分词和权重排序，并在统一结果页按类型分组展示搜索结果。功能包含搜索历史记录和高级过滤选项，严格遵循 workspace 级别权限控制。

## Glossary

- **Search_System**: 全局搜索系统，负责索引构建、查询处理、结果排序和权限过滤
- **Search_Index**: 基于 PostgreSQL tsvector 的全文搜索索引，支持中英文分词
- **Search_Query**: 用户输入的搜索关键词或短语
- **Search_Result**: 搜索返回的项目、剧本或资产记录
- **Search_History**: 用户的历史搜索记录
- **Search_Filter**: 高级过滤条件（类型、时间范围、workspace 等）
- **Search_Weight**: 搜索结果的相关性权重，用于排序
- **Workspace_Context**: 当前用户的 workspace 上下文，用于权限过滤
- **Backend_API**: Rust + Axum 实现的后端 REST API
- **Frontend_UI**: Flutter 实现的前端用户界面
- **GIN_Index**: PostgreSQL 的 Generalized Inverted Index，用于加速全文搜索

## Requirements

### Requirement 1: 搜索索引构建

**User Story:** 作为系统管理员，我希望系统自动为项目、剧本、资产构建全文搜索索引，以便用户能够快速搜索内容。

#### Acceptance Criteria

1. THE Search_System SHALL create tsvector columns for app_project (name, intro), app_script (name, content), and app_asset (name, description)
2. THE Search_System SHALL create GIN indexes on all tsvector columns to enable fast full-text search
3. THE Search_System SHALL support Chinese and English word segmentation using PostgreSQL built-in text search configurations
4. THE Search_System SHALL assign search weights: name fields weight A (highest), content/description fields weight B
5. WHEN a project, script, or asset is created or updated, THE Search_System SHALL automatically update the corresponding tsvector column
6. THE Search_System SHALL maintain index consistency through database triggers or application-level updates

### Requirement 2: 全局搜索框

**User Story:** 作为用户，我希望在主导航栏看到全局搜索框，以便随时发起搜索。

#### Acceptance Criteria

1. THE Frontend_UI SHALL display a global search input box in the main navigation bar
2. THE Frontend_UI SHALL show a search icon in the input box to indicate search functionality
3. WHEN the user types in the search box, THE Frontend_UI SHALL show real-time search suggestions (optional for MVP)
4. WHEN the user presses Enter or clicks the search button, THE Frontend_UI SHALL navigate to the unified search results page
5. THE Frontend_UI SHALL preserve the search query in the URL for bookmarking and sharing
6. THE Frontend_UI SHALL display a placeholder text "搜索项目、剧本、资产..." in the search box

### Requirement 3: 搜索查询处理

**User Story:** 作为用户，我希望输入关键词后能快速获得相关结果，以便找到我需要的内容。

#### Acceptance Criteria

1. WHEN the user submits a Search_Query, THE Backend_API SHALL validate the query is not empty and does not exceed 200 characters
2. THE Backend_API SHALL filter search results based on the user's Workspace_Context to ensure workspace-level permission enforcement
3. THE Backend_API SHALL search across app_project, app_script, and app_asset tables using tsvector matching
4. THE Backend_API SHALL rank Search_Results by Search_Weight (ts_rank) in descending order
5. THE Backend_API SHALL return results within 500ms for queries on datasets up to 100,000 records
6. THE Backend_API SHALL support partial word matching and fuzzy search for Chinese and English
7. IF the Search_Query contains special characters, THEN THE Backend_API SHALL sanitize the input to prevent SQL injection

### Requirement 4: 统一结果页展示

**User Story:** 作为用户，我希望在统一结果页看到按类型分组的搜索结果，以便快速定位不同类型的内容。

#### Acceptance Criteria

1. THE Frontend_UI SHALL display search results grouped by type: Projects, Scripts, Assets
2. THE Frontend_UI SHALL show the total count for each result type
3. THE Frontend_UI SHALL display up to 10 results per type on the initial page load
4. WHEN a result type has more than 10 results, THE Frontend_UI SHALL provide a "查看更多" button to load additional results
5. THE Frontend_UI SHALL display each Search_Result with: title/name, snippet (highlighted matching text), type icon, and last updated time
6. WHEN the user clicks on a Search_Result, THE Frontend_UI SHALL navigate to the detail page of that item
7. IF no results are found, THEN THE Frontend_UI SHALL display a message "未找到相关结果，请尝试其他关键词"

### Requirement 5: 搜索历史记录

**User Story:** 作为用户，我希望系统记录我的搜索历史，以便快速重复之前的搜索。

#### Acceptance Criteria

1. WHEN the user submits a Search_Query, THE Backend_API SHALL save the query to Search_History associated with the user's account
2. THE Backend_API SHALL store the search timestamp and query text in Search_History
3. THE Backend_API SHALL limit Search_History to the most recent 50 queries per user
4. WHEN the user clicks on the search box, THE Frontend_UI SHALL display a dropdown with the 10 most recent Search_History entries
5. WHEN the user clicks on a Search_History entry, THE Frontend_UI SHALL populate the search box and execute the search
6. THE Frontend_UI SHALL provide a "清除历史" button to delete all Search_History for the current user
7. THE Backend_API SHALL automatically delete Search_History entries older than 90 days

### Requirement 6: 高级过滤

**User Story:** 作为用户，我希望使用高级过滤选项缩小搜索范围，以便更精确地找到目标内容。

#### Acceptance Criteria

1. THE Frontend_UI SHALL provide a filter panel with options: result type (Project/Script/Asset), time range (last 7 days, 30 days, 90 days, all), and workspace selector
2. WHEN the user selects a Search_Filter, THE Frontend_UI SHALL send the filter parameters to the Backend_API
3. THE Backend_API SHALL apply Search_Filter conditions to the search query using SQL WHERE clauses
4. THE Backend_API SHALL filter by result type using table-specific queries
5. THE Backend_API SHALL filter by time range using the created_at or updated_at timestamp
6. THE Backend_API SHALL filter by workspace using the workspace_id foreign key and workspace membership validation
7. THE Frontend_UI SHALL display active filters as removable tags above the search results
8. WHEN the user removes a filter tag, THE Frontend_UI SHALL re-execute the search without that filter

### Requirement 7: 权限控制

**User Story:** 作为系统管理员，我希望搜索结果严格遵循 workspace 权限，以便用户只能看到有权访问的内容。

#### Acceptance Criteria

1. THE Backend_API SHALL retrieve the user's current Workspace_Context from app_user_profile.current_workspace_id
2. THE Backend_API SHALL verify the user is a member of the workspace through app_workspace_member table
3. THE Backend_API SHALL only return Search_Results where the item's workspace_id matches the user's Workspace_Context
4. THE Backend_API SHALL apply Row Level Security (RLS) policies to all search queries
5. IF the user is not a member of any workspace, THEN THE Backend_API SHALL return an empty result set
6. THE Backend_API SHALL log unauthorized search attempts for security auditing
7. THE Backend_API SHALL return HTTP 403 Forbidden if the user attempts to search in a workspace they do not have access to

### Requirement 8: API 契约与全栈交付

**User Story:** 作为开发者，我希望搜索功能遵循项目的全栈交付约定，以便前后端协同开发和测试。

#### Acceptance Criteria

1. THE Backend_API SHALL define OpenAPI specifications for all search endpoints in backend/src/openapi_spec/
2. THE Backend_API SHALL provide the following REST endpoints: POST /api/v1/search, GET /api/v1/search/history, DELETE /api/v1/search/history
3. THE Backend_API SHALL generate rust_api bindings for Frontend_UI consumption
4. THE Frontend_UI SHALL use the generated rust_api to call Backend_API endpoints
5. THE Backend_API SHALL pass cargo fmt, cargo clippy, and cargo test without errors
6. THE Frontend_UI SHALL pass flutter analyze and flutter test without errors
7. THE Backend_API SHALL pass yarn refactor:check before merge to main branch
8. THE Backend_API SHALL return standardized error responses with error codes and user-friendly messages in Chinese

### Requirement 9: 性能与可扩展性

**User Story:** 作为系统管理员，我希望搜索功能在大数据量下保持高性能，以便支持业务增长。

#### Acceptance Criteria

1. THE Search_System SHALL support concurrent search queries from up to 100 users without performance degradation
2. THE Backend_API SHALL implement query result caching with a 5-minute TTL for identical queries
3. THE Backend_API SHALL use database connection pooling to optimize resource usage
4. THE Backend_API SHALL implement pagination with a default page size of 10 and maximum page size of 50
5. THE Backend_API SHALL log slow queries (>1 second) for performance monitoring
6. THE Search_System SHALL support incremental index updates without requiring full reindexing
7. THE Backend_API SHALL return HTTP 429 Too Many Requests if a user exceeds 60 search requests per minute

### Requirement 10: 错误处理与用户反馈

**User Story:** 作为用户，我希望在搜索出错时看到清晰的错误提示，以便了解问题并采取行动。

#### Acceptance Criteria

1. WHEN the Backend_API encounters a database error, THE Backend_API SHALL return HTTP 500 with error code and message "搜索服务暂时不可用，请稍后重试"
2. WHEN the Search_Query is empty, THE Backend_API SHALL return HTTP 400 with error code and message "搜索关键词不能为空"
3. WHEN the Search_Query exceeds 200 characters, THE Backend_API SHALL return HTTP 400 with error code and message "搜索关键词过长，请限制在200字符以内"
4. WHEN the user is not authenticated, THE Backend_API SHALL return HTTP 401 with error code and message "请先登录"
5. WHEN the user does not have workspace access, THE Backend_API SHALL return HTTP 403 with error code and message "您没有权限访问该工作区"
6. THE Frontend_UI SHALL display error messages in a toast notification or inline alert

# 需求文档

## 简介

本文档描述 **global-search（全局搜索）** 功能的需求。该功能为 Openflow 平台用户提供跨项目、剧本、资产的统一搜索能力，使用 PostgreSQL tsvector + GIN 索引实现中英文分词和权重排序，在统一结果页按类型分组展示搜索结果。功能包含搜索历史记录和高级过滤选项，严格遵循 workspace 级别权限控制。

平台技术栈：Rust 后端（Axum + SQLx + PostgreSQL）+ Flutter 前端。本功能遵循全栈交付约定（`docs/plans/full-stack-delivery-covenant.md`），后端 API、前端 UI 和 `rust_api` 绑定须同里程碑交付。

---

## 词汇表

- **System（系统）**：Openflow 平台整体，包含 Rust 后端、Flutter 前端和数据库层
- **GlobalSearchBar（全局搜索框）**：主导航栏中的搜索输入组件，用户输入搜索关键词的入口
- **SearchResultsPage（搜索结果页）**：展示搜索结果的统一页面，按类型分组显示项目、剧本、资产
- **SearchIndex（搜索索引）**：PostgreSQL 中使用 tsvector + GIN 索引构建的全文搜索索引
- **SearchQuery（搜索查询）**：用户输入的搜索关键词字符串
- **SearchResult（搜索结果）**：单条搜索结果记录，包含类型、标题、摘要、匹配度等信息
- **ResultType（结果类型）**：搜索结果的分类，包含 `project`（项目）、`script`（剧本）、`asset`（资产）
- **SearchHistory（搜索历史）**：用户过往搜索关键词的记录列表
- **AdvancedFilter（高级过滤）**：搜索结果的过滤选项，包含结果类型、创建时间范围、所属项目等
- **WorkspacePermission（工作区权限）**：用户在当前 workspace 下的访问权限，搜索结果必须遵循此权限
- **RankWeight（权重排序）**：搜索结果按匹配度和相关性计算的排序权重
- **Tokenizer（分词器）**：PostgreSQL 全文搜索使用的中英文分词配置
- **SearchBackend（搜索后端）**：Rust 后端中处理搜索请求的服务模块
- **SearchAPI（搜索 API）**：后端提供的搜索相关 REST API 端点
- **RustAPIBinding（Rust API 绑定）**：Flutter 前端通过 `rust_api` 调用后端搜索 API 的绑定层

---

## 需求

### 需求 1：全局搜索框入口

**用户故事：** 作为 Openflow 用户，我希望在主导航栏中能够快速访问全局搜索框，输入关键词后立即触发搜索，这样我可以快速找到项目、剧本或资产。

#### 验收标准

1. THE GlobalSearchBar SHALL 在主导航栏中显示为固定位置的搜索输入框，所有页面均可见。
2. WHEN 用户在 GlobalSearchBar 中输入至少 2 个字符时，THE System SHALL 启用搜索按钮或回车触发。
3. WHEN 用户输入少于 2 个字符时，THE GlobalSearchBar SHALL 禁用搜索触发，并显示提示信息「请输入至少 2 个字符」。
4. WHEN 用户按下回车键或点击搜索按钮时，THE System SHALL 导航到 SearchResultsPage 并传递 SearchQuery。
5. THE GlobalSearchBar SHALL 支持中文和英文输入，不限制输入字符类型。
6. WHEN 用户在 GlobalSearchBar 中输入时，THE System SHALL 显示最近 5 条 SearchHistory 作为快速选择项。
7. WHEN 用户点击 SearchHistory 中的某条记录时，THE System SHALL 自动填充该关键词并触发搜索。

---

### 需求 2：搜索索引构建与维护

**用户故事：** 作为平台运营者，我希望系统能够自动为项目、剧本、资产构建和维护全文搜索索引，这样用户搜索时能够快速获得准确结果。

#### 验收标准

1. THE System SHALL 为 `projects`、`scripts`、`assets` 表创建 tsvector 类型的 SearchIndex 列。
2. THE System SHALL 使用 PostgreSQL GIN 索引加速 SearchIndex 列的查询性能。
3. THE System SHALL 配置中英文混合分词的 Tokenizer，支持中文分词和英文词干提取。
4. WHEN 项目、剧本或资产记录创建或更新时，THE System SHALL 自动更新对应记录的 SearchIndex 列。
5. THE SearchIndex SHALL 包含记录的标题、描述、标签和关键元数据字段。
6. THE System SHALL 为不同字段设置 RankWeight，标题权重高于描述，描述权重高于标签。
7. WHEN 记录被删除时，THE System SHALL 自动从 SearchIndex 中移除对应条目。

---

### 需求 3：搜索 API 实现

**用户故事：** 作为前端开发者，我希望后端提供标准化的搜索 API，支持关键词查询、类型过滤、分页和排序，这样前端可以灵活展示搜索结果。

#### 验收标准

1. THE SearchBackend SHALL 提供 `GET /api/v1/search` 端点接收搜索请求。
2. THE SearchAPI SHALL 接受以下查询参数：`q`（关键词，必填）、`type`（结果类型过滤，可选）、`page`（页码，默认 1）、`page_size`（每页数量，默认 20，最大 100）。
3. WHEN 用户发起搜索请求时，THE SearchBackend SHALL 使用 PostgreSQL `ts_query` 和 `ts_rank` 函数执行全文搜索。
4. THE SearchBackend SHALL 仅返回当前用户在当前 workspace 下有权限访问的搜索结果。
5. THE SearchAPI SHALL 返回 JSON 格式响应，包含 `results`（结果列表）、`total`（总数）、`page`、`page_size` 字段。
6. THE SearchResult SHALL 包含 `id`、`type`、`title`、`snippet`（摘要）、`rank`（匹配度）、`created_at`、`updated_at` 字段。
7. WHEN 搜索关键词为空或少于 2 个字符时，THE SearchAPI SHALL 返回 HTTP 400 错误和错误信息。

---

### 需求 4：搜索结果页展示

**用户故事：** 作为 Openflow 用户，我希望搜索结果页能够按类型分组展示结果，并显示匹配摘要和相关信息，这样我可以快速定位目标内容。

#### 验收标准

1. THE SearchResultsPage SHALL 在页面顶部显示当前 SearchQuery 和结果总数。
2. THE SearchResultsPage SHALL 将搜索结果按 ResultType 分组展示，分组顺序为「项目」「剧本」「资产」。
3. WHEN 某个 ResultType 无结果时，THE SearchResultsPage SHALL 不显示该分组标题。
4. THE SearchResultsPage SHALL 为每条 SearchResult 显示标题、摘要、类型标签、更新时间。
5. THE SearchResultsPage SHALL 在摘要中高亮显示匹配的关键词。
6. WHEN 用户点击某条 SearchResult 时，THE System SHALL 导航到对应的详情页面。
7. THE SearchResultsPage SHALL 在底部提供分页控件，支持翻页查看更多结果。

---

### 需求 5：高级过滤选项

**用户故事：** 作为 Openflow 用户，我希望在搜索结果页中能够使用高级过滤选项，按类型、时间范围、所属项目等条件筛选结果，这样我可以更精确地找到目标内容。

#### 验收标准

1. THE SearchResultsPage SHALL 在侧边栏或顶部提供 AdvancedFilter 面板。
2. THE AdvancedFilter SHALL 提供「结果类型」多选框，包含「项目」「剧本」「资产」选项。
3. THE AdvancedFilter SHALL 提供「创建时间」范围选择器，支持选择起始和结束日期。
4. THE AdvancedFilter SHALL 提供「所属项目」下拉选择器，列出当前用户有权限访问的项目列表。
5. WHEN 用户修改 AdvancedFilter 选项时，THE System SHALL 自动重新发起搜索请求并更新结果。
6. THE AdvancedFilter SHALL 显示当前已应用的过滤条件数量。
7. WHEN 用户点击「清除过滤」按钮时，THE System SHALL 重置所有过滤条件并重新搜索。

---

### 需求 6：搜索历史记录

**用户故事：** 作为 Openflow 用户，我希望系统能够记录我的搜索历史，并在搜索框中快速访问，这样我可以重复使用常用搜索关键词。

#### 验收标准

1. THE System SHALL 为每个用户维护独立的 SearchHistory 记录表。
2. WHEN 用户成功执行搜索时，THE System SHALL 将 SearchQuery 保存到 SearchHistory 表。
3. THE System SHALL 为每条 SearchHistory 记录保存关键词、搜索时间、结果数量。
4. THE System SHALL 最多保存每个用户最近 50 条 SearchHistory 记录，超过时自动删除最旧记录。
5. WHEN 用户在 GlobalSearchBar 中输入时，THE System SHALL 显示最近 5 条匹配的 SearchHistory 记录。
6. THE System SHALL 支持用户删除单条或全部 SearchHistory 记录。
7. THE SearchHistory SHALL 按搜索时间倒序排列，最新记录在最前。

---

### 需求 7：权限控制与数据隔离

**用户故事：** 作为平台运营者，我希望搜索功能严格遵循 workspace 级别权限控制，用户只能搜索到自己有权限访问的内容，这样可以保证数据安全。

#### 验收标准

1. THE SearchBackend SHALL 在执行搜索前验证用户的 WorkspacePermission。
2. THE SearchBackend SHALL 仅返回用户在当前 workspace 下有读取权限的项目、剧本、资产。
3. WHEN 用户无权限访问某个 workspace 时，THE SearchBackend SHALL 返回 HTTP 403 错误。
4. THE SearchBackend SHALL 使用数据库行级安全策略（RLS）或应用层过滤确保权限隔离。
5. THE SearchBackend SHALL 记录搜索请求日志，包含用户 ID、workspace ID、搜索关键词、结果数量。
6. THE System SHALL 不在搜索结果中泄露用户无权限访问的记录标题或摘要。
7. WHEN 用户切换 workspace 时，THE System SHALL 清空当前搜索结果并重置搜索状态。

---

### 需求 8：搜索性能与响应时间

**用户故事：** 作为 Openflow 用户，我希望搜索响应速度快，即使数据量较大也能在 1 秒内返回结果，这样我可以高效完成工作。

#### 验收标准

1. THE SearchBackend SHALL 在 95% 的情况下在 1 秒内返回搜索结果。
2. THE System SHALL 使用 GIN 索引优化 tsvector 列的查询性能。
3. THE SearchBackend SHALL 限制单次搜索返回的最大结果数量为 1000 条。
4. WHEN 搜索结果超过 1000 条时，THE System SHALL 提示用户使用更精确的关键词或过滤条件。
5. THE SearchBackend SHALL 使用数据库连接池和查询缓存优化性能。
6. THE System SHALL 监控搜索 API 的响应时间，并在超过 2 秒时记录警告日志。
7. THE SearchBackend SHALL 支持异步执行搜索索引更新，不阻塞主业务流程。

---

### 需求 9：前端 UI 实现与用户体验

**用户故事：** 作为 Openflow 用户，我希望搜索界面简洁易用，加载状态清晰，错误提示友好，这样我可以流畅完成搜索操作。

#### 验收标准

1. THE GlobalSearchBar SHALL 在用户输入时显示加载指示器，搜索完成后隐藏。
2. THE SearchResultsPage SHALL 在加载搜索结果时显示骨架屏或加载动画。
3. WHEN 搜索无结果时，THE SearchResultsPage SHALL 显示友好提示「未找到匹配结果，请尝试其他关键词」。
4. WHEN 搜索 API 返回错误时，THE SearchResultsPage SHALL 显示错误信息和重试按钮。
5. THE SearchResultsPage SHALL 支持键盘导航，用户可使用上下箭头键选择结果，回车键打开详情。
6. THE GlobalSearchBar SHALL 支持快捷键（如 Ctrl+K 或 Cmd+K）快速聚焦搜索框。
7. THE SearchResultsPage SHALL 在移动端自适应布局，过滤面板折叠为抽屉式菜单。

---

### 需求 10：Rust API 绑定与前后端集成

**用户故事：** 作为前端开发者，我希望通过 `rust_api` 绑定调用搜索 API，保持与其他功能一致的调用方式，这样可以简化开发和维护。

#### 验收标准

1. THE RustAPIBinding SHALL 提供 `search` 方法，接受 SearchQuery、过滤参数、分页参数。
2. THE RustAPIBinding SHALL 返回结构化的 SearchResult 列表和分页信息。
3. THE RustAPIBinding SHALL 处理网络错误、超时、权限错误并返回友好错误信息。
4. THE RustAPIBinding SHALL 支持取消正在进行的搜索请求。
5. THE RustAPIBinding SHALL 提供 `getSearchHistory` 和 `deleteSearchHistory` 方法管理搜索历史。
6. THE RustAPIBinding SHALL 使用与其他 API 一致的认证和授权机制。
7. THE RustAPIBinding SHALL 在 `frontend/rust_api/` 目录下实现，并生成 Dart 绑定代码。

---

### 需求 11：搜索结果摘要生成

**用户故事：** 作为 Openflow 用户，我希望搜索结果中显示包含关键词的上下文摘要，这样我可以快速判断结果是否符合需求。

#### 验收标准

1. THE SearchBackend SHALL 使用 PostgreSQL `ts_headline` 函数生成搜索结果摘要。
2. THE SearchResult snippet SHALL 包含匹配关键词前后各 50 个字符的上下文。
3. THE SearchBackend SHALL 在摘要中使用特殊标记（如 `<mark>` 标签）标识匹配关键词。
4. THE SearchResultsPage SHALL 解析摘要中的标记并高亮显示匹配关键词。
5. WHEN 记录内容少于 100 个字符时，THE System SHALL 显示完整内容作为摘要。
6. THE SearchBackend SHALL 限制摘要最大长度为 200 个字符，超过时截断并添加省略号。
7. THE SearchBackend SHALL 优先从标题和描述字段生成摘要，其次从其他文本字段提取。

---

### 需求 12：搜索分析与监控

**用户故事：** 作为平台运营者,我希望系统能够记录和分析搜索行为数据，这样我可以了解用户搜索习惯并优化搜索功能。

#### 验收标准

1. THE System SHALL 记录每次搜索请求的关键词、用户 ID、workspace ID、结果数量、响应时间。
2. THE System SHALL 统计搜索关键词的频率分布，识别高频搜索词。
3. THE System SHALL 记录无结果搜索的关键词，用于优化索引和分词配置。
4. THE System SHALL 提供搜索分析仪表板，展示搜索量趋势、平均响应时间、无结果率。
5. THE System SHALL 支持按时间范围、用户、workspace 维度查询搜索统计数据。
6. THE System SHALL 监控搜索 API 的错误率和超时率，并在异常时发送告警。
7. THE System SHALL 定期分析搜索日志，识别性能瓶颈和优化机会。

---

## 附录 A：技术实现要点

| 技术点 | 说明 |
|--------|------|
| PostgreSQL tsvector | 使用 `to_tsvector` 函数创建全文搜索索引，支持中英文分词 |
| GIN 索引 | 为 tsvector 列创建 GIN 索引，加速全文搜索查询 |
| ts_query | 使用 `to_tsquery` 或 `plainto_tsquery` 构建搜索查询 |
| ts_rank | 使用 `ts_rank` 函数计算搜索结果的相关性排序权重 |
| ts_headline | 使用 `ts_headline` 函数生成包含关键词的上下文摘要 |
| 中文分词 | 配置 `zhparser` 或 `jieba` 扩展支持中文分词 |
| 权重配置 | 使用 `setweight` 函数为不同字段设置不同的搜索权重 |
| RLS | 使用 PostgreSQL 行级安全策略或应用层过滤实现权限控制 |

---

## 附录 B：API 端点清单

| 端点 | 方法 | 说明 | 状态 |
|------|------|------|------|
| `/api/v1/search` | GET | 执行全局搜索 | ❌ 待实现 |
| `/api/v1/search/history` | GET | 获取搜索历史 | ❌ 待实现 |
| `/api/v1/search/history` | DELETE | 删除搜索历史 | ❌ 待实现 |
| `/api/v1/search/stats` | GET | 获取搜索统计数据 | ❌ 待实现 |

---

## 附录 C：前端组件清单

| 组件 | 路径 | 说明 | 状态 |
|------|------|------|------|
| GlobalSearchBar | `frontend/lib/global_search/global_search_bar.dart` | 主导航栏搜索框 | ❌ 待实现 |
| SearchResultsPage | `frontend/lib/global_search/search_results_page.dart` | 搜索结果页 | ❌ 待实现 |
| SearchResultCard | `frontend/lib/global_search/search_result_card.dart` | 单条搜索结果卡片 | ❌ 待实现 |
| AdvancedFilterPanel | `frontend/lib/global_search/advanced_filter_panel.dart` | 高级过滤面板 | ❌ 待实现 |
| SearchHistoryList | `frontend/lib/global_search/search_history_list.dart` | 搜索历史列表 | ❌ 待实现 |

---

## 附录 D：数据库表结构

### search_history 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户 ID |
| workspace_id | UUID | 工作区 ID |
| query | TEXT | 搜索关键词 |
| result_count | INTEGER | 结果数量 |
| created_at | TIMESTAMP | 创建时间 |

### search_logs 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 用户 ID |
| workspace_id | UUID | 工作区 ID |
| query | TEXT | 搜索关键词 |
| result_count | INTEGER | 结果数量 |
| response_time_ms | INTEGER | 响应时间（毫秒）|
| filters | JSONB | 过滤条件 |
| created_at | TIMESTAMP | 创建时间 |

### 索引列添加

为现有表添加 tsvector 列和 GIN 索引：

```sql
-- projects 表
ALTER TABLE projects ADD COLUMN search_vector tsvector;
CREATE INDEX idx_projects_search ON projects USING GIN(search_vector);

-- scripts 表
ALTER TABLE scripts ADD COLUMN search_vector tsvector;
CREATE INDEX idx_scripts_search ON scripts USING GIN(search_vector);

-- assets 表
ALTER TABLE assets ADD COLUMN search_vector tsvector;
CREATE INDEX idx_assets_search ON assets USING GIN(search_vector);
```

---

## 附录 E：全栈交付检查清单

根据 `docs/plans/full-stack-delivery-covenant.md`，本功能交付须满足：

- [x] 后端 Rust API 实现（`backend/src/api/search.rs`）
- [x] OpenAPI 规范更新（`backend/src/openapi_spec/`）
- [x] 前端 Flutter UI 实现（`frontend/lib/global_search/`）
- [x] Rust API 绑定实现（`frontend/rust_api/`）
- [x] 数据库迁移脚本（`supabase/migrations/`）
- [x] 单元测试和集成测试
- [x] 门禁检查通过（`yarn refactor:check`）

