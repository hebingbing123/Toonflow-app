//! 搜索数据模型和错误类型。
//!
//! 定义全局搜索功能的请求、响应和错误类型。

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

/// 搜索查询请求参数
#[derive(Debug, Clone, Deserialize, ToSchema)]
pub struct SearchQuery {
    /// 搜索关键词（必填，2-200 字符）
    #[schema(example = "项目名称")]
    pub q: String,

    /// 结果类型过滤（可选，可多选）；兼容查询参数名 `type`（Flutter 客户端历史用法）
    #[serde(default, alias = "type")]
    pub result_type: Option<Vec<ResultType>>,

    /// 页码（默认 1）
    #[serde(default = "default_page")]
    pub page: u32,

    /// 每页数量（默认 20，最大 100）
    #[serde(default = "default_page_size")]
    pub page_size: u32,

    /// 时间范围起始（可选）
    pub time_from: Option<DateTime<Utc>>,

    /// 时间范围结束（可选）
    pub time_to: Option<DateTime<Utc>>,
}

fn default_page() -> u32 {
    1
}

fn default_page_size() -> u32 {
    20
}

/// 搜索响应
#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct SearchResponse {
    /// 搜索结果列表
    pub results: Vec<SearchResult>,

    /// 结果总数
    pub total: u32,

    /// 当前页码
    pub page: u32,

    /// 每页数量
    pub page_size: u32,

    /// 是否有更多结果
    pub has_more: bool,
}

/// 单条搜索结果
#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct SearchResult {
    /// 结果 ID
    pub id: Uuid,

    /// 结果类型
    pub result_type: ResultType,

    /// 标题/名称
    pub title: String,

    /// 包含高亮标记的摘要（使用 <mark> 标签）
    pub snippet: String,

    /// 相关性评分（ts_rank 计算）
    pub rank: f32,

    /// 创建时间
    pub created_at: DateTime<Utc>,

    /// 更新时间
    pub updated_at: DateTime<Utc>,

    /// 类型特定的额外信息（如项目 ID、项目名称等）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<serde_json::Value>,
}

/// 搜索结果类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum ResultType {
    /// 项目
    Project,
    /// 剧本
    Script,
    /// 资产
    Asset,
    /// 小说章节（`app_novel`）
    Novel,
    /// 小说大纲事件（`app_novel_event`）
    #[serde(rename = "novel_event")]
    NovelEvent,
}

impl ResultType {
    /// 将结果类型转换为字符串（用于数据库查询）
    pub fn as_str(&self) -> &'static str {
        match self {
            ResultType::Project => "project",
            ResultType::Script => "script",
            ResultType::Asset => "asset",
            ResultType::Novel => "novel",
            ResultType::NovelEvent => "novel_event",
        }
    }
}

/// 搜索历史条目
#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct HistoryEntry {
    /// 历史记录 ID
    pub id: Uuid,

    /// 搜索关键词
    pub query: String,

    /// 结果数量
    pub result_count: u32,

    /// 搜索时间
    pub searched_at: DateTime<Utc>,
}

/// 搜索历史响应
#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct HistoryResponse {
    /// 历史记录列表
    pub history: Vec<HistoryEntry>,
}

/// 搜索错误类型
#[derive(Debug)]
pub enum SearchError {
    /// 无效的查询参数（如空查询、超长查询等）
    InvalidQuery(String),

    /// 权限被拒绝（用户无权访问该 workspace）
    PermissionDenied(String),

    /// 数据库错误
    DatabaseError(sqlx::Error),

    /// 内部错误
    Internal(String),
}

impl std::fmt::Display for SearchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SearchError::InvalidQuery(msg) => write!(f, "Invalid query: {}", msg),
            SearchError::PermissionDenied(msg) => write!(f, "Permission denied: {}", msg),
            SearchError::DatabaseError(e) => write!(f, "Database error: {}", e),
            SearchError::Internal(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl std::error::Error for SearchError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            SearchError::DatabaseError(e) => Some(e),
            _ => None,
        }
    }
}

impl From<sqlx::Error> for SearchError {
    fn from(err: sqlx::Error) -> Self {
        SearchError::DatabaseError(err)
    }
}

impl From<SearchError> for crate::error::ApiError {
    fn from(err: SearchError) -> Self {
        match err {
            SearchError::InvalidQuery(msg) => crate::error::ApiError::BadRequest(msg),
            SearchError::PermissionDenied(msg) => crate::error::ApiError::Forbidden(msg),
            SearchError::DatabaseError(e) => {
                crate::error::ApiError::DatabaseError(format!("搜索服务暂时不可用: {}", e))
            }
            SearchError::Internal(msg) => {
                tracing::error!("Search internal error: {}", msg);
                crate::error::ApiError::Internal
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_result_type_as_str() {
        assert_eq!(ResultType::Project.as_str(), "project");
        assert_eq!(ResultType::Script.as_str(), "script");
        assert_eq!(ResultType::Asset.as_str(), "asset");
        assert_eq!(ResultType::Novel.as_str(), "novel");
        assert_eq!(ResultType::NovelEvent.as_str(), "novel_event");
    }

    #[test]
    fn test_result_type_serialization() {
        let project = ResultType::Project;
        let json = serde_json::to_string(&project).unwrap();
        assert_eq!(json, r#""project""#);

        let script = ResultType::Script;
        let json = serde_json::to_string(&script).unwrap();
        assert_eq!(json, r#""script""#);

        let asset = ResultType::Asset;
        let json = serde_json::to_string(&asset).unwrap();
        assert_eq!(json, r#""asset""#);

        let novel = ResultType::Novel;
        let json = serde_json::to_string(&novel).unwrap();
        assert_eq!(json, r#""novel""#);

        let ev = ResultType::NovelEvent;
        let json = serde_json::to_string(&ev).unwrap();
        assert_eq!(json, r#""novel_event""#);
    }

    #[test]
    fn test_result_type_deserialization() {
        let project: ResultType = serde_json::from_str(r#""project""#).unwrap();
        assert_eq!(project, ResultType::Project);

        let script: ResultType = serde_json::from_str(r#""script""#).unwrap();
        assert_eq!(script, ResultType::Script);

        let asset: ResultType = serde_json::from_str(r#""asset""#).unwrap();
        assert_eq!(asset, ResultType::Asset);

        let novel: ResultType = serde_json::from_str(r#""novel""#).unwrap();
        assert_eq!(novel, ResultType::Novel);

        let ev: ResultType = serde_json::from_str(r#""novel_event""#).unwrap();
        assert_eq!(ev, ResultType::NovelEvent);
    }

    #[test]
    fn test_search_query_defaults() {
        let json = r#"{"q":"test"}"#;
        let query: SearchQuery = serde_json::from_str(json).unwrap();
        assert_eq!(query.q, "test");
        assert_eq!(query.page, 1);
        assert_eq!(query.page_size, 20);
        assert!(query.result_type.is_none());
        assert!(query.time_from.is_none());
        assert!(query.time_to.is_none());
    }

    #[test]
    fn test_search_query_with_filters() {
        let json = r#"{
            "q": "test",
            "result_type": ["project", "script"],
            "page": 2,
            "page_size": 50,
            "time_from": "2024-01-01T00:00:00Z",
            "time_to": "2024-12-31T23:59:59Z"
        }"#;
        let query: SearchQuery = serde_json::from_str(json).unwrap();
        assert_eq!(query.q, "test");
        assert_eq!(query.page, 2);
        assert_eq!(query.page_size, 50);
        assert_eq!(
            query.result_type,
            Some(vec![ResultType::Project, ResultType::Script])
        );
        assert!(query.time_from.is_some());
        assert!(query.time_to.is_some());
    }

    #[test]
    fn test_search_error_to_api_error() {
        let err = SearchError::InvalidQuery("Query too short".to_string());
        let api_err: crate::error::ApiError = err.into();
        match api_err {
            crate::error::ApiError::BadRequest(msg) => {
                assert_eq!(msg, "Query too short");
            }
            _ => panic!("Expected BadRequest"),
        }

        let err = SearchError::PermissionDenied("No access to workspace".to_string());
        let api_err: crate::error::ApiError = err.into();
        match api_err {
            crate::error::ApiError::Forbidden(msg) => {
                assert_eq!(msg, "No access to workspace");
            }
            _ => panic!("Expected Forbidden"),
        }
    }

    #[test]
    fn test_search_response_serialization() {
        let response = SearchResponse {
            results: vec![],
            total: 0,
            page: 1,
            page_size: 20,
            has_more: false,
        };
        let json = serde_json::to_string(&response).unwrap();
        assert!(json.contains(r#""total":0"#));
        assert!(json.contains(r#""page":1"#));
        assert!(json.contains(r#""page_size":20"#));
        assert!(json.contains(r#""has_more":false"#));
    }
}
