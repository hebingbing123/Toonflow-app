//! 搜索 API 路由处理器。

use axum::{
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    routing::{delete, get, put},
    Json, Router,
};

use crate::{
    auth::require_user_uuid,
    error::ApiError,
    search::models::{HistoryResponse, SearchQuery, SearchResponse},
    state::AppState,
};

/// 创建搜索路由
pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/search", get(search_handler))
        .route("/api/v1/search/history", get(get_search_history))
        .route("/api/v1/search/history", delete(delete_search_history))
        .route(
            "/api/v1/search/saved-views",
            get(crate::search::saved_views::get_search_saved_views),
        )
        .route(
            "/api/v1/search/saved-views",
            put(crate::search::saved_views::put_search_saved_views),
        )
}

/// 执行全局搜索
///
/// 搜索跨项目、剧本、资产、小说章节与大纲事件的内容，返回按相关性排序的结果。
/// 仅返回用户在当前 workspace 下有权限访问的内容。
#[utoipa::path(
    get,
    path = "/api/v1/search",
    operation_id = "search",
    tag = "search",
    summary = "全局搜索",
    description = "搜索跨项目、剧本、资产、小说章节（novel）、小说大纲事件（novel_event）的内容，返回按相关性排序的结果",
    params(
        ("q" = String, Query, description = "搜索关键词（必填，2-200 字符）", example = "角色设计"),
        ("result_type" = Option<Vec<String>>, Query, description = "结果类型过滤（可选）：project, script, asset, novel, novel_event；兼容查询参数名 type"),
        ("page" = Option<u32>, Query, description = "页码（默认 1）"),
        ("page_size" = Option<u32>, Query, description = "每页数量（默认 20，最大 100）"),
        ("time_from" = Option<String>, Query, description = "时间范围起始（ISO 8601 格式）"),
        ("time_to" = Option<String>, Query, description = "时间范围结束（ISO 8601 格式）"),
    ),
    responses(
        (status = 200, description = "搜索成功", body = SearchResponse),
        (status = 400, description = "请求参数错误", body = crate::error::ErrorBody),
        (status = 401, description = "未认证", body = crate::error::ErrorBody),
        (status = 403, description = "无权限访问该工作区", body = crate::error::ErrorBody),
        (status = 429, description = "请求过于频繁，已超过速率限制（60 请求/分钟）", body = crate::error::ErrorBody),
        (status = 500, description = "服务器内部错误", body = crate::error::ErrorBody),
    ),
    security(
        ("bearerAuth" = [])
    )
)]
pub async fn search_handler(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<SearchQuery>,
) -> Result<Json<SearchResponse>, ApiError> {
    // 记录搜索开始时间（用于计算响应时间）
    let start_time = std::time::Instant::now();

    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 验证查询参数：q 长度 2-200 字符
    let q = query.q.trim();
    if q.is_empty() || q.len() < 2 {
        return Err(ApiError::BadRequest(
            "搜索关键词不能为空，且至少需要 2 个字符".to_string(),
        ));
    }
    if q.len() > 200 {
        return Err(ApiError::BadRequest(
            "搜索关键词过长，请限制在 200 字符以内".to_string(),
        ));
    }

    // 保存查询字符串用于历史记录和日志
    let query_string = q.to_string();

    // 验证 page_size ≤ 100
    let page_size = query.page_size.min(100);
    if page_size == 0 {
        return Err(ApiError::BadRequest("每页数量必须大于 0".to_string()));
    }

    // 从 JWT 提取 user_id（已完成）和 current_workspace_id
    // 获取用户的 current_workspace_id，如果没有则使用个人 workspace
    use crate::workspaces::ensure_personal_workspace;
    let personal = ensure_personal_workspace(pool, user_id).await?;

    let workspace_id: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT COALESCE(
          (
            SELECT p.current_workspace_id
            FROM public.app_user_profile p
            WHERE p.user_id = $1
              AND p.current_workspace_id IS NOT NULL
              AND EXISTS (
                SELECT 1
                FROM public.app_workspace_member m
                WHERE m.workspace_id = p.current_workspace_id
                  AND m.user_id = $1
              )
            LIMIT 1
          ),
          $2
        ) AS workspace_id
        "#,
    )
    .bind(user_id)
    .bind(personal.workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(format!("获取工作区信息失败: {}", e)))?;

    // 调用 SearchService::search 执行搜索
    use crate::search::service::SearchService;
    let service = SearchService::new(pool.clone());

    // 执行搜索并处理权限错误（用于记录未授权尝试）
    let search_result = service.search(user_id, workspace_id, query.clone()).await;

    // 计算响应时间
    let response_time_ms = start_time.elapsed().as_millis() as i32;

    match search_result {
        Ok(response) => {
            // 搜索成功后自动保存历史记录
            // 注意：保存失败不应影响搜索结果返回
            let _ = crate::search::history::save_search_history(
                pool,
                user_id,
                workspace_id,
                &query_string,
                response.total,
            )
            .await;

            // 记录搜索日志（包括响应时间和结果数）
            use crate::search::logging::{build_filters_json, log_search_request, SearchLogEntry};
            let log_entry = SearchLogEntry {
                user_id,
                workspace_id,
                query: query_string,
                result_count: response.total,
                response_time_ms,
                filters: build_filters_json(&query),
            };

            // 异步记录日志，不阻塞响应
            let _ = log_search_request(pool, log_entry).await;

            Ok(Json(response))
        }
        Err(e) => {
            // 如果是权限错误，记录未授权尝试
            if matches!(e, ApiError::Forbidden(_)) {
                use crate::search::logging::log_unauthorized_search_attempt;
                let _ = log_unauthorized_search_attempt(pool, user_id, workspace_id, &query_string)
                    .await;
            }

            // 即使搜索失败，也记录日志（用于错误分析）
            use crate::search::logging::{build_filters_json, log_search_request, SearchLogEntry};
            let log_entry = SearchLogEntry {
                user_id,
                workspace_id,
                query: query_string,
                result_count: 0,
                response_time_ms,
                filters: build_filters_json(&query),
            };
            let _ = log_search_request(pool, log_entry).await;

            Err(e)
        }
    }
}

/// 获取搜索历史
///
/// 返回当前用户最近的搜索历史记录（最多 10 条）。
#[utoipa::path(
    get,
    path = "/api/v1/search/history",
    operation_id = "getSearchHistory",
    tag = "search",
    summary = "获取搜索历史",
    description = "返回当前用户最近的搜索历史记录（最多 10 条）",
    responses(
        (status = 200, description = "获取成功", body = HistoryResponse),
        (status = 401, description = "未认证", body = crate::error::ErrorBody),
        (status = 429, description = "请求过于频繁，已超过速率限制", body = crate::error::ErrorBody),
        (status = 500, description = "服务器内部错误", body = crate::error::ErrorBody),
    ),
    security(
        ("bearerAuth" = [])
    )
)]
pub async fn get_search_history(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HistoryResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let response = crate::search::history::get_search_history(pool, user_id).await?;

    Ok(Json(response))
}

/// 删除搜索历史
///
/// 删除当前用户的所有搜索历史记录。
#[utoipa::path(
    delete,
    path = "/api/v1/search/history",
    operation_id = "deleteSearchHistory",
    tag = "search",
    summary = "删除搜索历史",
    description = "删除当前用户的所有搜索历史记录",
    responses(
        (status = 204, description = "删除成功"),
        (status = 401, description = "未认证", body = crate::error::ErrorBody),
        (status = 429, description = "请求过于频繁，已超过速率限制", body = crate::error::ErrorBody),
        (status = 500, description = "服务器内部错误", body = crate::error::ErrorBody),
    ),
    security(
        ("bearerAuth" = [])
    )
)]
pub async fn delete_search_history(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    crate::search::history::delete_search_history(pool, user_id).await?;

    Ok(StatusCode::NO_CONTENT)
}
