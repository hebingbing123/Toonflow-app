//! 用户「保存的搜索视图」跨端同步：全量替换 + 按用户查询。

use axum::{extract::State, http::HeaderMap, Json};
use chrono::Utc;
use serde_json::json;
use sqlx::types::Json as SqlxJson;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::{
    auth::require_user_uuid,
    error::{bad_request_i18n, ApiError},
    search::models::{SearchSavedViewItem, SearchSavedViewsPutBody, SearchSavedViewsResponse},
    state::AppState,
};

const MAX_SAVED_VIEWS: usize = 100;

/// 是否为用户在指定工作区的成员（有 `workspace_id` 的保存视图时强制校验，防越权标签）。
async fn user_is_workspace_member(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM public.app_workspace_member
          WHERE workspace_id = $1 AND user_id = $2
        )
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}

fn validate_item(i: usize, item: &SearchSavedViewItem) -> Result<(), ApiError> {
    let id = item.id.trim();
    if id.is_empty() {
        return Err(bad_request_i18n(
            &format!("items[{}].id must not be empty", i),
            &format!("items[{}].id 不能为空", i),
        ));
    }
    if id.len() > 128 {
        return Err(bad_request_i18n(
            &format!("items[{}].id exceeds 128 characters", i),
            &format!("items[{}].id 超过 128 个字符", i),
        ));
    }
    if item.title.len() > 200 {
        return Err(bad_request_i18n(
            &format!("items[{}].title exceeds 200 characters", i),
            &format!("items[{}].title 超过 200 个字符", i),
        ));
    }
    if item.query.len() > 2000 {
        return Err(bad_request_i18n(
            &format!("items[{}].query exceeds 2000 characters", i),
            &format!("items[{}].query 超过 2000 个字符", i),
        ));
    }
    if item.use_count < 0 {
        return Err(bad_request_i18n(
            &format!("items[{}].use_count must be >= 0", i),
            &format!("items[{}].use_count 必须大于等于 0", i),
        ));
    }
    if item.result_types.len() > 32 {
        return Err(bad_request_i18n(
            &format!("items[{}].result_types too many entries (max 32)", i),
            &format!("items[{}].result_types 条目过多（最多 32 个）", i),
        ));
    }
    for (j, wire) in item.result_types.iter().enumerate() {
        if wire.len() > 64 {
            return Err(bad_request_i18n(
                &format!("items[{}].result_types[{}] too long", i, j),
                &format!("items[{}].result_types[{}] 过长", i, j),
            ));
        }
    }
    Ok(())
}

pub async fn fetch_saved_views(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Vec<SearchSavedViewItem>, ApiError> {
    let rows = sqlx::query(
        r#"
        SELECT
          client_view_id,
          workspace_id,
          title,
          query,
          workspace_name,
          pinned,
          result_types,
          time_from,
          time_to,
          use_count,
          last_used_at,
          updated_at,
          created_at
        FROM public.app_user_search_saved_view
        WHERE owner_user_id = $1
        ORDER BY updated_at DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(rows.len());
    for r in rows {
        let client_view_id: String = r
            .try_get("client_view_id")
            .map_err(|e| ApiError::DatabaseError(format!("read client_view_id: {}", e)))?;
        let workspace_id: Option<Uuid> = r.try_get("workspace_id").unwrap_or(None);
        let title: String = r
            .try_get("title")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let query: String = r
            .try_get("query")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let workspace_name: Option<String> = r.try_get("workspace_name").unwrap_or(None);
        let pinned: bool = r
            .try_get("pinned")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let SqlxJson(result_types): SqlxJson<Vec<String>> = r
            .try_get("result_types")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let time_from = r.try_get("time_from").unwrap_or(None);
        let time_to = r.try_get("time_to").unwrap_or(None);
        let use_count: i32 = r
            .try_get("use_count")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let last_used_at = r.try_get("last_used_at").unwrap_or(None);
        let updated_at = r
            .try_get("updated_at")
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let created_at = r.try_get("created_at").unwrap_or(None);

        out.push(SearchSavedViewItem {
            id: client_view_id,
            title,
            query,
            workspace_name,
            workspace_id,
            pinned,
            result_types,
            time_from,
            time_to,
            created_at,
            updated_at,
            last_used_at,
            use_count,
        });
    }

    Ok(out)
}

async fn replace_saved_views_tx(
    pool: &PgPool,
    user_id: Uuid,
    items: Vec<SearchSavedViewItem>,
) -> Result<Vec<SearchSavedViewItem>, ApiError> {
    if items.len() > MAX_SAVED_VIEWS {
        return Err(bad_request_i18n(
            &format!("at most {} saved views allowed", MAX_SAVED_VIEWS),
            &format!("最多允许 {} 个 saved views", MAX_SAVED_VIEWS),
        ));
    }

    let mut seen_ids = std::collections::HashSet::with_capacity(items.len());
    for (i, item) in items.iter().enumerate() {
        validate_item(i, item)?;
        let id = item.id.trim().to_string();
        if !seen_ids.insert(id) {
            return Err(bad_request_i18n(
                "duplicate items[].id in request body",
                "请求体中存在重复的 items[].id",
            ));
        }
        if let Some(ws) = item.workspace_id {
            if !user_is_workspace_member(pool, user_id, ws).await? {
                return Err(ApiError::Forbidden(
                    "saved view references a workspace you are not a member of".into(),
                ));
            }
        }
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("DELETE FROM public.app_user_search_saved_view WHERE owner_user_id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now = Utc::now();
    for item in &items {
        let created_at = item.created_at.unwrap_or(now);
        let rt = serde_json::to_value(&item.result_types).map_err(|e| {
            bad_request_i18n(
                &format!("result_types serialization: {}", e),
                &format!("result_types 序列化失败：{}", e),
            )
        })?;

        sqlx::query(
            r#"
            INSERT INTO public.app_user_search_saved_view (
              owner_user_id,
              client_view_id,
              workspace_id,
              title,
              query,
              workspace_name,
              pinned,
              result_types,
              time_from,
              time_to,
              use_count,
              last_used_at,
              updated_at,
              created_at
            )
            VALUES (
              $1, $2, $3, $4, $5, $6, $7, $8::jsonb,
              $9, $10, $11, $12, $13, $14
            )
            "#,
        )
        .bind(user_id)
        .bind(item.id.trim())
        .bind(item.workspace_id)
        .bind(&item.title)
        .bind(&item.query)
        .bind(&item.workspace_name)
        .bind(item.pinned)
        .bind(rt)
        .bind(item.time_from)
        .bind(item.time_to)
        .bind(item.use_count)
        .bind(item.last_used_at)
        .bind(item.updated_at)
        .bind(created_at)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    let mut sorted_ids: Vec<String> = items.iter().map(|it| it.id.trim().to_string()).collect();
    sorted_ids.sort();
    let audit_details = json!({
        "itemCount": items.len(),
        "clientViewIds": sorted_ids,
    });
    sqlx::query(
        r#"
        INSERT INTO public.app_user_search_saved_view_audit (owner_user_id, action, details)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(user_id)
    .bind("saved_views_put")
    .bind(SqlxJson(audit_details))
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    fetch_saved_views(pool, user_id).await
}

/// `GET /api/v1/search/saved-views`
#[utoipa::path(
    get,
    path = "/api/v1/search/saved-views",
    operation_id = "getSearchSavedViews",
    tag = "search",
    summary = "列出保存的搜索视图",
    description = "返回当前用户跨端同步的保存搜索视图（按 updated_at 降序）。",
    responses(
        (status = 200, description = "OK", body = SearchSavedViewsResponse),
        (status = 401, description = "未认证", body = crate::error::ErrorBody),
        (status = 503, description = "数据库不可用", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub async fn get_search_saved_views(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<SearchSavedViewsResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = fetch_saved_views(pool, user_id).await?;
    Ok(Json(SearchSavedViewsResponse { items }))
}

/// `PUT /api/v1/search/saved-views` — 全量替换当前用户的保存视图。
#[utoipa::path(
    put,
    path = "/api/v1/search/saved-views",
    operation_id = "putSearchSavedViews",
    tag = "search",
    summary = "同步保存的搜索视图",
    description = "以请求体整表替换当前用户的保存视图（上限 100 条）；含 workspace_id 时会校验工作区成员身份。",
    request_body = SearchSavedViewsPutBody,
    responses(
        (status = 200, description = "替换成功，返回持久化后的列表", body = SearchSavedViewsResponse),
        (status = 400, description = "参数错误", body = crate::error::ErrorBody),
        (status = 401, description = "未认证", body = crate::error::ErrorBody),
        (status = 403, description = "无权绑定该工作区", body = crate::error::ErrorBody),
        (status = 503, description = "数据库不可用", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub async fn put_search_saved_views(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SearchSavedViewsPutBody>,
) -> Result<Json<SearchSavedViewsResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let placed = body.items.len();
    let items = replace_saved_views_tx(pool, user_id, body.items).await?;
    tracing::info!(
        target: "toonflow.platform_audit",
        kind = "search_saved_views_full_sync",
        user_id = %user_id,
        requested_count = placed,
        persisted_count = items.len(),
        "saved_views_put_committed"
    );
    Ok(Json(SearchSavedViewsResponse { items }))
}
