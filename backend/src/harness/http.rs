//! Harness HTTP 端点。
//!
//! `/api/v1/harness/*` 下的 REST 路由（工具目录；未来的策略或管理端点保留在此处）。

use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::get;
use axum::{Json, Router};

use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::harness::tools::{HarnessToolInfo, ToolRegistry};
use crate::state::AppState;

#[derive(Serialize, utoipa::ToSchema)]
pub struct HarnessToolsResponse {
    pub tools: &'static [HarnessToolInfo],
}

#[utoipa::path(
    get,
    path = "/api/v1/harness/tools",
    operation_id = "listHarnessToolsV1",
    tag = "harness",
    responses(
        (status = 200, description = "OK", body = HarnessToolsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
async fn list_harness_tools(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HarnessToolsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    observe::harness_tools_catalog_http(uid);
    Ok(Json(HarnessToolsResponse {
        tools: ToolRegistry::catalog(),
    }))
}

pub fn router() -> Router<AppState> {
    Router::new().route("/api/v1/harness/tools", get(list_harness_tools))
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(list_harness_tools),
    components(schemas(
        HarnessToolsResponse,
        crate::harness::tools::HarnessToolInfo,
        crate::error::ErrorBody
    )),
    tags((name = "harness", description = "Harness tool catalog (invoke via WebSocket)"))
)]
pub struct HarnessOpenApi;
