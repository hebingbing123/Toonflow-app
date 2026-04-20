use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use base64::Engine;
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::scope::http::require_owned_numeric_production_scope;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct EditImageUploadImageBody {
    project_id: i32,
    script_id: i32,
    base64_data: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct EditImageUploadImageResponse {
    url: String,
}

fn normalize_upload_image_data_uri(input: &str) -> Result<String, ApiError> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Err(ApiError::BadRequest("base64Data must not be empty".into()));
    }
    let (prefix, payload) = trimmed
        .split_once(',')
        .ok_or_else(|| ApiError::BadRequest("base64Data must be a valid data URI".into()))?;
    let lower = prefix.to_ascii_lowercase();
    if !(lower.starts_with("data:image/jpeg;")
        || lower.starts_with("data:image/jpg;")
        || lower.starts_with("data:image/png;"))
        || !lower.contains(";base64")
    {
        return Err(ApiError::BadRequest("不支持的文件类型".into()));
    }

    let payload = payload.trim();
    if payload.is_empty() {
        return Err(ApiError::BadRequest(
            "base64Data payload must not be empty".into(),
        ));
    }
    base64::engine::general_purpose::STANDARD
        .decode(payload)
        .map_err(|_| ApiError::BadRequest("base64Data must be valid base64".into()))?;

    let mime = prefix
        .trim()
        .strip_prefix("data:")
        .and_then(|s| s.split(';').next())
        .unwrap_or("image/png")
        .to_ascii_lowercase();
    Ok(format!("data:{mime};base64,{payload}"))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/edit-image/upload-image",
    operation_id = "postProductionEditImageUploadImageV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_edit_image_upload_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditImageUploadImageBody>,
) -> Result<JsonResponse<EditImageUploadImageResponse>, ApiError> {
    let normalized = normalize_upload_image_data_uri(&body.base64_data)?;
    let (_uid, _pool, _project_id, _script_id, _script_content) =
        require_owned_numeric_production_scope(&state, &headers, body.project_id, body.script_id)
            .await?;

    Ok(JsonResponse(EditImageUploadImageResponse {
        url: normalized,
    }))
}

#[cfg(test)]
mod tests {
    use super::normalize_upload_image_data_uri;
    use crate::error::ApiError;

    #[test]
    fn upload_image_normalize_accepts_png_data_uri() {
        let got = normalize_upload_image_data_uri("data:image/png;base64,AA==").expect("png");
        assert_eq!(got, "data:image/png;base64,AA==");
    }

    #[test]
    fn upload_image_normalize_rejects_non_image_mime() {
        let err = normalize_upload_image_data_uri("data:text/plain;base64,AA==")
            .expect_err("text mime should fail");
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("不支持")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn upload_image_normalize_rejects_invalid_base64() {
        let err = normalize_upload_image_data_uri("data:image/png;base64,not-base64")
            .expect_err("invalid base64");
        match err {
            ApiError::BadRequest(msg) => assert!(msg.contains("valid base64")),
            other => panic!("unexpected error: {other:?}"),
        }
    }
}
