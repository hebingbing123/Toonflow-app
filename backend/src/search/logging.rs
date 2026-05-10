//! 搜索日志记录功能。
//!
//! 负责记录搜索请求的详细信息，包括关键词、用户、workspace、结果数、响应时间等。
//! 用于性能监控和搜索行为分析。

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::search::models::SearchQuery;

/// 搜索日志条目
#[derive(Debug, Clone)]
pub struct SearchLogEntry {
    /// 用户 ID
    pub user_id: Uuid,
    /// 工作区 ID
    pub workspace_id: Uuid,
    /// 搜索关键词
    pub query: String,
    /// 结果数量
    pub result_count: u32,
    /// 响应时间（毫秒）
    pub response_time_ms: i32,
    /// 过滤条件（JSON）
    pub filters: Option<serde_json::Value>,
}

/// 记录搜索请求日志
///
/// 将搜索请求的详细信息保存到 app_search_log 表,用于性能监控和分析。
/// 如果响应时间超过 1 秒，会自动标记为慢查询。
///
/// # 参数
/// - `pool`: 数据库连接池
/// - `entry`: 搜索日志条目
///
/// # 返回
/// - `Ok(())`: 日志记录成功
/// - `Err(sqlx::Error)`: 数据库错误
///
/// # 注意
/// 此函数不应阻塞主业务流程。如果日志记录失败，应该记录错误但不影响搜索结果返回。
pub async fn log_search_request(pool: &PgPool, entry: SearchLogEntry) -> Result<(), sqlx::Error> {
    // 如果是慢查询（>1 秒），记录警告日志
    let is_slow = entry.response_time_ms > 1000;
    if is_slow {
        tracing::warn!(
            user_id = %entry.user_id,
            workspace_id = %entry.workspace_id,
            query = %entry.query,
            response_time_ms = entry.response_time_ms,
            "Slow search query detected (>1s)"
        );
    }

    sqlx::query(
        r#"
        INSERT INTO public.app_search_log (
            user_id,
            workspace_id,
            query,
            result_count,
            response_time_ms,
            filters
        ) VALUES ($1, $2, $3, $4, $5, $6)
        "#,
    )
    .bind(entry.user_id)
    .bind(entry.workspace_id)
    .bind(entry.query)
    .bind(entry.result_count as i32)
    .bind(entry.response_time_ms)
    .bind(entry.filters)
    .execute(pool)
    .await?;

    Ok(())
}

/// 从 SearchQuery 构建过滤条件 JSON
///
/// 将搜索查询中的过滤条件转换为 JSON 格式，用于日志记录。
pub fn build_filters_json(query: &SearchQuery) -> Option<serde_json::Value> {
    let mut filters = serde_json::Map::new();

    // 结果类型过滤
    if let Some(ref types) = query.result_type {
        if !types.is_empty() {
            let type_strings: Vec<String> = types.iter().map(|t| t.as_str().to_string()).collect();
            filters.insert("result_type".to_string(), json!(type_strings));
        }
    }

    // 时间范围过滤
    if let Some(time_from) = query.time_from {
        filters.insert("time_from".to_string(), json!(time_from.to_rfc3339()));
    }
    if let Some(time_to) = query.time_to {
        filters.insert("time_to".to_string(), json!(time_to.to_rfc3339()));
    }

    // 分页参数
    filters.insert("page".to_string(), json!(query.page));
    filters.insert("page_size".to_string(), json!(query.page_size));

    Some(serde_json::Value::Object(filters))
}

/// 记录未授权的搜索尝试
///
/// 当用户尝试搜索无权访问的 workspace 时，记录此事件用于安全审计。
///
/// # 参数
/// - `pool`: 数据库连接池
/// - `user_id`: 用户 ID
/// - `workspace_id`: 尝试访问的 workspace ID
/// - `query`: 搜索关键词
pub async fn log_unauthorized_search_attempt(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    query: &str,
) -> Result<(), sqlx::Error> {
    // 记录到应用日志
    tracing::warn!(
        user_id = %user_id,
        workspace_id = %workspace_id,
        query = %query,
        "Unauthorized search attempt: user tried to search in workspace without access"
    );

    // 可选：记录到数据库审计表（如果有的话）
    // 这里我们使用 app_search_log 表，但标记为 0 结果和 0 响应时间
    // 并在 filters 中添加 unauthorized 标记
    let filters = json!({
        "unauthorized": true,
        "reason": "user_not_member_of_workspace"
    });

    let query_str = query.to_string(); // 克隆 query 以避免借用问题

    sqlx::query(
        r#"
        INSERT INTO public.app_search_log (
            user_id,
            workspace_id,
            query,
            result_count,
            response_time_ms,
            filters
        ) VALUES ($1, $2, $3, 0, 0, $4)
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(query_str)
    .bind(filters)
    .execute(pool)
    .await?;

    Ok(())
}

/// 获取慢查询统计信息
///
/// 返回指定时间范围内的慢查询统计数据。
///
/// # 参数
/// - `pool`: 数据库连接池
/// - `hours`: 时间范围（小时数，默认 24）
///
/// # 返回
/// - `total_slow_queries`: 慢查询总数
/// - `avg_response_time_ms`: 平均响应时间（毫秒）
/// - `max_response_time_ms`: 最大响应时间（毫秒）
/// - `most_common_slow_query`: 最常见的慢查询关键词
pub async fn get_slow_query_stats(
    pool: &PgPool,
    hours: i32,
) -> Result<SlowQueryStats, sqlx::Error> {
    use sqlx::Row;

    let row = sqlx::query(
        r#"
        SELECT * FROM public.get_slow_query_stats($1)
        "#,
    )
    .bind(hours)
    .fetch_one(pool)
    .await?;

    Ok(SlowQueryStats {
        total_slow_queries: row.try_get("total_slow_queries")?,
        avg_response_time_ms: row.try_get("avg_response_time_ms")?,
        max_response_time_ms: row.try_get("max_response_time_ms")?,
        most_common_slow_query: row.try_get("most_common_slow_query")?,
    })
}

/// 慢查询统计信息
#[derive(Debug, Clone)]
pub struct SlowQueryStats {
    /// 慢查询总数
    pub total_slow_queries: i64,
    /// 平均响应时间（毫秒）
    pub avg_response_time_ms: Option<f64>,
    /// 最大响应时间（毫秒）
    pub max_response_time_ms: Option<i32>,
    /// 最常见的慢查询关键词
    pub most_common_slow_query: Option<String>,
}

/// 获取搜索分析数据
///
/// 返回指定 workspace 和时间范围内的搜索分析数据。
///
/// # 参数
/// - `pool`: 数据库连接池
/// - `workspace_id`: 工作区 ID（可选，None 表示所有 workspace）
/// - `hours`: 时间范围（小时数，默认 24）
pub async fn get_search_analytics(
    pool: &PgPool,
    workspace_id: Option<Uuid>,
    hours: i32,
) -> Result<SearchAnalytics, sqlx::Error> {
    use sqlx::Row;

    let row = sqlx::query(
        r#"
        SELECT * FROM public.get_search_analytics($1, $2)
        "#,
    )
    .bind(workspace_id)
    .bind(hours)
    .fetch_one(pool)
    .await?;

    Ok(SearchAnalytics {
        total_searches: row.try_get("total_searches")?,
        unique_users: row.try_get("unique_users")?,
        avg_response_time_ms: row.try_get("avg_response_time_ms")?,
        slow_query_rate: row.try_get("slow_query_rate")?,
        avg_results_per_search: row.try_get("avg_results_per_search")?,
        top_queries: row.try_get("top_queries")?,
    })
}

/// 搜索分析数据
#[derive(Debug, Clone)]
pub struct SearchAnalytics {
    /// 搜索总数
    pub total_searches: i64,
    /// 唯一用户数
    pub unique_users: i64,
    /// 平均响应时间（毫秒）
    pub avg_response_time_ms: Option<f64>,
    /// 慢查询率（百分比）
    pub slow_query_rate: Option<f64>,
    /// 平均每次搜索的结果数
    pub avg_results_per_search: Option<f64>,
    /// 热门搜索关键词（前 10）
    pub top_queries: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::search::models::ResultType;
    use chrono::Utc;

    #[test]
    fn test_build_filters_json_empty() {
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert_eq!(filters_obj["page"], json!(1));
        assert_eq!(filters_obj["page_size"], json!(20));
    }

    #[test]
    fn test_build_filters_json_with_types() {
        let query = SearchQuery {
            q: "test".to_string(),
            result_type: Some(vec![ResultType::Project, ResultType::Script]),
            page: 1,
            page_size: 20,
            time_from: None,
            time_to: None,
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert_eq!(filters_obj["result_type"], json!(["project", "script"]));
    }

    #[test]
    fn test_build_filters_json_with_time_range() {
        use chrono::TimeZone;

        let time_from = Utc.with_ymd_and_hms(2024, 1, 1, 0, 0, 0).unwrap();
        let time_to = Utc.with_ymd_and_hms(2024, 12, 31, 23, 59, 59).unwrap();

        let query = SearchQuery {
            q: "test".to_string(),
            result_type: None,
            page: 1,
            page_size: 20,
            time_from: Some(time_from),
            time_to: Some(time_to),
        };

        let filters = build_filters_json(&query);
        assert!(filters.is_some());

        let filters_obj = filters.unwrap();
        assert!(filters_obj["time_from"].is_string());
        assert!(filters_obj["time_to"].is_string());
    }

    #[test]
    fn test_search_log_entry_creation() {
        let entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test query".to_string(),
            result_count: 10,
            response_time_ms: 500,
            filters: Some(json!({"page": 1})),
        };

        assert_eq!(entry.query, "test query");
        assert_eq!(entry.result_count, 10);
        assert_eq!(entry.response_time_ms, 500);
        assert!(entry.filters.is_some());
    }

    #[test]
    fn test_slow_query_detection() {
        // 正常查询
        let normal_entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 10,
            response_time_ms: 500,
            filters: None,
        };
        assert!(normal_entry.response_time_ms <= 1000);

        // 慢查询
        let slow_entry = SearchLogEntry {
            user_id: Uuid::new_v4(),
            workspace_id: Uuid::new_v4(),
            query: "test".to_string(),
            result_count: 10,
            response_time_ms: 1500,
            filters: None,
        };
        assert!(slow_entry.response_time_ms > 1000);
    }
}
