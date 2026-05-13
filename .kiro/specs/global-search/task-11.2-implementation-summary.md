# Task 11.2 Implementation Summary: 搜索日志记录

## 概述

成功实现了搜索日志记录功能，用于性能监控和搜索行为分析。该功能记录所有搜索请求的详细信息，包括关键词、用户、workspace、结果数、响应时间等，并自动标记慢查询（>1 秒）。

## 实现内容

### 1. 数据库迁移 (Migration)

**文件**: `supabase/migrations/20260518120000_create_search_logs.sql`

创建了 `app_search_log` 表，包含以下字段：
- `id`: UUID 主键
- `user_id`: 用户 ID（外键到 auth.users）
- `workspace_id`: 工作区 ID（外键到 app_workspace）
- `query`: 搜索关键词（2-200 字符）
- `result_count`: 结果数量
- `response_time_ms`: 响应时间（毫秒）
- `filters`: 过滤条件（JSONB 格式）
- `is_slow_query`: 自动计算字段（response_time_ms > 1000）
- `created_at`: 创建时间

**索引**:
- `idx_app_search_log_slow_queries`: 慢查询索引（WHERE is_slow_query = true）
- `idx_app_search_log_user`: 用户维度索引
- `idx_app_search_log_workspace`: 工作区维度索引
- `idx_app_search_log_created_at`: 时间维度索引
- `idx_app_search_log_query`: 查询关键词索引

**RLS 策略**:
- 仅 service_role 可访问（用于管理员分析和监控）
- 普通用户无法直接访问搜索日志

**辅助函数**:
1. `cleanup_old_search_logs()`: 自动删除 180 天前的日志
2. `get_slow_query_stats(hours)`: 获取慢查询统计信息
3. `get_search_analytics(workspace_id, hours)`: 获取搜索分析数据

### 2. 后端日志记录模块

**文件**: `backend/src/search/logging.rs`

实现了以下核心功能：

#### 数据结构
- `SearchLogEntry`: 搜索日志条目结构体
- `SlowQueryStats`: 慢查询统计信息
- `SearchAnalytics`: 搜索分析数据

#### 核心函数

1. **`log_search_request(pool, entry)`**
   - 记录搜索请求到数据库
   - 自动检测慢查询（>1 秒）并记录警告日志
   - 异步执行，不阻塞主业务流程

2. **`build_filters_json(query)`**
   - 从 SearchQuery 构建过滤条件 JSON
   - 包含 result_type、time_from、time_to、page、page_size

3. **`log_unauthorized_search_attempt(pool, user_id, workspace_id, query)`**
   - 记录未授权的搜索尝试（用于安全审计）
   - 在 filters 中标记 `unauthorized: true`

4. **`get_slow_query_stats(pool, hours)`**
   - 获取指定时间范围内的慢查询统计
   - 返回总数、平均响应时间、最大响应时间、最常见慢查询

5. **`get_search_analytics(pool, workspace_id, hours)`**
   - 获取搜索分析数据
   - 返回搜索总数、唯一用户数、平均响应时间、慢查询率、平均结果数、热门查询

### 3. 集成到搜索 API

**文件**: `backend/src/search/routes.rs`

在 `search_handler` 中集成了日志记录功能：

1. **响应时间测量**
   - 使用 `std::time::Instant` 记录搜索开始时间
   - 计算搜索完成后的响应时间（毫秒）

2. **成功场景日志**
   - 搜索成功后记录完整日志（关键词、用户、workspace、结果数、响应时间、过滤条件）
   - 异步执行，不影响响应返回

3. **失败场景日志**
   - 权限错误时调用 `log_unauthorized_search_attempt` 记录未授权尝试
   - 其他错误也记录日志（result_count = 0）用于错误分析

4. **慢查询警告**
   - 响应时间 > 1 秒时自动记录 tracing::warn 日志
   - 包含 user_id、workspace_id、query、response_time_ms

### 4. 单元测试

**文件**: `backend/src/search/logging_test.rs`

实现了全面的单元测试，覆盖：
- `build_filters_json` 的各种场景（空过滤、类型过滤、时间范围过滤、全部过滤）
- `SearchLogEntry` 的创建和验证
- 慢查询检测逻辑（边界条件：1000ms vs 1001ms）
- 响应时间范围测试（快速、正常、较慢、慢查询）
- 查询长度验证（最短 2 字符、最长 200 字符、中文查询）
- 结果数量范围测试（无结果、少量结果、大量结果）

## 满足的需求

### Requirement 7.6: 记录未授权搜索尝试
✅ 实现了 `log_unauthorized_search_attempt` 函数，在用户尝试访问无权限 workspace 时记录日志，用于安全审计。

### Requirement 9.5: 记录慢查询
✅ 实现了自动慢查询检测（>1 秒），通过数据库 GENERATED 列 `is_slow_query` 自动标记，并在应用层记录 tracing::warn 日志。

### Requirement 12.1: 记录搜索请求详细信息
✅ 完整记录每次搜索请求的：
- 关键词 (query)
- 用户 ID (user_id)
- 工作区 ID (workspace_id)
- 结果数量 (result_count)
- 响应时间 (response_time_ms)
- 过滤条件 (filters)

## 技术亮点

1. **性能优化**
   - 使用 GENERATED ALWAYS AS STORED 列自动计算 is_slow_query，无需应用层判断
   - 创建针对性索引（慢查询索引、时间索引、用户索引等）
   - 异步日志记录，不阻塞搜索响应

2. **数据治理**
   - 自动清理 180 天前的日志（cleanup_old_search_logs 函数）
   - RLS 策略限制仅 service_role 访问，保护用户隐私

3. **可观测性**
   - 提供 `get_slow_query_stats` 和 `get_search_analytics` 函数用于监控仪表板
   - 集成 tracing 日志框架，慢查询自动记录警告日志

4. **安全审计**
   - 记录未授权搜索尝试，包含用户、workspace、查询关键词
   - 在 filters 字段中标记 `unauthorized: true` 便于筛选

## 使用示例

### 查询慢查询统计（最近 24 小时）
```sql
SELECT * FROM public.get_slow_query_stats(24);
```

返回：
- `total_slow_queries`: 慢查询总数
- `avg_response_time_ms`: 平均响应时间
- `max_response_time_ms`: 最大响应时间
- `most_common_slow_query`: 最常见的慢查询关键词

### 查询搜索分析数据（特定 workspace，最近 7 天）
```sql
SELECT * FROM public.get_search_analytics('workspace-uuid', 168);
```

返回：
- `total_searches`: 搜索总数
- `unique_users`: 唯一用户数
- `avg_response_time_ms`: 平均响应时间
- `slow_query_rate`: 慢查询率（百分比）
- `avg_results_per_search`: 平均每次搜索的结果数
- `top_queries`: 热门搜索关键词（前 10）

### 查询所有慢查询（最近 24 小时）
```sql
SELECT 
  user_id,
  workspace_id,
  query,
  result_count,
  response_time_ms,
  created_at
FROM public.app_search_log
WHERE is_slow_query = true
  AND created_at >= NOW() - INTERVAL '24 hours'
ORDER BY response_time_ms DESC
LIMIT 100;
```

### 查询未授权搜索尝试
```sql
SELECT 
  user_id,
  workspace_id,
  query,
  created_at
FROM public.app_search_log
WHERE filters->>'unauthorized' = 'true'
ORDER BY created_at DESC
LIMIT 100;
```

## 后续优化建议

1. **定时任务**
   - 设置 cron job 定期调用 `cleanup_old_search_logs()` 清理旧日志
   - 建议每天凌晨执行一次

2. **监控告警**
   - 集成到监控系统（如 Prometheus + Grafana）
   - 设置慢查询率告警阈值（如 >5%）
   - 设置平均响应时间告警阈值（如 >500ms）

3. **搜索优化**
   - 定期分析慢查询日志，优化索引和查询逻辑
   - 分析无结果搜索，优化分词和索引配置

4. **用户行为分析**
   - 分析热门搜索关键词，优化搜索建议
   - 分析搜索结果点击率，优化排序算法

## 测试验证

### 单元测试
```bash
cd backend
cargo test search::logging
```

所有测试通过，覆盖：
- 过滤条件构建逻辑
- 慢查询检测逻辑
- 日志条目创建和验证
- 边界条件测试

### 集成测试
需要在集成测试中验证：
1. 搜索请求成功后日志正确记录
2. 慢查询（>1 秒）正确标记
3. 未授权搜索尝试正确记录
4. 统计函数返回正确数据

## 文件清单

1. **数据库迁移**
   - `supabase/migrations/20260518120000_create_search_logs.sql`

2. **后端代码**
   - `backend/src/search/logging.rs` (新增)
   - `backend/src/search/logging_test.rs` (新增)
   - `backend/src/search/mod.rs` (修改：添加 logging 模块)
   - `backend/src/search/routes.rs` (修改：集成日志记录)

3. **文档**
   - `.kiro/specs/global-search/task-11.2-implementation-summary.md` (本文档)

## 总结

Task 11.2 已完成，成功实现了搜索日志记录功能，满足所有需求：
- ✅ 记录搜索请求详细信息（关键词、用户、workspace、结果数、响应时间）
- ✅ 自动检测和记录慢查询（>1 秒）
- ✅ 记录未授权搜索尝试用于安全审计
- ✅ 提供统计和分析函数用于性能监控
- ✅ 实现完整的单元测试

该功能为搜索系统的性能监控、用户行为分析和安全审计提供了坚实的数据基础。

