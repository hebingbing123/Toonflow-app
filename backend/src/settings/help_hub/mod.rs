use axum::{extract::State, http::HeaderMap, routing::get, Json, Router};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

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
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(HelpHubLinksResponse {
        items: parse_env_items(),
    }))
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/settings/help/hub", get(get_help_hub_links))
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
}
