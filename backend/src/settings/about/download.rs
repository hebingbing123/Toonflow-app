use axum::extract::{Json, State};
use axum::http::HeaderMap;
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_non_empty_string, ApiError};
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct DownloadAppBody {
    pub(super) url: String,
    pub(super) reinstall: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct DownloadAppAcceptedResponse {
    pub(super) message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/about/download-app",
    operation_id = "postAboutDownloadAppV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_download_app(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownloadAppBody>,
) -> Result<Json<DownloadAppAcceptedResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let u = body.url.trim();
    validate_non_empty_string(u, "url")?;
    let parsed =
        reqwest::Url::parse(u).map_err(|_| bad_request_i18n("invalid url", "无效的 url"))?;
    let scheme = parsed.scheme();
    if scheme != "http" && scheme != "https" {
        return Err(bad_request_i18n(
            "url must be http or https",
            "url 必须是 http 或 https",
        ));
    }
    let _ = body.reinstall;
    Ok(Json(DownloadAppAcceptedResponse {
        message: "Flutter 版本不通过此接口执行安装；请使用平台商店、分发页或浏览器打开下载链接",
    }))
}
