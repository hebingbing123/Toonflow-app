use axum::{
    extract::State,
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::helpers::forbidden_i18n;
use crate::error::ApiError;
use crate::state::AppState;
use crate::workspaces::ensure_personal_workspace;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct HelpHubLinkItem {
    pub id: String,
    pub title: String,
    pub url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct HelpHubLinksResponse {
    pub items: Vec<HelpHubLinkItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct HelpHubConfigResponse {
    pub workspace_id: Uuid,
    pub can_manage_workspace: bool,
    pub env_items: Vec<HelpHubLinkItem>,
    pub workspace_items: Vec<HelpHubLinkItem>,
    pub user_items: Vec<HelpHubLinkItem>,
    pub effective_items: Vec<HelpHubLinkItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct UpsertHelpHubLinksBody {
    pub items: Vec<HelpHubLinkItem>,
}

#[derive(Debug, Clone, FromRow)]
struct HelpHubLinkRow {
    link_id: String,
    title: String,
    url: String,
    #[allow(dead_code)]
    sort_order: i32,
}

fn parse_env_items() -> Vec<HelpHubLinkItem> {
    if let Ok(raw) = std::env::var("TOONFLOW_HELP_HUB_ITEMS_JSON") {
        if let Ok(v) = serde_json::from_str::<Vec<HelpHubLinkItem>>(&raw) {
            if !v.is_empty() {
                return v;
            }
        }
    }

    let url = std::env::var("TOONFLOW_HELP_HUB_URL")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "https://docs.toonflow.ai".to_string());

    vec![HelpHubLinkItem {
        id: "docs".to_string(),
        title: "Toonflow 文档".to_string(),
        url,
    }]
}

async fn resolve_current_workspace(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<(Uuid, bool), ApiError> {
    let personal = ensure_personal_workspace(pool, uid).await?;
    let current_workspace_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();

    let resolved = if let Some(ws_id) = current_workspace_id {
        let row: Option<(Uuid, String, String)> = sqlx::query_as(
            r#"
            SELECT w.id, w.workspace_type::text, m.role
            FROM public.app_workspace w
            INNER JOIN public.app_workspace_member m ON m.workspace_id = w.id
            WHERE w.id = $1
              AND m.user_id = $2
              AND w.archived_at IS NULL
            LIMIT 1
            "#,
        )
        .bind(ws_id)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        row.map(|(id, workspace_type, role)| {
            let can_manage =
                workspace_type == "enterprise" && matches!(role.as_str(), "owner" | "admin");
            (id, can_manage)
        })
    } else {
        None
    };
    Ok(resolved.unwrap_or((personal.workspace_id, true)))
}

async fn load_scope_links(
    pool: &sqlx::PgPool,
    scope: &str,
    workspace_id: Option<Uuid>,
    user_id: Option<Uuid>,
) -> Result<Vec<HelpHubLinkItem>, ApiError> {
    let rows: Vec<HelpHubLinkRow> = sqlx::query_as(
        r#"
        SELECT link_id, title, url, sort_order
        FROM app_help_hub_link
        WHERE scope = $1
          AND ($2::uuid IS NULL OR workspace_id = $2)
          AND ($3::uuid IS NULL OR user_id = $3)
        ORDER BY sort_order ASC, created_at ASC
        "#,
    )
    .bind(scope)
    .bind(workspace_id)
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows
        .into_iter()
        .map(|r| HelpHubLinkItem {
            id: r.link_id,
            title: r.title,
            url: r.url,
        })
        .collect())
}

fn build_effective(
    env_items: &[HelpHubLinkItem],
    workspace_items: &[HelpHubLinkItem],
    user_items: &[HelpHubLinkItem],
) -> Vec<HelpHubLinkItem> {
    // priority: user overrides > workspace overrides > env defaults
    use std::collections::BTreeMap;
    let mut map: BTreeMap<String, HelpHubLinkItem> = BTreeMap::new();
    for item in env_items.iter().chain(workspace_items).chain(user_items) {
        map.insert(item.id.clone(), item.clone());
    }
    map.into_values().collect()
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/help/hub",
    operation_id = "getSettingsHelpHubLinksV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = HelpHubLinksResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_help_hub_links(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HelpHubLinksResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, _can_manage_workspace) = resolve_current_workspace(pool, uid).await?;
    let env_items = parse_env_items();
    let workspace_items = load_scope_links(pool, "workspace", Some(workspace_id), None).await?;
    let user_items = load_scope_links(pool, "user", None, Some(uid)).await?;
    Ok(Json(HelpHubLinksResponse {
        items: build_effective(&env_items, &workspace_items, &user_items),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/help/hub/config",
    operation_id = "getSettingsHelpHubConfigV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = HelpHubConfigResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_help_hub_config(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HelpHubConfigResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage_workspace) = resolve_current_workspace(pool, uid).await?;
    let env_items = parse_env_items();
    let workspace_items = load_scope_links(pool, "workspace", Some(workspace_id), None).await?;
    let user_items = load_scope_links(pool, "user", None, Some(uid)).await?;
    let effective_items = build_effective(&env_items, &workspace_items, &user_items);
    Ok(Json(HelpHubConfigResponse {
        workspace_id,
        can_manage_workspace,
        env_items,
        workspace_items,
        user_items,
        effective_items,
    }))
}

async fn replace_links(
    pool: &sqlx::PgPool,
    scope: &str,
    workspace_id: Option<Uuid>,
    user_id: Option<Uuid>,
    items: &[HelpHubLinkItem],
) -> Result<(), ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    sqlx::query(
        r#"
        DELETE FROM app_help_hub_link
        WHERE scope = $1
          AND ($2::uuid IS NULL OR workspace_id = $2)
          AND ($3::uuid IS NULL OR user_id = $3)
        "#,
    )
    .bind(scope)
    .bind(workspace_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for (idx, item) in items.iter().enumerate() {
        let link_id = item.id.trim();
        let title = item.title.trim();
        let url = item.url.trim();
        if link_id.is_empty() || title.is_empty() || url.is_empty() {
            continue;
        }
        sqlx::query(
            r#"
            INSERT INTO app_help_hub_link
              (id, scope, workspace_id, user_id, link_id, title, url, sort_order, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(scope)
        .bind(workspace_id)
        .bind(user_id)
        .bind(link_id)
        .bind(title)
        .bind(url)
        .bind(idx as i32)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/help/hub/user-links",
    operation_id = "postSettingsHelpHubUserLinksV1",
    tag = "settings",
    request_body = UpsertHelpHubLinksBody,
    responses(
        (status = 200, description = "OK", body = HelpHubConfigResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_user_help_hub_links(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpsertHelpHubLinksBody>,
) -> Result<Json<HelpHubConfigResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    replace_links(pool, "user", None, Some(uid), &body.items).await?;
    get_help_hub_config(State(state), headers).await
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/help/hub/workspace-links",
    operation_id = "postSettingsHelpHubWorkspaceLinksV1",
    tag = "settings",
    request_body = UpsertHelpHubLinksBody,
    responses(
        (status = 200, description = "OK", body = HelpHubConfigResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_workspace_help_hub_links(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpsertHelpHubLinksBody>,
) -> Result<Json<HelpHubConfigResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace(pool, uid).await?;
    if !can_manage {
        return Err(forbidden_i18n(
            "requires enterprise workspace owner/admin",
            "需要企业工作区所有者/管理员权限",
        ));
    }
    replace_links(pool, "workspace", Some(workspace_id), None, &body.items).await?;
    get_help_hub_config(State(state), headers).await
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/help/hub", get(get_help_hub_links))
        .route("/api/v1/settings/help/hub/config", get(get_help_hub_config))
        .route(
            "/api/v1/settings/help/hub/user-links",
            post(post_user_help_hub_links),
        )
        .route(
            "/api/v1/settings/help/hub/workspace-links",
            post(post_workspace_help_hub_links),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    static HELP_HUB_ENV_TEST_MUTEX: std::sync::OnceLock<std::sync::Mutex<()>> =
        std::sync::OnceLock::new();

    fn env_lock() -> std::sync::MutexGuard<'static, ()> {
        HELP_HUB_ENV_TEST_MUTEX
            .get_or_init(|| std::sync::Mutex::new(()))
            .lock()
            .expect("lock")
    }

    #[test]
    fn help_hub_items_json_parses() {
        let _guard = env_lock();
        std::env::set_var(
            "TOONFLOW_HELP_HUB_ITEMS_JSON",
            r#"[{"id":"a","title":"A","url":"https://example.com"}]"#,
        );
        let items = parse_env_items();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "a");
        std::env::remove_var("TOONFLOW_HELP_HUB_ITEMS_JSON");
    }

    #[test]
    fn help_hub_url_fallback() {
        let _guard = env_lock();
        std::env::remove_var("TOONFLOW_HELP_HUB_ITEMS_JSON");
        std::env::set_var("TOONFLOW_HELP_HUB_URL", "https://x.test");
        let items = parse_env_items();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].url, "https://x.test");
        std::env::remove_var("TOONFLOW_HELP_HUB_URL");
    }

    #[test]
    fn help_hub_permission_error_creates_correct_variant() {
        use crate::error::helpers::forbidden_i18n;
        use crate::error::ApiError;

        let err = forbidden_i18n(
            "requires enterprise workspace owner/admin",
            "需要企业工作区所有者/管理员权限",
        );
        match err {
            ApiError::Forbidden(msg) => {
                assert!(
                    msg == "requires enterprise workspace owner/admin"
                        || msg == "需要企业工作区所有者/管理员权限"
                );
            }
            _ => panic!("expected Forbidden variant"),
        }
    }

    #[tokio::test]
    async fn help_hub_permission_error_response_en() {
        use crate::error::helpers::forbidden_i18n;
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = forbidden_i18n(
            "requires enterprise workspace owner/admin",
            "需要企业工作区所有者/管理员权限",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("requires enterprise workspace owner/admin")
        );
    }

    #[tokio::test]
    async fn help_hub_permission_error_response_zh() {
        use crate::error::helpers::forbidden_i18n;
        use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = forbidden_i18n(
                    "requires enterprise workspace owner/admin",
                    "需要企业工作区所有者/管理员权限",
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("需要企业工作区所有者/管理员权限")
        );
    }
}
