use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    response::Response,
};
use serde_json::json;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SETTINGS_ACCOUNT_EXPORT};
use crate::state::AppState;

use super::storage::{
    delete_account_and_cleanup, get_account_export_file_response, list_account_exports,
    to_account_export_job_record,
};
use super::types::{
    AccountDeleteBody, AccountDeleteResponse, AccountExportCreateBody, AccountExportJobRecord,
    AccountExportsResponse, ACCOUNT_DELETE_CONFIRM_PHRASE,
};

#[utoipa::path(
    post,
    path = "/api/v1/settings/account/export",
    operation_id = "postSettingsAccountExportV1",
    tag = "settings",
    request_body = AccountExportCreateBody,
    responses(
        (status = 200, description = "OK", body = AccountExportJobRecord),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_account_export(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AccountExportCreateBody>,
) -> Result<Json<AccountExportJobRecord>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let row: JobRow = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_SETTINGS_ACCOUNT_EXPORT,
        json!({
            "scope": "account",
            "format": "zip",
            "include_audit_logs": body.include_audit_logs,
            "include_notifications": body.include_notifications,
        }),
        Some(&headers),
    )
    .await?;
    Ok(Json(to_account_export_job_record(&row)))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/account/exports",
    operation_id = "getSettingsAccountExportsV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = AccountExportsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_account_exports(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<AccountExportsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(list_account_exports(pool, uid).await?))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/account/exports/{job_id}/file",
    operation_id = "getSettingsAccountExportFileV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK"),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_account_export_file(
    State(state): State<AppState>,
    Path(job_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    get_account_export_file_response(&state, pool, uid, job_id).await
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/account/delete",
    operation_id = "postSettingsAccountDeleteV1",
    tag = "settings",
    request_body = AccountDeleteBody,
    responses(
        (status = 200, description = "OK", body = AccountDeleteResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_account_delete(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AccountDeleteBody>,
) -> Result<Json<AccountDeleteResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.confirm_phrase.trim() != ACCOUNT_DELETE_CONFIRM_PHRASE {
        return Err(ApiError::BadRequest(format!(
            "confirmPhrase must equal `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"
        )));
    }
    if !body.acknowledge_irreversible {
        return Err(ApiError::BadRequest(
            "acknowledgeIrreversible must be true".into(),
        ));
    }
    let pool = state.require_pool()?;
    Ok(Json(delete_account_and_cleanup(&state, pool, uid).await?))
}
