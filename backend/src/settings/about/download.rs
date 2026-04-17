use axum::extract::{Json, State};
use axum::http::HeaderMap;
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
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
    if u.is_empty() {
        return Err(ApiError::BadRequest("url is required".into()));
    }
    let parsed = reqwest::Url::parse(u).map_err(|_| ApiError::BadRequest("invalid url".into()))?;
    let scheme = parsed.scheme();
    if scheme != "http" && scheme != "https" {
        return Err(ApiError::BadRequest("url must be http or https".into()));
    }
    let _ = body.reinstall;
    Ok(Json(DownloadAppAcceptedResponse {
        message: "Flutter 版本不通过此接口执行安装；请使用平台商店、分发页或浏览器打开下载链接",
    }))
}
