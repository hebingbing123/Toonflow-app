//! M.1: Platform callback HTTP handlers
//!
//! These handlers receive callbacks from external platforms after publish operations.
//! All callbacks go through security validation (signature/timestamp/nonce).

use axum::{
    body::Bytes,
    extract::{Path, State},
    http::HeaderMap,
    routing::post,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;

use super::callback_validation::{validate_callback, CallbackValidationConfig};

/// Platform callback request body (generic structure)
#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct PlatformCallbackBody {
    /// Callback ID from the platform
    pub callback_id: String,
    /// Job ID that this callback relates to
    pub job_id: Option<Uuid>,
    /// Draft ID that this callback relates to
    pub draft_id: Option<Uuid>,
    /// Callback event type (e.g., "publish_success", "publish_failed")
    pub event_type: String,
    /// Platform-specific data
    pub data: Value,
    /// Optional error information
    pub error: Option<CallbackError>,
}

#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct CallbackError {
    pub code: String,
    pub message: String,
    pub details: Option<Value>,
}

/// Callback response
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub struct CallbackResponse {
    pub received: bool,
    pub callback_id: String,
    pub processed_at: String,
}

pub fn callback_router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/callbacks/publish/:platform_id",
        post(handle_platform_callback),
    )
}

/// Handle platform callback
///
/// This endpoint receives callbacks from external platforms.
/// All requests must pass security validation (signature/timestamp/nonce).
///
/// ## Security Headers Required
///
/// - `X-Platform-Signature`: HMAC-SHA256 hex signature
/// - `X-Platform-Timestamp`: Unix timestamp (seconds)
/// - `X-Platform-Nonce`: Unique nonce for this request
/// - `X-Callback-Id`: Optional callback identifier
///
/// ## Signature Computation
///
/// The signature is computed as:
/// ```text
/// HMAC-SHA256(secret_key, timestamp + "." + body)
/// ```
///
/// Where:
/// - `secret_key` is the platform-specific secret from `app_publish_platform_secret`
/// - `timestamp` is the value from `X-Platform-Timestamp` header
/// - `body` is the raw request body bytes
///
#[utoipa::path(
    post,
    path = "/api/v1/callbacks/publish/{platform_id}",
    operation_id = "handlePlatformCallbackV1",
    tag = "publish-callbacks",
    params(
        ("platform_id" = String, Path, description = "Platform identifier (e.g., douyin, tiktok)")
    ),
    request_body = PlatformCallbackBody,
    responses(
        (status = 200, description = "Callback received and validated", body = CallbackResponse),
        (status = 400, description = "Invalid request or validation failed", body = crate::error::ErrorBody),
        (status = 401, description = "Invalid signature", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn handle_platform_callback(
    State(state): State<AppState>,
    Path(platform_id): Path<String>,
    headers: HeaderMap,
    body: Bytes,
) -> Result<Json<CallbackResponse>, ApiError> {
    let pool = state.require_pool()?;

    // Extract source IP for audit (if behind proxy, check X-Forwarded-For)
    let source_ip = headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .or_else(|| headers.get("x-real-ip").and_then(|v| v.to_str().ok()));

    // Validate callback (signature, timestamp, nonce)
    let config = CallbackValidationConfig::default();
    let validated = validate_callback(
        pool,
        &platform_id,
        &headers,
        body.to_vec(),
        &config,
        source_ip,
    )
    .await?;

    // Parse callback body
    let callback_body: PlatformCallbackBody = serde_json::from_slice(&validated.body)
        .map_err(|e| ApiError::BadRequest(format!("Invalid JSON body: {}", e)))?;

    // Process callback based on event type
    process_callback_event(pool, &platform_id, &callback_body).await?;

    Ok(Json(CallbackResponse {
        received: true,
        callback_id: validated
            .callback_id
            .unwrap_or_else(|| callback_body.callback_id.clone()),
        processed_at: chrono::Utc::now().to_rfc3339(),
    }))
}

/// Process callback event and update job status
async fn process_callback_event(
    pool: &sqlx::PgPool,
    platform_id: &str,
    callback: &PlatformCallbackBody,
) -> Result<(), ApiError> {
    match callback.event_type.as_str() {
        "publish_success" => {
            handle_publish_success(pool, platform_id, callback).await?;
        }
        "publish_failed" => {
            handle_publish_failed(pool, platform_id, callback).await?;
        }
        "publish_processing" => {
            handle_publish_processing(pool, platform_id, callback).await?;
        }
        other => {
            tracing::warn!(
                platform_id = platform_id,
                event_type = other,
                "Unknown callback event type"
            );
        }
    }

    Ok(())
}

/// Handle successful publish callback
async fn handle_publish_success(
    pool: &sqlx::PgPool,
    platform_id: &str,
    callback: &PlatformCallbackBody,
) -> Result<(), ApiError> {
    let job_id = callback
        .job_id
        .ok_or_else(|| ApiError::BadRequest("job_id required for publish_success".to_string()))?;

    // Update job status to succeeded
    let updated = sqlx::query(
        r#"
        UPDATE app_publish_job
        SET status = 'succeeded',
            updated_at = NOW()
        WHERE id = $1
          AND status IN ('uploading', 'platform_processing')
        "#,
    )
    .bind(job_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() > 0 {
        tracing::info!(
            job_id = %job_id,
            platform_id = platform_id,
            callback_id = callback.callback_id,
            "Publish job succeeded via callback"
        );

        // Record attempt audit
        if let Some(draft_id) = callback.draft_id {
            record_callback_attempt(pool, job_id, draft_id, platform_id, "succeeded", callback)
                .await?;
        }
    }

    Ok(())
}

/// Handle failed publish callback
async fn handle_publish_failed(
    pool: &sqlx::PgPool,
    platform_id: &str,
    callback: &PlatformCallbackBody,
) -> Result<(), ApiError> {
    let job_id = callback
        .job_id
        .ok_or_else(|| ApiError::BadRequest("job_id required for publish_failed".to_string()))?;

    let error_message = callback
        .error
        .as_ref()
        .map(|e| e.message.clone())
        .unwrap_or_else(|| "Platform reported failure".to_string());

    let error_details = callback.error.as_ref().map(|e| {
        serde_json::json!({
            "code": e.code,
            "message": e.message,
            "details": e.details,
            "callback_data": callback.data,
        })
    });

    // Update job status to failed
    let updated = sqlx::query(
        r#"
        UPDATE app_publish_job
        SET status = 'failed',
            error_message = $2,
            error_details = $3,
            updated_at = NOW()
        WHERE id = $1
          AND status IN ('uploading', 'platform_processing', 'validating')
        "#,
    )
    .bind(job_id)
    .bind(&error_message)
    .bind(error_details)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() > 0 {
        tracing::warn!(
            job_id = %job_id,
            platform_id = platform_id,
            callback_id = callback.callback_id,
            error = error_message,
            "Publish job failed via callback"
        );

        // Record attempt audit
        if let Some(draft_id) = callback.draft_id {
            record_callback_attempt(pool, job_id, draft_id, platform_id, "failed", callback)
                .await?;
        }
    }

    Ok(())
}

/// Handle processing status callback
async fn handle_publish_processing(
    pool: &sqlx::PgPool,
    platform_id: &str,
    callback: &PlatformCallbackBody,
) -> Result<(), ApiError> {
    let job_id = callback.job_id.ok_or_else(|| {
        ApiError::BadRequest("job_id required for publish_processing".to_string())
    })?;

    // Update job status to platform_processing if not already
    let updated = sqlx::query(
        r#"
        UPDATE app_publish_job
        SET status = 'platform_processing',
            updated_at = NOW()
        WHERE id = $1
          AND status IN ('uploading', 'validating')
        "#,
    )
    .bind(job_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() > 0 {
        tracing::info!(
            job_id = %job_id,
            platform_id = platform_id,
            callback_id = callback.callback_id,
            "Publish job processing via callback"
        );
    }

    Ok(())
}

/// Record callback attempt in audit table
async fn record_callback_attempt(
    pool: &sqlx::PgPool,
    job_id: Uuid,
    draft_id: Uuid,
    platform_id: &str,
    status: &str,
    callback: &PlatformCallbackBody,
) -> Result<(), ApiError> {
    // Find target_id for this platform
    let target_id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id FROM app_publish_target
        WHERE draft_id = $1 AND platform_id = $2
        LIMIT 1
        "#,
    )
    .bind(draft_id)
    .bind(platform_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(target_id) = target_id {
        // Get next attempt number
        let attempt_no: i32 = sqlx::query_scalar(
            r#"
            SELECT COALESCE(MAX(attempt_no), 0) + 1
            FROM app_publish_attempt
            WHERE job_id = $1 AND target_id = $2
            "#,
        )
        .bind(job_id)
        .bind(target_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let detail = serde_json::json!({
            "source": "platform_callback",
            "callback_id": callback.callback_id,
            "event_type": callback.event_type,
            "data": callback.data,
        });

        let error_message = callback.error.as_ref().map(|e| e.message.clone());

        sqlx::query(
            r#"
            INSERT INTO app_publish_attempt
                (job_id, target_id, attempt_no, status, detail, error_message)
            VALUES ($1, $2, $3, $4, $5, $6)
            "#,
        )
        .bind(job_id)
        .bind(target_id)
        .bind(attempt_no)
        .bind(status)
        .bind(detail)
        .bind(error_message)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_callback_body_deserialization() {
        let json = r#"{
            "callback_id": "cb_123",
            "job_id": "550e8400-e29b-41d4-a716-446655440000",
            "draft_id": "550e8400-e29b-41d4-a716-446655440001",
            "event_type": "publish_success",
            "data": {
                "external_video_id": "platform_vid_123",
                "published_url": "https://platform.com/video/123"
            }
        }"#;

        let callback: PlatformCallbackBody = serde_json::from_str(json).unwrap();
        assert_eq!(callback.callback_id, "cb_123");
        assert_eq!(callback.event_type, "publish_success");
        assert!(callback.job_id.is_some());
        assert!(callback.error.is_none());
    }

    #[test]
    fn test_callback_error_deserialization() {
        let json = r#"{
            "callback_id": "cb_456",
            "job_id": "550e8400-e29b-41d4-a716-446655440000",
            "event_type": "publish_failed",
            "data": {},
            "error": {
                "code": "UPLOAD_FAILED",
                "message": "Video upload failed",
                "details": {"reason": "network_timeout"}
            }
        }"#;

        let callback: PlatformCallbackBody = serde_json::from_str(json).unwrap();
        assert_eq!(callback.event_type, "publish_failed");
        assert!(callback.error.is_some());
        let error = callback.error.unwrap();
        assert_eq!(error.code, "UPLOAD_FAILED");
        assert_eq!(error.message, "Video upload failed");
    }
}
