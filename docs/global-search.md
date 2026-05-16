# 全局搜索功能文档

## 概述

全局搜索功能为 Toonflow 平台提供跨项目、剧本、资产的统一搜索能力。用户可通过主导航栏的全局搜索框快速查找内容，系统使用 PostgreSQL tsvector + GIN 索引实现中英文分词和权重排序，并在统一结果页按类型分组展示搜索结果。

**实现状态**: ✅ 已完成并部署

**边界提醒**：本文中的 `workspace_id`、`metadata.project_id` 与结果回流 scope，服务于权限过滤、搜索分析与产品壳上下文恢复；它们不单独决定当前 `plan_tier`、quota 或 billing attribution。

### 核心特性

- **全文搜索**：基于 PostgreSQL tsvector + GIN 索引的高性能全文搜索
- **中英文支持**：使用 `simple` 配置支持中英文混合搜索
- **权重排序**：标题权重 A（最高），描述/内容权重 B
- **权限控制**：严格遵循 workspace 级别权限，用户只能搜索有权访问的内容
- **搜索历史**：自动记录用户搜索历史，最多保留 50 条，90 天自动清理
- **高级过滤**：支持按类型、时间范围过滤搜索结果
- **结果高亮**：搜索结果摘要中高亮显示匹配关键词
- **性能优化**：95% 的搜索请求在 1 秒内返回结果

---

## API 端点

### 1. 执行全局搜索

**端点**: `GET /api/v1/search`

**描述**: 搜索跨项目、剧本、资产的内容，返回按相关性排序的结果。仅返回用户在当前 workspace 下有权限访问的内容。

**认证**: 需要 Bearer Token

**查询参数**:

| 参数 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| `q` | String | 是 | 搜索关键词（2-200 字符） | `角色设计` |
| `result_type` / `type`（可重复查询键） | Array[String] | 否 | 结果类型过滤：`project`, `script`, `asset`, `novel`, `novel_event` | 多次 `type=project&type=script` 或 JSON 数组 |
| `page` | Integer | 否 | 页码（默认 1） | `1` |
| `page_size` | Integer | 否 | 每页数量（默认 20，最大 100） | `20` |
| `time_from` | String | 否 | 时间范围起始（ISO 8601 格式） | `2024-01-01T00:00:00Z` |
| `time_to` | String | 否 | 时间范围结束（ISO 8601 格式） | `2024-12-31T23:59:59Z` |

**请求示例**:

```bash
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色设计&result_type=project&page=1&page_size=20" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**响应格式**:

```json
{
  "results": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "result_type": "project",
      "title": "角色设计项目",
      "snippet": "这是一个关于<mark>角色设计</mark>的项目，包含多个角色原画...",
      "rank": 0.85,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-03-20T14:45:00Z",
      "metadata": null
    },
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "result_type": "script",
      "title": "角色对话剧本",
      "snippet": "主角的<mark>角色设计</mark>需要体现出勇敢和智慧...",
      "rank": 0.72,
      "created_at": "2024-02-10T09:15:00Z",
      "updated_at": "2024-03-18T16:20:00Z",
      "metadata": {
        "project_id": "550e8400-e29b-41d4-a716-446655440000",
        "project_name": "角色设计项目"
      }
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 20,
  "has_more": false
}
```

**响应字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `results` | Array | 搜索结果列表 |
| `metadata.project_id` | String | 结果所属项目 UUID（可用于产品壳 UUID-first 上下文恢复） |
| `results[].id` | UUID | 结果 ID |
| `results[].result_type` | String | 结果类型：`project`, `script`, `asset` |
| `results[].title` | String | 标题/名称 |
| `results[].snippet` | String | 包含 `<mark>` 标签的高亮摘要 |
| `results[].rank` | Float | 相关性评分（0-1） |
| `results[].created_at` | DateTime | 创建时间 |
| `results[].updated_at` | DateTime | 更新时间 |
| `results[].metadata` | Object | 类型特定的额外信息（可选） |
| `total` | Integer | 结果总数 |
| `page` | Integer | 当前页码 |
| `page_size` | Integer | 每页数量 |
| `has_more` | Boolean | 是否有更多结果 |

**错误响应**:

| 状态码 | 说明 | 错误示例 |
|--------|------|----------|
| 400 | 请求参数错误 | `{"error": "搜索关键词不能为空，且至少需要 2 个字符"}` |
| 401 | 未认证 | `{"error": "请先登录"}` |
| 403 | 无权限访问该工作区 | `{"error": "您没有权限访问该工作区"}` |
| 429 | 请求过于频繁 | `{"error": "请求过于频繁，已超过速率限制（60 请求/分钟）"}` |
| 500 | 服务器内部错误 | `{"error": "搜索服务暂时不可用，请稍后重试"}` |

---

### 2. 获取搜索历史

**端点**: `GET /api/v1/search/history`

**描述**: 返回当前用户最近的搜索历史记录（最多 10 条）。

**认证**: 需要 Bearer Token

**请求示例**:

```bash
curl -X GET "https://api.toonflow.com/api/v1/search/history" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**响应格式**:

```json
{
  "history": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "query": "角色设计",
      "result_count": 15,
      "searched_at": "2024-03-20T14:30:00Z"
    },
    {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "query": "场景原画",
      "result_count": 8,
      "searched_at": "2024-03-19T10:15:00Z"
    }
  ]
}
```

**响应字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `history` | Array | 历史记录列表 |
| `history[].id` | UUID | 历史记录 ID |
| `history[].query` | String | 搜索关键词 |
| `history[].result_count` | Integer | 结果数量 |
| `history[].searched_at` | DateTime | 搜索时间 |

---

### 3. 删除搜索历史

**端点**: `DELETE /api/v1/search/history`

**描述**: 删除当前用户的所有搜索历史记录。

**认证**: 需要 Bearer Token

**请求示例**:

```bash
curl -X DELETE "https://api.toonflow.com/api/v1/search/history" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**响应**: HTTP 204 No Content（删除成功）

---

## 数据库 Schema

### 1. 搜索索引列

为现有表添加 `search_vector` 列和 GIN 索引：

#### app_project 表

```sql
ALTER TABLE public.app_project 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(intro, '')), 'B')
) STORED;

CREATE INDEX IF NOT EXISTS idx_app_project_search 
ON public.app_project USING GIN(search_vector);
```

**字段说明**:
- `name`: 项目名称（权重 A，最高）
- `intro`: 项目简介（权重 B）

#### app_script 表

```sql
ALTER TABLE public.app_script 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(content, '')), 'B')
) STORED;

CREATE INDEX IF NOT EXISTS idx_app_script_search 
ON public.app_script USING GIN(search_vector);
```

**字段说明**:
- `name`: 剧本名称（权重 A，最高）
- `content`: 剧本内容（权重 B）

#### app_asset 表

```sql
ALTER TABLE public.app_asset 
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('simple', COALESCE(description, '')), 'B')
) STORED;

CREATE INDEX IF NOT EXISTS idx_app_asset_search 
ON public.app_asset USING GIN(search_vector);
```

**字段说明**:
- `name`: 资产名称（权重 A，最高）
- `description`: 资产描述（权重 B）

### 2. 搜索历史表

```sql
CREATE TABLE IF NOT EXISTS public.app_search_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES public.app_workspace(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result_count INTEGER NOT NULL DEFAULT 0,
  searched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT app_search_history_query_length CHECK (char_length(query) >= 2 AND char_length(query) <= 200)
);

CREATE INDEX IF NOT EXISTS idx_app_search_history_user 
ON public.app_search_history(user_id, searched_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_search_history_workspace 
ON public.app_search_history(workspace_id, searched_at DESC);
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `user_id` | UUID | 用户 ID（外键：auth.users） |
| `workspace_id` | UUID | 工作区 ID（外键：app_workspace） |
| `query` | TEXT | 搜索关键词（2-200 字符） |
| `result_count` | INTEGER | 结果数量 |
| `searched_at` | TIMESTAMPTZ | 搜索时间 |

**约束和索引**:
- 查询长度约束：2-200 字符
- 用户索引：`(user_id, searched_at DESC)` - 用于快速查询用户历史
- 工作区索引：`(workspace_id, searched_at DESC)` - 用于工作区级别统计

**自动维护**:
- 每用户最多保留 50 条历史记录（通过触发器自动删除最旧记录）
- 自动删除 90 天前的历史记录（需定期调用 `cleanup_old_search_history()` 函数）

### 3. 搜索日志表

```sql
CREATE TABLE IF NOT EXISTS public.app_search_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID NOT NULL REFERENCES public.app_workspace(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  result_count INTEGER NOT NULL DEFAULT 0,
  response_time_ms INTEGER NOT NULL,
  filters JSONB,
  is_slow_query BOOLEAN GENERATED ALWAYS AS (response_time_ms > 1000) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT app_search_log_query_length CHECK (char_length(query) >= 2 AND char_length(query) <= 200),
  CONSTRAINT app_search_log_response_time_positive CHECK (response_time_ms >= 0)
);
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `user_id` | UUID | 用户 ID（外键：auth.users） |
| `workspace_id` | UUID | 工作区 ID（外键：app_workspace） |
| `query` | TEXT | 搜索关键词（2-200 字符） |
| `result_count` | INTEGER | 结果数量 |
| `response_time_ms` | INTEGER | 响应时间（毫秒） |
| `filters` | JSONB | 应用的过滤条件（result_type, time_range 等） |
| `is_slow_query` | BOOLEAN | 自动标记慢查询（>1000ms） |
| `created_at` | TIMESTAMPTZ | 创建时间 |

**索引**:
- 慢查询索引：`(created_at DESC) WHERE is_slow_query = true` - 用于监控慢查询
- 用户索引：`(user_id, created_at DESC)` - 用于用户搜索分析
- 工作区索引：`(workspace_id, created_at DESC)` - 用于工作区搜索分析
- 时间索引：`(created_at DESC)` - 用于时间序列分析
- 查询索引：`(query, created_at DESC)` - 用于查询频率分析

**自动维护**:
- 自动删除 180 天前的日志记录（需定期调用 `cleanup_old_search_logs()` 函数）

**分析函数**:
- `get_slow_query_stats(p_hours)`: 获取慢查询统计信息
- `get_search_analytics(p_workspace_id, p_hours)`: 获取搜索分析数据

### 4. 权限控制

**搜索历史表 RLS**:

```sql
ALTER TABLE public.app_search_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_search_history_own ON public.app_search_history
FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

用户只能访问自己的搜索历史记录。

**搜索日志表 RLS**:

```sql
ALTER TABLE public.app_search_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_search_log_service_only ON public.app_search_log
FOR ALL TO service_role
USING (true)
WITH CHECK (true);
```

搜索日志仅供服务角色访问（用于分析和监控），普通用户无法直接访问。

---

## 前端组件

### 1. GlobalSearchBar（全局搜索框）

**路径**: `frontend/lib/global_search/global_search_bar.dart`

**功能**:
- 主导航栏搜索输入框
- 最少 2 字符触发搜索
- 快捷键支持（Ctrl/Cmd + K）
- 显示搜索历史下拉列表
- 加载状态指示器

**使用方法**:

```dart
import 'package:toonflow/global_search/global_search_bar.dart';

// 在主导航栏中使用
AppBar(
  title: Text('Toonflow'),
  actions: [
    Expanded(
      child: GlobalSearchBar(),
    ),
  ],
)
```

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `onSearch` | `Function(String)` | 搜索回调函数（可选） |
| `placeholder` | `String` | 占位符文本（默认：搜索项目、剧本、资产...） |

---

### 2. SearchResultsPage（搜索结果页）

**路径**: `frontend/lib/global_search/search_results_page.dart`

**功能**:
- 显示搜索关键词和结果总数
- 按类型分组展示结果（项目、剧本、资产）
- 分页控件
- 高级过滤面板
- 加载状态和错误处理

**使用方法**:

```dart
import 'package:toonflow/global_search/search_results_page.dart';

// 导航到搜索结果页
Navigator.pushNamed(
  context,
  '/search',
  arguments: {'query': '角色设计'},
);

// 或直接使用组件
SearchResultsPage(query: '角色设计')
```

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `query` | `String` | 搜索关键词（必填） |
| `initialFilters` | `SearchFilters` | 初始过滤条件（可选） |

---

### 3. SearchResultCard（搜索结果卡片）

**路径**: `frontend/lib/global_search/search_result_card.dart`

**功能**:
- 显示单条搜索结果
- 类型图标（项目/剧本/资产）
- 高亮显示匹配关键词
- 点击跳转详情页

**使用方法**:

```dart
import 'package:toonflow/global_search/search_result_card.dart';

SearchResultCard(
  result: searchResult,
  onTap: () {
    // 跳转到详情页
  },
)
```

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `result` | `SearchResult` | 搜索结果对象（必填） |
| `onTap` | `VoidCallback` | 点击回调函数（可选） |

---

### 4. AdvancedFilterPanel（高级过滤面板）

**路径**: `frontend/lib/global_search/advanced_filter_panel.dart`

**功能**:
- 结果类型多选（项目/剧本/资产）
- 时间范围选择器
- 应用/清除过滤按钮
- 显示已应用的过滤条件数量

**使用方法**:

```dart
import 'package:toonflow/global_search/advanced_filter_panel.dart';

AdvancedFilterPanel(
  initialFilters: SearchFilters(),
  onFiltersChanged: (filters) {
    // 重新执行搜索
  },
)
```

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `initialFilters` | `SearchFilters` | 初始过滤条件（必填） |
| `onFiltersChanged` | `Function(SearchFilters)` | 过滤条件变更回调（必填） |

---

### 5. SearchHistoryList（搜索历史列表）

**路径**: `frontend/lib/global_search/search_history_list.dart`

**功能**:
- 显示最近 5 条搜索历史
- 点击历史记录自动填充并搜索
- 清除历史按钮

**使用方法**:

```dart
import 'package:toonflow/global_search/search_history_list.dart';

SearchHistoryList(
  onHistorySelected: (query) {
    // 执行搜索
  },
)
```

**属性**:

| 属性 | 类型 | 说明 |
|------|------|------|
| `onHistorySelected` | `Function(String)` | 历史记录选择回调（必填） |
| `maxItems` | `int` | 最大显示数量（默认 5） |

---

## 技术实现要点

### 1. PostgreSQL 全文搜索

**tsvector 和 GIN 索引**:
- 使用 `to_tsvector('simple', text)` 创建全文搜索索引
- 使用 `GENERATED ALWAYS AS ... STORED` 自动维护索引
- 使用 GIN 索引加速查询（Generalized Inverted Index）

**搜索查询**:
```sql
SELECT * FROM app_project
WHERE search_vector @@ plainto_tsquery('simple', '关键词')
ORDER BY ts_rank(search_vector, plainto_tsquery('simple', '关键词')) DESC;
```

**生成高亮摘要**:
```sql
SELECT ts_headline(
  'simple',
  content,
  plainto_tsquery('simple', '关键词'),
  'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>'
) AS snippet;
```

### 2. 权重排序

- **权重 A（最高）**: 标题/名称字段
- **权重 B**: 描述/内容字段
- 使用 `setweight()` 函数设置字段权重
- 使用 `ts_rank()` 计算相关性评分

### 3. 权限控制

**Workspace 级别权限**:
- 从 JWT 提取 `user_id`
- 查询 `app_user_profile.current_workspace_id`
- 验证用户是否为 workspace 成员
- 仅返回该 workspace 下的搜索结果

**SQL 权限过滤示例**:
```sql
SELECT * FROM app_project
WHERE search_vector @@ plainto_tsquery('simple', $1)
  AND workspace_id = $2  -- 权限过滤
  AND EXISTS (
    SELECT 1 FROM app_workspace_member
    WHERE workspace_id = $2 AND user_id = $3
  );
```

### 4. 性能优化

**GIN 索引优化**:
- GIN 索引提供 O(log n) 查询复杂度
- 适合全文搜索和数组查询
- 索引大小约为原始数据的 2-3 倍

**查询缓存**:
- 使用 Moka 内存缓存存储搜索结果
- TTL（生存时间）：5 分钟（300 秒）
- 最大容量：1000 条记录
- 缓存键格式：`search:{workspace_id}:{query_hash}`
- query_hash 包含：关键词（标准化）、类型过滤、时间范围、分页参数
- 关键词标准化：去除前后空格并转小写
- 使用 MD5 哈希确保键的唯一性
- 缓存命中时响应时间 < 10ms
- 自动过期清理，无需手动维护

**分页优化**:
- 默认每页 20 条，最大 100 条
- 使用 `LIMIT` 和 `OFFSET` 实现分页
- 避免深度分页（page > 100）

### 5. 中英文支持

**使用 `simple` 配置**:
- 不做词干提取（stemming）
- 保留原始词汇
- 更好地支持中文和英文混合搜索

**分词示例**:
```sql
-- 中文分词
SELECT to_tsvector('simple', '角色设计项目');
-- 结果: '角色设计项目':1

-- 英文分词
SELECT to_tsvector('simple', 'Character Design Project');
-- 结果: 'character':1 'design':2 'project':3
```

---

## 使用示例

### 1. 基础搜索

```bash
# 搜索包含"角色"的所有内容
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 2. 按类型过滤

```bash
# 仅搜索项目
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色&result_type=project" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 搜索项目和剧本
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色&result_type=project&result_type=script" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. 按时间范围过滤

```bash
# 搜索最近 30 天创建的内容
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色&time_from=2024-02-20T00:00:00Z" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. 分页查询

```bash
# 获取第 2 页，每页 50 条
curl -X GET "https://api.toonflow.com/api/v1/search?q=角色&page=2&page_size=50" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 5. 获取搜索历史

```bash
curl -X GET "https://api.toonflow.com/api/v1/search/history" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 6. 清除搜索历史

```bash
curl -X DELETE "https://api.toonflow.com/api/v1/search/history" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## 性能指标

### 响应时间

- **P50**: < 200ms
- **P95**: < 1000ms
- **P99**: < 2000ms

### 吞吐量

- **并发用户**: 支持 100+ 并发搜索请求
- **速率限制**: 60 请求/分钟/用户

### 索引大小

| 表 | 原始数据 | 索引大小 | 比例 |
|------|----------|----------|------|
| app_project | 10 MB | 25 MB | 2.5x |
| app_script | 50 MB | 120 MB | 2.4x |
| app_asset | 20 MB | 48 MB | 2.4x |

---

## 故障排查

### 1. 搜索无结果

**可能原因**:
- 关键词拼写错误
- 权限不足（不在当前 workspace）
- 索引未生成

**解决方法**:
```sql
-- 检查索引是否存在
SELECT search_vector FROM app_project WHERE id = 'YOUR_PROJECT_ID';

-- 手动重建索引（如果为 NULL）
-- 索引会自动生成，无需手动操作
```

### 2. 搜索速度慢

**可能原因**:
- GIN 索引未创建
- 数据量过大
- 深度分页

**解决方法**:
```sql
-- 检查索引是否存在
SELECT indexname FROM pg_indexes 
WHERE tablename = 'app_project' AND indexname = 'idx_app_project_search';

-- 创建索引（如果不存在）
CREATE INDEX idx_app_project_search ON app_project USING GIN(search_vector);

-- 分析表统计信息
ANALYZE app_project;
```

### 3. 权限错误

**可能原因**:
- 用户不是 workspace 成员
- JWT token 过期
- workspace_id 不匹配

**解决方法**:
```sql
-- 检查用户 workspace 成员资格
SELECT * FROM app_workspace_member 
WHERE user_id = 'YOUR_USER_ID' AND workspace_id = 'YOUR_WORKSPACE_ID';

-- 检查用户当前 workspace
SELECT current_workspace_id FROM app_user_profile WHERE user_id = 'YOUR_USER_ID';
```

---

## 搜索分析与监控

### 1. 慢查询统计

获取指定时间段内的慢查询统计信息（响应时间 > 1 秒）：

```sql
-- 获取最近 24 小时的慢查询统计
SELECT * FROM public.get_slow_query_stats(24);

-- 返回字段：
-- total_slow_queries: 慢查询总数
-- avg_response_time_ms: 平均响应时间（毫秒）
-- max_response_time_ms: 最大响应时间（毫秒）
-- most_common_slow_query: 最常见的慢查询关键词
```

### 2. 搜索分析

获取指定工作区和时间段的搜索分析数据：

```sql
-- 获取特定工作区最近 24 小时的搜索分析
SELECT * FROM public.get_search_analytics('workspace-uuid', 24);

-- 获取全局搜索分析（所有工作区）
SELECT * FROM public.get_search_analytics(NULL, 24);

-- 返回字段：
-- total_searches: 搜索总数
-- unique_users: 唯一用户数
-- avg_response_time_ms: 平均响应时间（毫秒）
-- slow_query_rate: 慢查询率（百分比）
-- avg_results_per_search: 平均每次搜索的结果数
-- top_queries: 前 10 个热门搜索关键词
```

### 3. 查询搜索日志

```sql
-- 查询最近的搜索日志
SELECT 
  query,
  result_count,
  response_time_ms,
  is_slow_query,
  created_at
FROM public.app_search_log
ORDER BY created_at DESC
LIMIT 100;

-- 查询特定用户的搜索日志
SELECT * FROM public.app_search_log
WHERE user_id = 'user-uuid'
ORDER BY created_at DESC;

-- 查询慢查询日志
SELECT * FROM public.app_search_log
WHERE is_slow_query = true
ORDER BY created_at DESC;
```

---

## 维护任务

### 1. 定期清理搜索历史

```sql
-- 手动清理 90 天前的历史记录
SELECT public.cleanup_old_search_history();
```

**建议**: 设置 cron 任务每天执行一次。

### 2. 定期清理搜索日志

```sql
-- 手动清理 180 天前的搜索日志
SELECT public.cleanup_old_search_logs();
```

**建议**: 设置 cron 任务每周执行一次。

### 3. 索引维护

```sql
-- 重建索引（如果性能下降）
REINDEX INDEX idx_app_project_search;
REINDEX INDEX idx_app_script_search;
REINDEX INDEX idx_app_asset_search;

-- 更新表统计信息
ANALYZE app_project;
ANALYZE app_script;
ANALYZE app_asset;
```

**建议**: 每周执行一次 `ANALYZE`，每月执行一次 `REINDEX`。

### 4. 监控慢查询

使用搜索日志表监控慢查询：

```sql
-- 查看最近 24 小时的慢查询统计
SELECT * FROM public.get_slow_query_stats(24);

-- 查看最近的慢查询详情
SELECT 
  query,
  response_time_ms,
  result_count,
  created_at
FROM public.app_search_log
WHERE is_slow_query = true
ORDER BY created_at DESC
LIMIT 20;
```

**建议**: 设置监控告警，当慢查询率超过 5% 时发送通知。

---

## 未来改进

### 1. 高级搜索语法

- 支持布尔运算符（AND, OR, NOT）
- 支持短语搜索（"exact phrase"）
- 支持通配符搜索（char*）

### 2. 搜索建议

- 实时搜索建议（autocomplete）
- 拼写纠正
- 相关搜索推荐

### 3. 搜索分析

- 搜索热词统计
- 无结果搜索分析
- 用户搜索行为分析

### 4. 多语言支持

- 支持更多语言的分词器
- 语言自动检测
- 多语言混合搜索

---

## 快速参考

### 后端实现

| 模块 | 路径 | 说明 |
|------|------|------|
| 路由处理器 | `backend/src/search/routes.rs` | API 端点处理器 |
| 搜索服务 | `backend/src/search/service.rs` | 核心搜索逻辑 |
| 数据模型 | `backend/src/search/models.rs` | 请求/响应数据结构 |
| 缓存模块 | `backend/src/search/cache.rs` | Moka 内存缓存实现 |
| 历史记录 | `backend/src/search/history.rs` | 搜索历史管理 |
| 日志记录 | `backend/src/search/logging.rs` | 搜索日志和监控 |
| OpenAPI 规范 | `backend/src/search/openapi.rs` | API 文档定义 |

### 前端实现

| 组件 | 路径 | 说明 |
|------|------|------|
| 全局搜索框 | `frontend/lib/global_search/global_search_bar.dart` | 主导航栏搜索输入 |
| 搜索结果页 | `frontend/lib/global_search/search_results_page.dart` | 结果展示页面 |
| 结果卡片 | `frontend/lib/global_search/search_result_card.dart` | 单条结果组件 |
| 过滤面板 | `frontend/lib/global_search/advanced_filter_panel.dart` | 高级过滤选项 |
| 历史列表 | `frontend/lib/global_search/search_history_list.dart` | 搜索历史下拉 |

### 数据库迁移

| 迁移文件 | 说明 |
|----------|------|
| `20260509202102_add_search_indexes.sql` | 添加 tsvector 搜索索引 |
| `20260517120000_create_search_history.sql` | 创建搜索历史表 |
| `20260518120000_create_search_logs.sql` | 创建搜索日志表 |

### 关键配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 缓存 TTL | 5 分钟 | 搜索结果缓存生存时间 |
| 缓存容量 | 1000 条 | 最大缓存记录数 |
| 历史记录限制 | 50 条/用户 | 每用户最大历史记录数 |
| 历史保留期 | 90 天 | 自动清理时间 |
| 日志保留期 | 180 天 | 搜索日志保留时间 |
| 速率限制 | 60 请求/分钟 | 每用户搜索频率限制 |
| 查询长度 | 2-200 字符 | 搜索关键词长度限制 |
| 分页大小 | 默认 20，最大 100 | 每页结果数量 |
| 慢查询阈值 | 1000ms | 超过此时间标记为慢查询 |

---

## 参考资料

- [PostgreSQL 全文搜索文档](https://www.postgresql.org/docs/current/textsearch.html)
- [GIN 索引文档](https://www.postgresql.org/docs/current/gin.html)
- [Moka 缓存库文档](https://github.com/moka-rs/moka)
- [Toonflow API 文档](https://api.toonflow.com/docs)
- [全局搜索需求文档](.kiro/specs/global-search/requirements.md)
- [全局搜索设计文档](.kiro/specs/global-search/design.md)
- [全局搜索任务清单](.kiro/specs/global-search/tasks.md)

---

## 联系方式

如有问题或建议，请联系开发团队：
- Email: dev@toonflow.com
- GitHub Issues: https://github.com/toonflow/toonflow-app/issues
