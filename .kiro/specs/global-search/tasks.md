# Implementation Plan: Global Search

## Overview

本实现计划将全局搜索功能分解为可执行的编码任务。该功能基于 PostgreSQL tsvector + GIN 索引实现跨项目、剧本、资产的全文搜索，包含搜索历史、高级过滤和权限控制。

技术栈：Rust (后端) + Flutter (前端) + PostgreSQL (数据库)

## Tasks

- [x] 1. 数据库迁移：创建搜索索引和历史表
  - [x] 1.1 创建搜索索引迁移脚本
    - 为 `app_project`、`app_script`、`app_asset` 表添加 `search_vector` 列（tsvector 类型）
    - 使用 `GENERATED ALWAYS AS` 自动维护索引（标题权重 A，描述权重 B）
    - 创建 GIN 索引加速全文搜索
    - 迁移文件路径：`supabase/migrations/YYYYMMDDHHMMSS_add_search_indexes.sql`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  
  - [x] 1.2 创建搜索历史表迁移脚本
    - 创建 `app_search_history` 表（id, user_id, workspace_id, query, result_count, searched_at）
    - 添加查询长度约束（2-200 字符）
    - 创建索引：user_id + searched_at DESC, workspace_id + searched_at DESC
    - 配置 RLS 策略：用户只能访问自己的历史记录
    - 创建自动清理函数：删除 90 天前的历史
    - 创建触发器：限制每用户最多 50 条历史
    - 迁移文件路径：`supabase/migrations/YYYYMMDDHHMMSS_create_search_history.sql`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 5.7_

- [x] 2. 后端核心搜索服务实现
  - [x] 2.1 实现搜索数据模型和错误类型
    - 创建 `backend/src/search/mod.rs` 模块入口
    - 定义 `SearchQuery`、`SearchResponse`、`SearchResult`、`ResultType` 结构体
    - 定义 `SearchError` 错误类型（InvalidQuery, PermissionDenied, DatabaseError 等）
    - 实现 Serde 序列化/反序列化
    - _Requirements: 3.1, 3.2, 3.3, 3.6, 10.1, 10.2, 10.3_
  
  - [x] 2.2 实现搜索服务核心逻辑
    - 创建 `backend/src/search/service.rs`
    - 实现 `SearchService` 结构体（包含 PgPool）
    - 实现 `verify_workspace_access` 方法：验证用户 workspace 权限
    - 实现 `build_search_query` 方法：构建 PostgreSQL 全文搜索查询（使用 `plainto_tsquery`）
    - 实现跨表联合搜索（UNION ALL 查询项目、剧本、资产）
    - 使用 `ts_rank` 计算相关性评分并排序
    - 使用 `ts_headline` 生成包含高亮标记的摘要（`<mark>` 标签）
    - 实现分页逻辑（默认 20 条/页，最大 100 条）
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.3, 3.4, 3.5, 7.1, 7.2, 7.3, 7.4, 11.1, 11.2, 11.3, 11.6, 11.7_
  
  - [x] 2.3 编写搜索服务单元测试
    - 测试 `verify_workspace_access`：有权限/无权限场景
    - 测试 `build_search_query`：关键词转义和 SQL 注入防护
    - 测试搜索结果排序：按 rank 和 updated_at 排序
    - 测试分页逻辑：边界条件（page=0, page_size>100）
    - 测试摘要生成：高亮标记正确性
    - 测试文件：`backend/src/search/service_test.rs`
    - _Requirements: 3.7, 8.5_

- [x] 3. 后端搜索 API 实现
  - [x] 3.1 实现搜索 API 处理器
    - 创建 `backend/src/search/api.rs`
    - 实现 `GET /api/v1/search` 端点处理器
    - 解析查询参数：q, result_type, page, page_size, time_from, time_to
    - 验证查询参数：q 长度 2-200 字符，page_size ≤ 100
    - 从 JWT 提取 user_id 和 current_workspace_id
    - 调用 `SearchService::search` 执行搜索
    - 返回 JSON 响应（SearchResponse）
    - 错误处理：返回标准化错误响应（HTTP 400/403/500）
    - _Requirements: 3.1, 3.2, 3.3, 3.7, 7.1, 7.5, 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [x] 3.2 实现搜索历史 API 处理器
    - 创建 `backend/src/search/history.rs`
    - 实现 `GET /api/v1/search/history` 端点：返回用户最近 10 条搜索历史
    - 实现 `DELETE /api/v1/search/history` 端点：删除用户所有搜索历史（返回 204）
    - 在搜索成功后自动保存历史记录到 `app_search_history` 表
    - 验证用户权限（仅能访问自己的历史）
    - _Requirements: 5.1, 5.2, 5.5, 5.6, 6.5, 6.6_
  
  - [x] 3.3 注册搜索路由到 Axum 应用
    - 在 `backend/src/main.rs` 或路由模块中注册搜索路由
    - 添加认证中间件到搜索路由
    - 配置 CORS 和速率限制（60 请求/分钟）
    - _Requirements: 8.2, 9.7_
  
  - [x] 3.4 编写搜索 API 集成测试
    - 测试完整搜索流程：发起请求 → 验证权限 → 返回结果
    - 测试权限隔离：用户 A 无法搜索到用户 B 的 workspace 内容
    - 测试高级过滤：按类型、时间范围过滤
    - 测试搜索历史：保存、获取、删除
    - 测试错误场景：空查询、超长查询、无权限
    - 测试文件：`backend/tests/search_api_test.rs`
    - _Requirements: 7.6, 8.5, 8.6, 10.6_

- [x] 4. 后端 OpenAPI 规范更新
  - [x] 4.1 更新 OpenAPI 规范文档
    - 在 `backend/src/openapi_spec/` 中添加搜索 API 定义
    - 定义 `/api/v1/search` 端点（GET）：参数、响应、错误码
    - 定义 `/api/v1/search/history` 端点（GET, DELETE）
    - 定义数据模型：SearchQuery, SearchResponse, SearchResult, HistoryEntry
    - 添加示例请求和响应
    - 运行 `cargo run --bin export-openapi` 验证规范可解析
    - _Requirements: 8.1, 8.2_

- [x] 5. Checkpoint - 后端实现验证
  - 运行 `cargo fmt` 和 `cargo clippy` 确保代码质量
  - 运行 `cargo test` 确保所有测试通过
  - 运行 `yarn refactor:check` 验证门禁通过
  - 确认数据库迁移可成功应用
  - 询问用户是否有问题或需要调整

- [x] 6. 前端 Rust API 绑定实现
  - [x] 6.1 实现搜索 API 绑定
    - 创建 `frontend/rust_api/lib/search.dart`
    - 实现 `RustApiSearch.search()` 方法：调用 `GET /api/v1/search`
    - 实现 `RustApiSearch.getHistory()` 方法：调用 `GET /api/v1/search/history`
    - 实现 `RustApiSearch.deleteHistory()` 方法：调用 `DELETE /api/v1/search/history`
    - 定义 Dart 数据模型：SearchQuery, SearchResponse, SearchResult, HistoryEntry
    - 处理网络错误、超时、权限错误并返回友好错误信息
    - 支持取消正在进行的搜索请求
    - _Requirements: 8.3, 8.4, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_
  
  - [x] 6.2 编写 Rust API 绑定单元测试
    - 测试请求参数序列化
    - 测试响应反序列化
    - 测试错误处理
    - 测试文件：`frontend/rust_api/test/search_test.dart`
    - _Requirements: 8.6_

- [x] 7. 前端全局搜索框组件实现
  - [x] 7.1 实现 GlobalSearchBar 组件
    - 创建 `frontend/lib/global_search/global_search_bar.dart`
    - 实现搜索输入框（TextEditingController）
    - 实现最少 2 字符触发逻辑（输入少于 2 字符时禁用搜索）
    - 实现回车键和搜索按钮触发搜索
    - 实现快捷键支持（Ctrl/Cmd + K 聚焦搜索框）
    - 实现加载状态指示器
    - 导航到搜索结果页并传递查询参数
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 9.1, 9.6_
  
  - [x] 7.2 实现搜索历史下拉列表
    - 创建 `frontend/lib/global_search/search_history_list.dart`
    - 在搜索框获得焦点时显示最近 5 条历史记录
    - 点击历史记录自动填充并触发搜索
    - 提供「清除历史」按钮
    - 调用 `RustApiSearch.getHistory()` 和 `deleteHistory()`
    - _Requirements: 1.6, 1.7, 5.5, 6.6_
  
  - [x] 7.3 编写 GlobalSearchBar 组件测试
    - 测试输入验证（少于 2 字符禁用）
    - 测试快捷键触发
    - 测试导航逻辑
    - 测试文件：`frontend/test/global_search/global_search_bar_test.dart`
    - _Requirements: 9.6_

- [x] 8. 前端搜索结果页实现
  - [x] 8.1 实现 SearchResultsPage 页面
    - 创建 `frontend/lib/global_search/search_results_page.dart`
    - 在页面顶部显示搜索关键词和结果总数
    - 实现加载状态（骨架屏或加载动画）
    - 调用 `RustApiSearch.search()` 获取搜索结果
    - 按类型分组展示结果（项目、剧本、资产）
    - 实现分页控件（上一页/下一页）
    - 处理无结果场景：显示「未找到匹配结果，请尝试其他关键词」
    - 处理错误场景：显示错误信息和重试按钮
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.7, 9.2, 9.3, 9.4_
  
  - [x] 8.2 实现 SearchResultCard 组件
    - 创建 `frontend/lib/global_search/search_result_card.dart`
    - 显示类型图标（项目/剧本/资产）
    - 显示标题、更新时间
    - 解析 snippet 中的 `<mark>` 标签并高亮显示匹配关键词
    - 实现点击跳转到详情页
    - _Requirements: 4.5, 4.6, 11.4_
  
  - [x] 8.3 实现 AdvancedFilterPanel 组件
    - 创建 `frontend/lib/global_search/advanced_filter_panel.dart`
    - 实现结果类型多选框（项目/剧本/资产）
    - 实现时间范围选择器（起始日期、结束日期）
    - 实现「应用过滤」和「清除过滤」按钮
    - 显示当前已应用的过滤条件数量
    - 修改过滤条件时自动重新搜索
    - 移动端自适应：折叠为抽屉式菜单
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 9.7_
  
  - [x] 8.4 编写搜索结果页组件测试
    - 测试搜索结果渲染
    - 测试分页逻辑
    - 测试过滤功能
    - 测试无结果和错误场景
    - 测试文件：`frontend/test/global_search/search_results_page_test.dart`
    - _Requirements: 9.3, 9.4_

- [x] 9. 前端路由和导航集成
  - [x] 9.1 注册搜索相关路由
    - 在 Flutter 路由配置中添加 `/search` 路由
    - 配置路由参数传递（query, filters）
    - 在主导航栏中集成 GlobalSearchBar 组件
    - _Requirements: 1.1, 1.4_
  
  - [x] 9.2 实现键盘导航支持
    - 在搜索结果页支持上下箭头键选择结果
    - 支持回车键打开选中的结果详情
    - _Requirements: 9.5_

- [x] 10. Checkpoint - 前端实现验证
  - 运行 `flutter pub get` 安装依赖
  - 运行 `flutter analyze` 确保无静态分析错误
  - 运行 `flutter test` 确保所有测试通过
  - 运行 `yarn refactor:check` 验证门禁通过
  - 手动测试搜索流程：输入关键词 → 查看结果 → 应用过滤 → 查看历史
  - 询问用户是否有问题或需要调整

- [x] 11. 性能优化和监控
  - [x] 11.1 实现搜索结果缓存
    - 在后端实现查询结果缓存（5 分钟 TTL）
    - 使用 Redis 或内存缓存存储相同查询的结果
    - _Requirements: 9.2_
  
  - [x] 11.2 实现搜索日志记录
    - 创建搜索日志记录功能（关键词、用户、workspace、结果数、响应时间）
    - 记录慢查询（>1 秒）用于性能监控
    - _Requirements: 7.6, 9.5, 12.1_
  
  - [x] 11.3 实现速率限制
    - 在搜索 API 上实现速率限制（60 请求/分钟/用户）
    - 超过限制返回 HTTP 429 Too Many Requests
    - _Requirements: 9.7_

- [x] 12. 文档和最终验证
  - [x] 12.1 更新项目文档
    - 在 `docs/` 中添加全局搜索功能文档
    - 记录 API 端点、参数、响应格式
    - 记录数据库 schema 变更
    - 记录前端组件使用方法
  
  - [x] 12.2 最终集成测试
    - 端到端测试：从搜索框输入 → 后端查询 → 结果展示
    - 测试权限隔离：多用户、多 workspace 场景
    - 测试性能：大数据量下的响应时间
    - 测试错误恢复：数据库连接失败、网络超时等
  
  - [x] 12.3 运行完整门禁检查
    - 运行 `yarn refactor:check` 确保所有检查通过
    - 确认所有测试通过（后端 + 前端）
    - 确认代码格式化和 lint 检查通过
    - 确认 OpenAPI 规范可正确导出

## Notes

- **任务标记说明**：
  - 标记 `*` 的子任务为可选测试任务，可跳过以加速 MVP 交付
  - 未标记 `*` 的任务为核心实现任务，必须完成
  
- **权限控制**：所有搜索查询必须严格遵循 workspace 级别权限，通过 RLS 或应用层过滤实现

- **性能目标**：95% 的搜索请求在 1 秒内返回结果，通过 GIN 索引和查询优化实现

- **全栈交付**：本功能遵循 `docs/plans/full-stack-delivery-covenant.md`，后端 API、前端 UI、Rust API 绑定同步交付

- **门禁检查**：每个 Checkpoint 必须运行 `yarn refactor:check` 确保代码质量

- **数据库迁移**：迁移脚本使用时间戳命名（YYYYMMDDHHMMSS），按顺序应用

- **中英文支持**：使用 PostgreSQL `simple` 配置支持中英文混合搜索，不做词干提取

- **搜索历史限制**：每用户最多 50 条历史，自动删除 90 天前的记录

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1.1", "1.2"]
    },
    {
      "id": 1,
      "tasks": ["2.1", "4.1"]
    },
    {
      "id": 2,
      "tasks": ["2.2", "3.1", "3.2"]
    },
    {
      "id": 3,
      "tasks": ["2.3", "3.3", "3.4"]
    },
    {
      "id": 4,
      "tasks": ["6.1"]
    },
    {
      "id": 5,
      "tasks": ["6.2", "7.1", "7.2"]
    },
    {
      "id": 6,
      "tasks": ["7.3", "8.1", "8.2", "8.3"]
    },
    {
      "id": 7,
      "tasks": ["8.4", "9.1", "9.2"]
    },
    {
      "id": 8,
      "tasks": ["11.1", "11.2", "11.3"]
    },
    {
      "id": 9,
      "tasks": ["12.1", "12.2", "12.3"]
    }
  ]
}
```
