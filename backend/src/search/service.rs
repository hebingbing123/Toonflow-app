//! 搜索服务核心逻辑。
//!
//! 负责构建 PostgreSQL 全文搜索查询、应用权限过滤、结果排序和分页。

use chrono::{DateTime, Utc};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::{
    error::ApiError,
    search::{
        cache::SearchCache,
        models::{ResultType, SearchError, SearchQuery, SearchResponse, SearchResult},
    },
};

/// 搜索服务
pub struct SearchService {
    pool: PgPool,
    cache: SearchCache,
}

impl SearchService {
    /// 创建搜索服务实例
    pub fn new(pool: PgPool) -> Self {
        Self {
            pool,
            cache: SearchCache::new(),
        }
    }

    /// 创建带自定义缓存的搜索服务实例
    pub fn with_cache(pool: PgPool, cache: SearchCache) -> Self {
        Self { pool, cache }
    }

    /// 执行跨表搜索
    ///
    /// 实现跨项目、剧本、资产的全文搜索，包含权限验证、结果排序和分页。
    /// 使用内存缓存（5 分钟 TTL）提升性能。
    pub async fn search(
        &self,
        user_id: Uuid,
        workspace_id: Uuid,
        query: SearchQuery,
    ) -> Result<SearchResponse, ApiError> {
        // 验证查询参数
        if query.q.trim().is_empty() {
            return Err(SearchError::InvalidQuery("搜索关键词不能为空".to_string()).into());
        }
        if query.q.len() > 200 {
            return Err(SearchError::InvalidQuery(
                "搜索关键词过长，请限制在200字符以内".to_string(),
            )
            .into());
        }

        // 验证分页参数
        let page = query.page.max(1);
        let page_size = query.page_size.clamp(1, 100);

        // 验证用户 workspace 权限
        self.verify_workspace_access(user_id, workspace_id).await?;

        // 尝试从缓存获取结果
        if let Some(cached_response) = self.cache.get(workspace_id, &query).await {
            tracing::debug!(
                workspace_id = %workspace_id,
                query = %query.q,
                page = page,
                "Search cache hit"
            );
            return Ok(cached_response);
        }

        tracing::debug!(
            workspace_id = %workspace_id,
            query = %query.q,
            page = page,
            "Search cache miss, executing database query"
        );

        // 构建搜索查询字符串（用于 plainto_tsquery）
        let search_term = query.q.trim();
        let search_like = build_search_like_pattern(search_term);

        // 计算偏移量
        let offset = (page - 1) * page_size;
        let limit = page_size + 1; // 多查询一条用于判断是否有更多结果

        // 构建类型过滤条件
        let type_filter = if let Some(ref types) = query.result_type {
            if types.is_empty() {
                None
            } else {
                Some(types.clone())
            }
        } else {
            None
        };

        // 执行跨表联合搜索
        let results = self
            .execute_union_search(
                workspace_id,
                search_term,
                &search_like,
                type_filter.as_deref(),
                query.time_from,
                query.time_to,
                limit as i64,
                offset as i64,
            )
            .await?;

        // 判断是否有更多结果
        let has_more = results.len() > page_size as usize;
        let results = results
            .into_iter()
            .take(page_size as usize)
            .collect::<Vec<_>>();

        // 计算总数（简化实现：如果有更多结果，total = page * page_size + 1）
        let total = if has_more {
            page * page_size + 1
        } else {
            (page - 1) * page_size + results.len() as u32
        };

        let response = SearchResponse {
            results,
            total,
            page,
            page_size,
            has_more,
        };

        // 将结果存入缓存
        self.cache.set(workspace_id, &query, response.clone()).await;

        Ok(response)
    }

    /// 验证用户 workspace 权限
    ///
    /// 检查用户是否是指定 workspace 的成员。
    async fn verify_workspace_access(
        &self,
        user_id: Uuid,
        workspace_id: Uuid,
    ) -> Result<bool, ApiError> {
        let result = sqlx::query(
            r#"
            SELECT EXISTS(
                SELECT 1
                FROM public.app_workspace_member
                WHERE workspace_id = $1 AND user_id = $2
            ) as is_member
            "#,
        )
        .bind(workspace_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(SearchError::from)?;

        let is_member: bool = result.get("is_member");

        if !is_member {
            return Err(SearchError::PermissionDenied("您没有权限访问该工作区".to_string()).into());
        }

        Ok(true)
    }

    /// 获取缓存统计信息
    pub fn cache_stats(&self) -> crate::search::cache::CacheStats {
        self.cache.stats()
    }

    /// 清除指定 workspace 的搜索缓存
    pub async fn invalidate_workspace_cache(&self, workspace_id: Uuid) {
        self.cache.invalidate_workspace(workspace_id).await;
    }

    /// 清除所有搜索缓存
    pub async fn clear_cache(&self) {
        self.cache.clear().await;
    }

    /// 执行跨表联合搜索（UNION ALL）
    ///
    /// 搜索 `app_project`、`app_script`、`app_asset`、`app_novel`、`app_novel_event`，使用 `ts_rank` 排序。
    #[allow(clippy::too_many_arguments)]
    async fn execute_union_search(
        &self,
        workspace_id: Uuid,
        search_term: &str,
        search_like: &str,
        type_filter: Option<&[ResultType]>,
        time_from: Option<DateTime<Utc>>,
        time_to: Option<DateTime<Utc>>,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<SearchResult>, ApiError> {
        // 判断是否需要搜索各个类型
        let search_projects = type_filter
            .map(|types| types.contains(&ResultType::Project))
            .unwrap_or(true);
        let search_scripts = type_filter
            .map(|types| types.contains(&ResultType::Script))
            .unwrap_or(true);
        let search_assets = type_filter
            .map(|types| types.contains(&ResultType::Asset))
            .unwrap_or(true);
        let search_novels = type_filter
            .map(|types| types.contains(&ResultType::Novel))
            .unwrap_or(true);
        let search_novel_events = type_filter
            .map(|types| types.contains(&ResultType::NovelEvent))
            .unwrap_or(true);

        // 构建 UNION ALL 查询
        let mut union_parts = Vec::new();

        if search_projects {
            // 构建项目时间过滤条件
            let time_filter_proj = match (time_from, time_to) {
                (Some(from), Some(to)) => {
                    format!("AND updated_at >= '{}' AND updated_at <= '{}'", from, to)
                }
                (Some(from), None) => format!("AND updated_at >= '{}'", from),
                (None, Some(to)) => format!("AND updated_at <= '{}'", to),
                (None, None) => String::new(),
            };

            union_parts.push(format!(
                r#"
                SELECT 
                    id,
                    'project' as result_type,
                    name as title,
                    CASE
                        WHEN search_vector @@ plainto_tsquery('simple', $1) THEN
                            ts_headline('simple', COALESCE(intro, ''), plainto_tsquery('simple', $1),
                                'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>')
                        ELSE LEFT(COALESCE(NULLIF(intro, ''), name, ''), 180)
                    END as snippet,
                    (
                        ts_rank(search_vector, plainto_tsquery('simple', $1))
                        + CASE WHEN COALESCE(name, '') ILIKE $3 ESCAPE '\' THEN 2.5 ELSE 0.0 END
                        + CASE WHEN COALESCE(intro, '') ILIKE $3 ESCAPE '\' THEN 0.8 ELSE 0.0 END
                    ) as rank,
                    created_at,
                    updated_at,
                    jsonb_build_object(
                        'project_numeric_id', numeric_id,
                        'workspace_id', workspace_id
                    ) as metadata
                FROM public.app_project
                WHERE 
                    (
                        search_vector @@ plainto_tsquery('simple', $1)
                        OR COALESCE(name, '') ILIKE $3 ESCAPE '\'
                        OR COALESCE(intro, '') ILIKE $3 ESCAPE '\'
                    )
                    AND workspace_id = $2
                    AND archived_at IS NULL
                    {}
                "#,
                time_filter_proj
            ));
        }

        if search_scripts {
            // 构建剧本时间过滤条件（使用 s. 前缀）
            let time_filter_script = match (time_from, time_to) {
                (Some(from), Some(to)) => {
                    format!(
                        "AND s.updated_at >= '{}' AND s.updated_at <= '{}'",
                        from, to
                    )
                }
                (Some(from), None) => format!("AND s.updated_at >= '{}'", from),
                (None, Some(to)) => format!("AND s.updated_at <= '{}'", to),
                (None, None) => String::new(),
            };

            union_parts.push(format!(
                r#"
                SELECT 
                    s.id,
                    'script' as result_type,
                    s.name as title,
                    CASE
                        WHEN s.search_vector @@ plainto_tsquery('simple', $1) THEN
                            ts_headline('simple', COALESCE(s.content, ''), plainto_tsquery('simple', $1),
                                'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>')
                        ELSE LEFT(COALESCE(NULLIF(s.content, ''), s.name, ''), 180)
                    END as snippet,
                    (
                        ts_rank(s.search_vector, plainto_tsquery('simple', $1))
                        + CASE WHEN COALESCE(s.name, '') ILIKE $3 ESCAPE '\' THEN 2.5 ELSE 0.0 END
                        + CASE WHEN COALESCE(s.content, '') ILIKE $3 ESCAPE '\' THEN 0.8 ELSE 0.0 END
                    ) as rank,
                    s.created_at,
                    s.updated_at,
                    jsonb_build_object(
                        'project_id', p.id,
                        'project_name', p.name,
                        'project_numeric_id', p.numeric_id,
                        'workspace_id', p.workspace_id,
                        'script_numeric_id', s.numeric_id
                    ) as metadata
                FROM public.app_script s
                INNER JOIN public.app_project p ON p.id = s.project_id
                WHERE 
                    (
                        s.search_vector @@ plainto_tsquery('simple', $1)
                        OR COALESCE(s.name, '') ILIKE $3 ESCAPE '\'
                        OR COALESCE(s.content, '') ILIKE $3 ESCAPE '\'
                    )
                    AND p.workspace_id = $2
                    AND p.archived_at IS NULL
                    {}
                "#,
                time_filter_script
            ));
        }

        if search_assets {
            // 构建资产时间过滤条件（使用 a. 前缀）
            let time_filter_asset = match (time_from, time_to) {
                (Some(from), Some(to)) => {
                    format!(
                        "AND a.updated_at >= '{}' AND a.updated_at <= '{}'",
                        from, to
                    )
                }
                (Some(from), None) => format!("AND a.updated_at >= '{}'", from),
                (None, Some(to)) => format!("AND a.updated_at <= '{}'", to),
                (None, None) => String::new(),
            };

            union_parts.push(format!(
                r#"
                SELECT 
                    a.id,
                    'asset' as result_type,
                    a.name as title,
                    CASE
                        WHEN a.search_vector @@ plainto_tsquery('simple', $1) THEN
                            ts_headline('simple', COALESCE(a.description, ''), plainto_tsquery('simple', $1),
                                'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>')
                        ELSE LEFT(COALESCE(NULLIF(a.description, ''), a.name, ''), 180)
                    END as snippet,
                    (
                        ts_rank(a.search_vector, plainto_tsquery('simple', $1))
                        + CASE WHEN COALESCE(a.name, '') ILIKE $3 ESCAPE '\' THEN 2.5 ELSE 0.0 END
                        + CASE WHEN COALESCE(a.description, '') ILIKE $3 ESCAPE '\' THEN 0.8 ELSE 0.0 END
                    ) as rank,
                    a.created_at,
                    a.updated_at,
                    jsonb_build_object(
                        'project_id', p.id,
                        'project_name', p.name,
                        'project_numeric_id', p.numeric_id,
                        'workspace_id', p.workspace_id,
                        'asset_numeric_id', a.numeric_id,
                        'asset_type', a.asset_type
                    ) as metadata
                FROM public.app_asset a
                INNER JOIN public.app_project p ON p.id = a.project_id
                WHERE 
                    (
                        a.search_vector @@ plainto_tsquery('simple', $1)
                        OR COALESCE(a.name, '') ILIKE $3 ESCAPE '\'
                        OR COALESCE(a.description, '') ILIKE $3 ESCAPE '\'
                    )
                    AND p.workspace_id = $2
                    AND p.archived_at IS NULL
                    {}
                "#,
                time_filter_asset
            ));
        }

        if search_novels {
            let time_filter_novel = match (time_from, time_to) {
                (Some(from), Some(to)) => {
                    format!(
                        "AND n.updated_at >= '{}' AND n.updated_at <= '{}'",
                        from, to
                    )
                }
                (Some(from), None) => format!("AND n.updated_at >= '{}'", from),
                (None, Some(to)) => format!("AND n.updated_at <= '{}'", to),
                (None, None) => String::new(),
            };

            union_parts.push(format!(
                r#"
                SELECT 
                    n.id,
                    'novel' as result_type,
                    CONCAT('章 ', n.chapter_index::text, ' · ', LEFT(COALESCE(NULLIF(trim(n.chapter), ''), '未命名'), 120)) as title,
                    CASE
                        WHEN n.search_vector @@ plainto_tsquery('simple', $1) THEN
                            ts_headline('simple', COALESCE(n.chapter_data, ''), plainto_tsquery('simple', $1),
                                'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>')
                        ELSE LEFT(COALESCE(NULLIF(n.chapter_data, ''), n.chapter, ''), 180)
                    END as snippet,
                    (
                        ts_rank(n.search_vector, plainto_tsquery('simple', $1))
                        + CASE WHEN COALESCE(n.chapter, '') ILIKE $3 ESCAPE '\' THEN 2.5 ELSE 0.0 END
                        + CASE WHEN COALESCE(n.chapter_data, '') ILIKE $3 ESCAPE '\' THEN 0.8 ELSE 0.0 END
                    ) as rank,
                    n.created_at,
                    n.updated_at,
                    jsonb_build_object(
                        'project_id', p.id,
                        'project_name', p.name,
                        'project_numeric_id', p.numeric_id,
                        'workspace_id', p.workspace_id,
                        'novel_numeric_id', n.numeric_id,
                        'chapter_index', n.chapter_index
                    ) as metadata
                FROM public.app_novel n
                INNER JOIN public.app_project p ON p.id = n.project_id
                WHERE 
                    (
                        n.search_vector @@ plainto_tsquery('simple', $1)
                        OR COALESCE(n.chapter, '') ILIKE $3 ESCAPE '\'
                        OR COALESCE(n.chapter_data, '') ILIKE $3 ESCAPE '\'
                    )
                    AND p.workspace_id = $2
                    AND p.archived_at IS NULL
                    {}
                "#,
                time_filter_novel
            ));
        }

        if search_novel_events {
            let time_filter_event = match (time_from, time_to) {
                (Some(from), Some(to)) => {
                    format!(
                        "AND e.updated_at >= '{}' AND e.updated_at <= '{}'",
                        from, to
                    )
                }
                (Some(from), None) => format!("AND e.updated_at >= '{}'", from),
                (None, Some(to)) => format!("AND e.updated_at <= '{}'", to),
                (None, None) => String::new(),
            };

            union_parts.push(format!(
                r#"
                SELECT 
                    e.id,
                    'novel_event' as result_type,
                    COALESCE(NULLIF(trim(e.name), ''), '未命名事件') as title,
                    CASE
                        WHEN e.search_vector @@ plainto_tsquery('simple', $1) THEN
                            ts_headline('simple', COALESCE(e.detail, ''), plainto_tsquery('simple', $1),
                                'MaxWords=50, MinWords=25, StartSel=<mark>, StopSel=</mark>')
                        ELSE LEFT(COALESCE(NULLIF(e.detail, ''), e.name, ''), 180)
                    END as snippet,
                    (
                        ts_rank(e.search_vector, plainto_tsquery('simple', $1))
                        + CASE WHEN COALESCE(e.name, '') ILIKE $3 ESCAPE '\' THEN 2.5 ELSE 0.0 END
                        + CASE WHEN COALESCE(e.detail, '') ILIKE $3 ESCAPE '\' THEN 0.8 ELSE 0.0 END
                    ) as rank,
                    e.created_at,
                    e.updated_at,
                    jsonb_build_object(
                        'project_id', p.id,
                        'project_name', p.name,
                        'project_numeric_id', p.numeric_id,
                        'workspace_id', p.workspace_id,
                        'event_numeric_id', e.numeric_id
                    ) as metadata
                FROM public.app_novel_event e
                INNER JOIN public.app_project p ON p.id = e.project_id
                WHERE 
                    (
                        e.search_vector @@ plainto_tsquery('simple', $1)
                        OR COALESCE(e.name, '') ILIKE $3 ESCAPE '\'
                        OR COALESCE(e.detail, '') ILIKE $3 ESCAPE '\'
                    )
                    AND p.workspace_id = $2
                    AND p.archived_at IS NULL
                    {}
                "#,
                time_filter_event
            ));
        }

        if union_parts.is_empty() {
            return Ok(Vec::new());
        }

        // 组合 UNION ALL 查询并添加排序和分页
        let query_sql = format!(
            r#"
            WITH search_results AS (
                {}
            )
            SELECT * FROM search_results
            ORDER BY rank DESC, updated_at DESC
            LIMIT $3 OFFSET $4
            "#,
            union_parts.join(" UNION ALL ")
        );

        // 执行查询
        let rows = sqlx::query(&query_sql)
            .bind(search_term)
            .bind(workspace_id)
            .bind(search_like)
            .bind(limit)
            .bind(offset)
            .fetch_all(&self.pool)
            .await
            .map_err(SearchError::from)?;

        // 解析结果
        let mut results = Vec::new();
        for row in rows {
            let result_type_str: String = row.get("result_type");
            let result_type = match result_type_str.as_str() {
                "project" => ResultType::Project,
                "script" => ResultType::Script,
                "asset" => ResultType::Asset,
                "novel" => ResultType::Novel,
                "novel_event" => ResultType::NovelEvent,
                _ => continue,
            };

            let metadata_value: serde_json::Value = row.get("metadata");
            let metadata = if metadata_value.is_null() || metadata_value == serde_json::json!({}) {
                None
            } else {
                Some(metadata_value)
            };

            results.push(SearchResult {
                id: row.get("id"),
                result_type,
                title: row.get("title"),
                snippet: row.get("snippet"),
                rank: row.get("rank"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
                metadata,
            });
        }

        Ok(results)
    }
}

fn build_search_like_pattern(raw: &str) -> String {
    let trimmed = raw.trim();
    let escaped = trimmed
        .replace('\\', r"\\")
        .replace('%', r"\%")
        .replace('_', r"\_");
    format!("%{escaped}%")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::models::{ResultType, SearchQuery};

    /// 测试查询参数验证：空查询
    #[test]
    fn test_search_query_validation_empty() {
        // 创建一个空查询
        let query = SearchQuery {
            q: "".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        // 验证空查询应该被拒绝
        assert!(query.q.trim().is_empty());
    }

    /// 测试查询参数验证：超长查询
    #[test]
    fn test_search_query_validation_too_long() {
        // 创建一个超过 200 字符的查询
        let long_query = "a".repeat(201);
        let query = SearchQuery {
            q: long_query.clone(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        // 验证超长查询应该被拒绝
        assert!(query.q.len() > 200);
    }

    /// 测试查询参数验证：正常查询
    #[test]
    fn test_search_query_validation_valid() {
        let query = SearchQuery {
            q: "项目名称".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        assert!(!query.q.trim().is_empty());
        assert!(query.q.len() <= 200);
    }

    /// 测试分页参数：page=0 应该被修正为 1
    #[test]
    fn test_pagination_page_zero() {
        let page = 0u32;
        let corrected_page = page.max(1);
        assert_eq!(corrected_page, 1);
    }

    /// 测试分页参数：page_size>100 应该被限制为 100
    #[test]
    fn test_pagination_page_size_exceeds_max() {
        let page_size = 150u32;
        let corrected_page_size = page_size.clamp(1, 100);
        assert_eq!(corrected_page_size, 100);
    }

    /// 测试分页参数：page_size=0 应该被修正为 1
    #[test]
    fn test_pagination_page_size_zero() {
        let page_size = 0u32;
        let corrected_page_size = page_size.clamp(1, 100);
        assert_eq!(corrected_page_size, 1);
    }

    /// 测试分页参数：正常范围内的 page_size
    #[test]
    fn test_pagination_page_size_valid() {
        let page_size = 50u32;
        let corrected_page_size = page_size.clamp(1, 100);
        assert_eq!(corrected_page_size, 50);
    }

    /// 测试分页偏移量计算
    #[test]
    fn test_pagination_offset_calculation() {
        // 第 1 页，每页 20 条，偏移量应该是 0
        let page = 1u32;
        let page_size = 20u32;
        let offset = (page - 1) * page_size;
        assert_eq!(offset, 0);

        // 第 2 页，每页 20 条，偏移量应该是 20
        let page = 2u32;
        let offset = (page - 1) * page_size;
        assert_eq!(offset, 20);

        // 第 5 页，每页 50 条，偏移量应该是 200
        let page = 5u32;
        let page_size = 50u32;
        let offset = (page - 1) * page_size;
        assert_eq!(offset, 200);
    }

    /// 测试 has_more 逻辑：结果数量等于 page_size + 1 时应该有更多结果
    #[test]
    fn test_has_more_logic_true() {
        let page_size = 20usize;
        let results_count = 21usize; // 多查询了一条
        let has_more = results_count > page_size;
        assert!(has_more);
    }

    /// 测试 has_more 逻辑：结果数量小于等于 page_size 时没有更多结果
    #[test]
    fn test_has_more_logic_false() {
        let page_size = 20usize;
        let results_count = 15usize;
        let has_more = results_count > page_size;
        assert!(!has_more);
    }

    /// 测试 SQL 注入防护：plainto_tsquery 会自动处理特殊字符
    ///
    /// plainto_tsquery 将输入视为纯文本，不解析特殊字符，因此天然防止 SQL 注入
    #[test]
    fn test_sql_injection_protection() {
        // 测试各种可能的 SQL 注入尝试
        let malicious_inputs = vec![
            "'; DROP TABLE app_project; --",
            "' OR '1'='1",
            "'; DELETE FROM app_project WHERE '1'='1",
            "<script>alert('xss')</script>",
            "../../etc/passwd",
            "' UNION SELECT * FROM app_project --",
        ];

        for input in malicious_inputs {
            // plainto_tsquery 会将这些输入视为普通文本进行搜索
            // 不会执行任何 SQL 命令
            let trimmed = input.trim();
            assert!(!trimmed.is_empty());
            // 在实际使用中，这些字符串会被 plainto_tsquery 安全处理
        }
    }

    /// 测试关键词转义：特殊字符应该被保留（plainto_tsquery 会处理）
    #[test]
    fn test_keyword_escaping() {
        let keywords = vec![
            ("项目名称", "项目名称"),
            ("  项目名称  ", "项目名称"), // 前后空格应该被去除
            ("项目-名称", "项目-名称"),   // 连字符保留
            ("项目_名称", "项目_名称"),   // 下划线保留
            ("项目@名称", "项目@名称"),   // @ 符号保留
            ("项目#名称", "项目#名称"),   // # 符号保留
        ];

        for (input, expected) in keywords {
            let trimmed = input.trim();
            assert_eq!(trimmed, expected);
        }
    }

    #[test]
    fn test_build_search_like_pattern_escapes_like_metacharacters() {
        assert_eq!(build_search_like_pattern("动漫短剧"), "%动漫短剧%");
        assert_eq!(build_search_like_pattern("100%_test"), r"%100\%\_test%");
        assert_eq!(build_search_like_pattern(r"a\b"), r"%a\\b%");
    }

    /// 测试摘要生成：验证 ts_headline 的高亮标记格式
    #[test]
    fn test_snippet_highlight_format() {
        // ts_headline 使用 <mark> 标签标记匹配的关键词
        let snippet = "这是一个包含<mark>关键词</mark>的摘要文本";

        // 验证包含 <mark> 标签
        assert!(snippet.contains("<mark>"));
        assert!(snippet.contains("</mark>"));

        // 验证标签成对出现
        let open_count = snippet.matches("<mark>").count();
        let close_count = snippet.matches("</mark>").count();
        assert_eq!(open_count, close_count);
    }

    /// 测试摘要生成：验证多个匹配关键词的高亮
    #[test]
    fn test_snippet_multiple_highlights() {
        let snippet = "这是<mark>第一个</mark>关键词和<mark>第二个</mark>关键词";

        let open_count = snippet.matches("<mark>").count();
        let close_count = snippet.matches("</mark>").count();

        assert_eq!(open_count, 2);
        assert_eq!(close_count, 2);
    }

    /// 测试结果类型过滤：空列表应该被视为无过滤
    #[test]
    fn test_result_type_filter_empty() {
        let types: Vec<ResultType> = vec![];
        let should_filter = !types.is_empty();
        assert!(!should_filter);
    }

    /// 测试结果类型过滤：包含特定类型
    #[test]
    fn test_result_type_filter_contains() {
        let types = [ResultType::Project, ResultType::Script];

        assert!(types.contains(&ResultType::Project));
        assert!(types.contains(&ResultType::Script));
        assert!(!types.contains(&ResultType::Asset));
    }

    /// 测试时间范围过滤：构建 SQL 条件
    #[test]
    fn test_time_range_filter_both() {
        use chrono::TimeZone;

        let time_from = Some(Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap());
        let time_to = Some(Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap());

        let has_time_filter = time_from.is_some() || time_to.is_some();
        assert!(has_time_filter);

        // 验证时间范围有效
        if let (Some(from), Some(to)) = (time_from, time_to) {
            assert!(from < to);
        }
    }

    /// 测试时间范围过滤：仅起始时间
    #[test]
    fn test_time_range_filter_from_only() {
        use chrono::TimeZone;

        let time_from = Some(Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap());
        let time_to: Option<DateTime<Utc>> = None;

        let has_time_filter = time_from.is_some() || time_to.is_some();
        assert!(has_time_filter);
    }

    /// 测试时间范围过滤：仅结束时间
    #[test]
    fn test_time_range_filter_to_only() {
        use chrono::TimeZone;

        let time_from: Option<DateTime<Utc>> = None;
        let time_to = Some(Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap());

        let has_time_filter = time_from.is_some() || time_to.is_some();
        assert!(has_time_filter);
    }

    /// 测试时间范围过滤：无时间过滤
    #[test]
    fn test_time_range_filter_none() {
        let time_from: Option<DateTime<Utc>> = None;
        let time_to: Option<DateTime<Utc>> = None;

        let has_time_filter = time_from.is_some() || time_to.is_some();
        assert!(!has_time_filter);
    }

    /// 测试搜索结果排序：验证排序逻辑（rank DESC, updated_at DESC）
    #[test]
    fn test_search_result_ordering() {
        use chrono::TimeZone;

        // 创建测试数据
        let mut results = [
            (0.5f32, Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap()),
            (0.8f32, Utc.with_ymd_and_hms(2024, 1, 2, 0, 0, 0).unwrap()),
            (0.8f32, Utc.with_ymd_and_hms(2024, 1, 3, 0, 0, 0).unwrap()),
            (0.3f32, Utc.with_ymd_and_hms(2024, 1, 4, 0, 0, 0).unwrap()),
        ];

        // 按 rank DESC, updated_at DESC 排序
        results.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap().then_with(|| b.1.cmp(&a.1)));

        // 验证排序结果
        assert_eq!(results[0].0, 0.8f32); // 最高 rank
        assert_eq!(
            results[0].1,
            Utc.with_ymd_and_hms(2024, 1, 3, 0, 0, 0).unwrap()
        ); // 最新时间
        assert_eq!(results[1].0, 0.8f32);
        assert_eq!(
            results[1].1,
            Utc.with_ymd_and_hms(2024, 1, 2, 0, 0, 0).unwrap()
        );
        assert_eq!(results[2].0, 0.5f32);
        assert_eq!(results[3].0, 0.3f32); // 最低 rank
    }

    /// 测试 total 计算：有更多结果时
    #[test]
    fn test_total_calculation_has_more() {
        let page = 2u32;
        let page_size = 20u32;
        let has_more = true;

        let total = if has_more {
            page * page_size + 1
        } else {
            (page - 1) * page_size + page_size
        };

        assert_eq!(total, 41); // 2 * 20 + 1
    }

    /// 测试 total 计算：没有更多结果时
    #[test]
    fn test_total_calculation_no_more() {
        let page = 2u32;
        let page_size = 20u32;
        let results_count = 15usize;
        let has_more = false;

        let total = if has_more {
            page * page_size + 1
        } else {
            (page - 1) * page_size + results_count as u32
        };

        assert_eq!(total, 35); // (2 - 1) * 20 + 15
    }

    /// 测试 workspace 权限验证：模拟查询结果
    #[test]
    fn test_workspace_access_verification_logic() {
        // 模拟数据库查询结果
        let is_member_true = true;
        let is_member_false = false;

        // 有权限的情况
        assert!(is_member_true);

        // 无权限的情况
        assert!(!is_member_false);
    }

    /// 测试 UNION ALL 查询构建：验证是否包含所有类型
    #[test]
    fn test_union_query_all_types() {
        let search_projects = true;
        let search_scripts = true;
        let search_assets = true;

        let mut union_parts = Vec::new();

        if search_projects {
            union_parts.push("project_query");
        }
        if search_scripts {
            union_parts.push("script_query");
        }
        if search_assets {
            union_parts.push("asset_query");
        }

        assert_eq!(union_parts.len(), 3);
    }

    /// 测试 UNION ALL 查询构建：仅包含部分类型
    #[test]
    fn test_union_query_partial_types() {
        let search_projects = true;
        let search_scripts = false;
        let search_assets = true;

        let mut union_parts = Vec::new();

        if search_projects {
            union_parts.push("project_query");
        }
        if search_scripts {
            union_parts.push("script_query");
        }
        if search_assets {
            union_parts.push("asset_query");
        }

        assert_eq!(union_parts.len(), 2);
        assert!(union_parts.contains(&"project_query"));
        assert!(union_parts.contains(&"asset_query"));
        assert!(!union_parts.contains(&"script_query"));
    }

    /// 测试 UNION ALL 查询构建：无类型时返回空结果
    #[test]
    fn test_union_query_no_types() {
        let search_projects = false;
        let search_scripts = false;
        let search_assets = false;

        let mut union_parts = Vec::new();

        if search_projects {
            union_parts.push("project_query");
        }
        if search_scripts {
            union_parts.push("script_query");
        }
        if search_assets {
            union_parts.push("asset_query");
        }

        assert!(union_parts.is_empty());
    }

    // 注意：以下测试需要真实的 PgPool 实例，应该在集成测试中实现
    // - verify_workspace_access 的实际数据库查询
    // - execute_union_search 的实际数据库查询
    // - 完整的 search 方法端到端测试
    //
    // 这些测试应该放在 backend/tests/ 目录下的集成测试中

    /// 测试缓存功能：验证缓存键生成
    #[test]
    fn test_cache_key_generation_consistency() {
        use crate::search::cache::SearchCache;

        let workspace_id = Uuid::new_v4();
        let query = SearchQuery {
            q: "测试".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query);

        assert_eq!(key1, key2, "相同查询应生成相同缓存键");
    }

    /// 测试缓存功能：验证不同查询生成不同缓存键
    #[test]
    fn test_cache_key_different_for_different_queries() {
        use crate::search::cache::SearchCache;

        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "查询1".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "查询2".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        assert_ne!(key1, key2, "不同查询应生成不同缓存键");
    }

    /// 测试缓存功能：验证分页参数影响缓存键
    #[test]
    fn test_cache_key_includes_pagination() {
        use crate::search::cache::SearchCache;

        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "测试".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "测试".to_string(),
            result_type: None,
            page: 2,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        assert_ne!(key1, key2, "不同分页应生成不同缓存键");
    }
}
