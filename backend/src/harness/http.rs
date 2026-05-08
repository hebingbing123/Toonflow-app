//! Harness HTTP 端点。
//!
//! `/api/v1/harness/*` 下的 REST 路由（工具目录；未来的策略或管理端点保留在此处）。

use axum::body::Bytes;
use axum::extract::{Path, State};
use axum::http::HeaderMap;
use axum::http::StatusCode;
use axum::routing::{delete, get, post};
use axum::{Json, Router};

use chrono::{DateTime, Utc};
use serde::Serialize;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::harness::observe;
use crate::harness::tools::{HarnessToolInfo, ToolRegistry};
use crate::harness::user_wasm_db;
use crate::harness::wasm_runtime;
use crate::state::AppState;

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
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
#[serde(rename_all = "snake_case")]
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
async fn validate_user_wasm_only(
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

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct HarnessUserWasmPersisted {
    #[schema(example = "b3b4cb26-62d4-4d5c-9486-74c4c5c62c94")]
    pub id: Uuid,
    #[schema(example = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")]
    pub wasm_sha256_hex: String,
    #[schema(example = 38)]
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
}

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct HarnessUserWasmRecord {
    #[schema(example = "b3b4cb26-62d4-4d5c-9486-74c4c5c62c94")]
    pub id: Uuid,
    #[schema(example = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")]
    pub wasm_sha256_hex: String,
    #[schema(example = 38)]
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
}

#[derive(Serialize, utoipa::ToSchema)]
pub struct HarnessUserWasmListResponse {
    pub items: Vec<HarnessUserWasmRecord>,
}

/// **WP‑C:** persist validated WASM to **`app_harness_user_wasm`** (JWT + Postgres).
#[utoipa::path(
    post,
    path = "/api/v1/harness/user-wasm",
    operation_id = "persistHarnessUserWasmV1",
    tag = "harness",
    request_body(content = Vec<u8>, description = "Raw WebAssembly module", content_type = "application/wasm"),
    responses(
        (status = 201, description = "Stored", body = HarnessUserWasmPersisted),
        (status = 400, description = "Empty, oversized, malformed WASM, or per-user stored row limit", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "DATABASE_URL not configured / DB unavailable", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
async fn persist_user_wasm(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<(StatusCode, Json<HarnessUserWasmPersisted>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    observe::harness_user_wasm_persist_http(uid, body.len());
    let pool = state.require_pool()?;
    let row = user_wasm_db::persist_user_wasm_checked(pool, uid, &body).await?;

    Ok((
        StatusCode::CREATED,
        Json(HarnessUserWasmPersisted {
            id: row.id,
            wasm_sha256_hex: row.wasm_sha256_hex,
            size_bytes: row.size_bytes,
            created_at: row.created_at,
        }),
    ))
}

/// **WP‑C:** list stored WASM metadata for the JWT subject (**does not return** `wasm_bytes`).
#[utoipa::path(
    get,
    path = "/api/v1/harness/user-wasm",
    operation_id = "listHarnessUserWasmV1",
    tag = "harness",
    responses(
        (status = 200, description = "OK", body = HarnessUserWasmListResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "DATABASE_URL not configured / DB unavailable", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
async fn list_user_wasm_meta(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<HarnessUserWasmListResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let rows = user_wasm_db::list_user_wasm_for_owner(pool, uid).await?;

    observe::harness_user_wasm_list_http(uid, rows.len());

    Ok(Json(HarnessUserWasmListResponse {
        items: rows
            .into_iter()
            .map(|r| HarnessUserWasmRecord {
                id: r.id,
                wasm_sha256_hex: r.wasm_sha256_hex,
                size_bytes: r.size_bytes,
                created_at: r.created_at,
            })
            .collect(),
    }))
}

#[derive(Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct HarnessUserWasmRevoked {
    #[schema(example = "b3b4cb26-62d4-4d5c-9486-74c4c5c62c94")]
    pub id: Uuid,
    pub revoked_at: DateTime<Utc>,
}

/// **WP‑C:** soft-revoke one stored WASM row (**`revoked_at`** set; row retained for audit).
#[utoipa::path(
    delete,
    path = "/api/v1/harness/user-wasm/{id}",
    operation_id = "revokeHarnessUserWasmV1",
    tag = "harness",
    params(
        ("id" = Uuid, Path, description = "Stored WASM row id")
    ),
    responses(
        (status = 200, description = "Revoked or already revoked (idempotent)", body = HarnessUserWasmRevoked),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "No row for this id and owner", body = crate::error::ErrorBody),
        (status = 503, description = "DATABASE_URL not configured / DB unavailable", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
async fn revoke_user_wasm_by_id(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<HarnessUserWasmRevoked>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    observe::harness_user_wasm_revoke_http(uid, id);
    let revoked_at = user_wasm_db::revoke_user_wasm_for_owner(pool, uid, id).await?;
    Ok(Json(HarnessUserWasmRevoked { id, revoked_at }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/harness/tools", get(list_harness_tools))
        .route(
            "/api/v1/harness/user-wasm",
            get(list_user_wasm_meta).post(persist_user_wasm),
        )
        .route(
            "/api/v1/harness/user-wasm/validate",
            post(validate_user_wasm_only),
        )
        .route(
            "/api/v1/harness/user-wasm/{id}",
            delete(revoke_user_wasm_by_id),
        )
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        list_harness_tools,
        validate_user_wasm_only,
        persist_user_wasm,
        list_user_wasm_meta,
        revoke_user_wasm_by_id
    ),
    components(schemas(
        HarnessToolsResponse,
        ValidateUserWasmResponse,
        HarnessUserWasmPersisted,
        HarnessUserWasmRecord,
        HarnessUserWasmListResponse,
        HarnessUserWasmRevoked,
        crate::harness::tools::HarnessToolInfo,
        crate::error::ErrorBody
    )),
    tags((name = "harness", description = "Harness tools (catalog, user WASM validation/storage); invoke tools via WebSocket"))
)]
pub struct HarnessOpenApi;
