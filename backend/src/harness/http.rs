//! Harness HTTP 端点。
//!
//! `/api/v1/harness/*` 下的 REST 路由（工具目录；未来的策略或管理端点保留在此处）。

use axum::body::Bytes;
use axum::extract::State;
use axum::http::HeaderMap;
use axum::routing::{get, post};
use axum::{Json, Router};

use serde::Serialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::harness::tools::{HarnessToolInfo, ToolRegistry};
use crate::harness::wasm_runtime;
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

#[derive(Serialize, utoipa::ToSchema)]
pub struct ValidateUserWasmResponse {
    /// Always **true** on **200**; present for forwards-compatible tooling.
    pub validated: bool,
    /// Bytes received in the request body.
    #[schema(example = 64)]
    pub size_bytes: u64,
}

/// **WP‑C:** HTTP surface for **`validate_user_wasm_upload`** (size cap + wasmi parse). Does not persist.
#[utoipa::path(
    post,
    path = "/api/v1/harness/user-wasm/validate",
    operation_id = "validateHarnessUserWasmV1",
    tag = "harness",
    request_body(content = Vec<u8>, description = "Raw WebAssembly module", content_type = "application/wasm"),
    responses(
        (status = 200, description = "Module passes validation", body = ValidateUserWasmResponse),
        (status = 400, description = "Empty, oversized, or malformed WASM", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
async fn validate_user_wasm(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<Json<ValidateUserWasmResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    observe::harness_user_wasm_validate_http(uid, body.len());
    let n = body.len();
    wasm_runtime::validate_user_wasm_upload(&body).map_err(ApiError::BadRequest)?;
    Ok(Json(ValidateUserWasmResponse {
        validated: true,
        size_bytes: n as u64,
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/harness/tools", get(list_harness_tools))
        .route(
            "/api/v1/harness/user-wasm/validate",
            post(validate_user_wasm),
        )
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(list_harness_tools, validate_user_wasm),
    components(schemas(
        HarnessToolsResponse,
        ValidateUserWasmResponse,
        crate::harness::tools::HarnessToolInfo,
        crate::error::ErrorBody
    )),
    tags((name = "harness", description = "Harness tools (catalog, user WASM validation); invoke tools via WebSocket"))
)]
pub struct HarnessOpenApi;
