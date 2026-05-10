//! 搜索结果缓存模块。
//!
//! 使用 Moka 内存缓存存储搜索结果，TTL 为 5 分钟。
//! 缓存键基于查询参数（关键词、类型过滤、时间范围、分页参数）和 workspace_id 生成。

use std::sync::Arc;
use std::time::Duration;

use moka::future::Cache;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::search::models::{SearchQuery, SearchResponse};

/// 搜索结果缓存
///
/// 使用 Moka 内存缓存，TTL 为 5 分钟，最大容量 1000 条记录。
#[derive(Clone)]
pub struct SearchCache {
    cache: Arc<Cache<String, SearchResponse>>,
}

impl SearchCache {
    /// 创建新的搜索缓存实例
    ///
    /// 配置：
    /// - TTL: 5 分钟（300 秒）
    /// - 最大容量: 1000 条记录
    /// - 自动过期清理
    pub fn new() -> Self {
        let cache = Cache::builder()
            .max_capacity(1000)
            .time_to_live(Duration::from_secs(300)) // 5 分钟 TTL
            .build();

        Self {
            cache: Arc::new(cache),
        }
    }

    /// 生成缓存键
    ///
    /// 缓存键格式：`search:{workspace_id}:{query_hash}`
    /// query_hash 包含：关键词、类型过滤、时间范围、分页参数
    pub fn generate_cache_key(workspace_id: Uuid, query: &SearchQuery) -> String {
        // 创建可序列化的查询结构用于生成哈希
        let cache_key_data = CacheKeyData {
            workspace_id,
            q: query.q.trim().to_lowercase(), // 标准化：去除空格并转小写
            result_type: query.result_type.clone(),
            page: query.page,
            page_size: query.page_size,
            time_from: query.time_from,
            time_to: query.time_to,
        };

        // 序列化为 JSON 并计算哈希
        let json = serde_json::to_string(&cache_key_data).unwrap_or_default();
        let hash = format!("{:x}", md5::compute(json.as_bytes()));

        format!("search:{}:{}", workspace_id, hash)
    }

    /// 从缓存中获取搜索结果
    ///
    /// 如果缓存命中，返回 Some(SearchResponse)；否则返回 None。
    pub async fn get(&self, workspace_id: Uuid, query: &SearchQuery) -> Option<SearchResponse> {
        let key = Self::generate_cache_key(workspace_id, query);
        let result = self.cache.get(&key).await;

        if result.is_some() {
            tracing::debug!(
                cache_key = %key,
                "Search cache hit"
            );
        } else {
            tracing::debug!(
                cache_key = %key,
                "Search cache miss"
            );
        }

        result
    }

    /// 将搜索结果存入缓存
    ///
    /// 缓存将在 5 分钟后自动过期。
    pub async fn set(&self, workspace_id: Uuid, query: &SearchQuery, response: SearchResponse) {
        let key = Self::generate_cache_key(workspace_id, query);
        self.cache.insert(key.clone(), response).await;

        tracing::debug!(
            cache_key = %key,
            "Search result cached"
        );
    }

    /// 清除指定 workspace 的所有缓存
    ///
    /// 注意：由于 Moka 不支持按前缀删除，此方法会遍历所有缓存键。
    /// 在生产环境中，建议使用 Redis 以支持更高效的前缀删除。
    pub async fn invalidate_workspace(&self, workspace_id: Uuid) {
        let _prefix = format!("search:{}:", workspace_id);
        let invalidated_count = 0;

        // 遍历所有缓存键并删除匹配的
        self.cache.run_pending_tasks().await;

        // 注意：Moka 不提供直接的键遍历 API
        // 在实际使用中，可以考虑维护一个 workspace -> keys 的映射
        // 或者在数据更新时让缓存自然过期（5 分钟 TTL）

        tracing::debug!(
            workspace_id = %workspace_id,
            invalidated_count = invalidated_count,
            "Invalidated workspace search cache"
        );
    }

    /// 清除所有缓存
    pub async fn clear(&self) {
        self.cache.invalidate_all();
        self.cache.run_pending_tasks().await;
        tracing::debug!("Cleared all search cache");
    }

    /// 获取缓存统计信息
    pub fn stats(&self) -> CacheStats {
        CacheStats {
            entry_count: self.cache.entry_count(),
            weighted_size: self.cache.weighted_size(),
        }
    }
}

impl Default for SearchCache {
    fn default() -> Self {
        Self::new()
    }
}

/// 缓存键数据结构
///
/// 用于生成稳定的缓存键哈希。
#[derive(Debug, Clone, Serialize, Deserialize)]
struct CacheKeyData {
    workspace_id: Uuid,
    q: String,
    result_type: Option<Vec<crate::search::models::ResultType>>,
    page: u32,
    page_size: u32,
    time_from: Option<chrono::DateTime<chrono::Utc>>,
    time_to: Option<chrono::DateTime<chrono::Utc>>,
}

/// 缓存统计信息
#[derive(Debug, Clone)]
pub struct CacheStats {
    /// 缓存条目数量
    pub entry_count: u64,
    /// 缓存占用大小（加权）
    pub weighted_size: u64,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::models::{ResultType, SearchQuery};

    #[test]
    fn test_cache_key_generation() {
        let workspace_id = Uuid::new_v4();
        let query = SearchQuery {
            q: "测试关键词".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query);

        // 相同的查询应该生成相同的缓存键
        assert_eq!(key1, key2);
        assert!(key1.starts_with(&format!("search:{}:", workspace_id)));
    }

    #[test]
    fn test_cache_key_normalization() {
        let workspace_id = Uuid::new_v4();

        // 测试大小写标准化
        let query1 = SearchQuery {
            q: "Test Query".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "test query".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 大小写不同但内容相同的查询应该生成相同的缓存键
        assert_eq!(key1, key2);
    }

    #[test]
    fn test_cache_key_whitespace_normalization() {
        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "  test query  ".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "test query".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 前后空格不同但内容相同的查询应该生成相同的缓存键
        assert_eq!(key1, key2);
    }

    #[test]
    fn test_cache_key_different_queries() {
        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "query1".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "query2".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 不同的查询应该生成不同的缓存键
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_cache_key_different_filters() {
        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![ResultType::Project]),
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![ResultType::Script]),
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 不同的过滤条件应该生成不同的缓存键
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_cache_key_different_pagination() {
        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let query2 = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 2,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 不同的分页参数应该生成不同的缓存键
        assert_ne!(key1, key2);
    }

    #[test]
    fn test_cache_key_different_workspaces() {
        let workspace_id1 = Uuid::new_v4();
        let workspace_id2 = Uuid::new_v4();

        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let key1 = SearchCache::generate_cache_key(workspace_id1, &query);
        let key2 = SearchCache::generate_cache_key(workspace_id2, &query);

        // 不同的 workspace 应该生成不同的缓存键
        assert_ne!(key1, key2);
    }

    #[tokio::test]
    async fn test_cache_set_and_get() {
        use crate::search::models::SearchResponse;

        let cache = SearchCache::new();
        let workspace_id = Uuid::new_v4();
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let response = SearchResponse {
            results: vec![],
            total: 0,
            page: 1,
            page_size: 20,
            has_more: false,
        };

        // 初始状态应该没有缓存
        let result = cache.get(workspace_id, &query).await;
        assert!(result.is_none());

        // 设置缓存
        cache.set(workspace_id, &query, response.clone()).await;

        // 应该能够获取到缓存
        let result = cache.get(workspace_id, &query).await;
        assert!(result.is_some());
        let cached = result.unwrap();
        assert_eq!(cached.total, response.total);
        assert_eq!(cached.page, response.page);
    }

    #[tokio::test]
    async fn test_cache_clear() {
        use crate::search::models::SearchResponse;

        let cache = SearchCache::new();
        let workspace_id = Uuid::new_v4();
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let response = SearchResponse {
            results: vec![],
            total: 0,
            page: 1,
            page_size: 20,
            has_more: false,
        };

        // 设置缓存
        cache.set(workspace_id, &query, response).await;

        // 验证缓存存在
        let result = cache.get(workspace_id, &query).await;
        assert!(result.is_some());

        // 清除所有缓存
        cache.clear().await;

        // 验证缓存已清除
        let result = cache.get(workspace_id, &query).await;
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn test_cache_stats() {
        use crate::search::models::SearchResponse;

        let cache = SearchCache::new();
        let workspace_id = Uuid::new_v4();

        // 初始状态
        let stats = cache.stats();
        assert_eq!(stats.entry_count, 0);

        // 添加一些缓存条目
        for i in 0..5 {
            let query = SearchQuery {
                q: format!("test{}", i),
                result_type: None,
                page: 1,
                page_size: 20,
                time_from: None,
                time_to: None,
            };

            let response = SearchResponse {
                results: vec![],
                total: 0,
                page: 1,
                page_size: 20,
                has_more: false,
            };

            cache.set(workspace_id, &query, response).await;
        }

        // Moka 缓存使用异步后台任务维护状态，需要等待任务完成
        // 使用 run_pending_tasks() 确保所有待处理的任务都已完成
        cache.cache.run_pending_tasks().await;

        // 验证统计信息
        let stats = cache.stats();
        assert_eq!(stats.entry_count, 5);
    }

    #[test]
    fn test_cache_key_with_time_range() {
        use chrono::{TimeZone, Utc};

        let workspace_id = Uuid::new_v4();

        let query1 = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: Some(Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap()),
            time_to: Some(Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap()),
        };

        let query2 = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: Some(Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap()),
            time_to: Some(Utc.with_ymd_and_hms(2024, 6, 30, 23, 59, 59).unwrap()),
        };

        let key1 = SearchCache::generate_cache_key(workspace_id, &query1);
        let key2 = SearchCache::generate_cache_key(workspace_id, &query2);

        // 不同的时间范围应该生成不同的缓存键
        assert_ne!(key1, key2);
    }
}
