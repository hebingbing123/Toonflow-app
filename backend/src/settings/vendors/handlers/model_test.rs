use axum::{extract::State, http::HeaderMap, Json};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST};
use crate::state::AppState;

use super::common::require_pool;
use crate::settings::vendors::dto::VendorModelTestBody;
use crate::settings::vendors::MAX_VENDOR_MODEL_TEST_FIELD_LEN;

#[utoipa::path(
    post,
    path = "/api/v1/settings/vendors/model-test",
    operation_id = "postSettingsVendorModelTestV1",
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
pub(crate) async fn post_vendor_model_test(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VendorModelTestBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = body.kind.to_ascii_lowercase();
    if kind != "text" && kind != "image" && kind != "video" {
        return Err(ApiError::BadRequest(
            "type must be text, image, or video".into(),
        ));
    }
    let model_name = body.model_name.trim();
    let id = body.id.trim();
    if model_name.is_empty() || id.is_empty() {
        return Err(ApiError::BadRequest(
            "modelName and id must be non-empty".into(),
        ));
    }
    if model_name.len() > MAX_VENDOR_MODEL_TEST_FIELD_LEN
        || id.len() > MAX_VENDOR_MODEL_TEST_FIELD_LEN
    {
        return Err(ApiError::BadRequest(format!(
            "modelName and id must be at most {MAX_VENDOR_MODEL_TEST_FIELD_LEN} chars each"
        )));
    }

    let pool = require_pool(&state)?;
    let payload = json!({
        "source": "settings.vendors.model-test",
        "model_name": model_name,
        "kind": kind,
        "id": id,
    });

    let row =
        enqueue_generation_job(pool, uid, JOB_KIND_SETTINGS_VENDOR_MODEL_TEST, payload).await?;
    Ok(Json(row))
}
