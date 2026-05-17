//! `POST /api/v1/production/voiceover/preview` — short synchronous TTS sample (F.2).

use axum::{
    body::Body,
    extract::State,
    http::{header, HeaderMap, StatusCode},
    response::Response,
    Json,
};
use serde::Deserialize;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::worker::voiceover::load_tts_llm_config_for_user;
use crate::projects::routes::common::require_project_write_scope;
use crate::short_video::voice::{run_voice_preview, VoicePreviewInput};
use crate::state::AppState;

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VoiceoverPreviewBody {
    pub project_id: Uuid,
    #[serde(default)]
    pub character_id: Option<Uuid>,
    pub text: String,
    #[serde(default)]
    pub voice: Option<String>,
    #[serde(default)]
    pub emotion: Option<String>,
    #[serde(default)]
    pub speed: Option<f32>,
    #[serde(default)]
    pub provider: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/voiceover/preview",
    operation_id = "postProductionVoiceoverPreviewV1",
    tag = "production",
    request_body = VoiceoverPreviewBody,
    responses(
        (status = 200, description = "audio/mpeg"),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_production_voiceover_preview(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VoiceoverPreviewBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_write_scope(&state, uid, body.project_id).await?;
    let pool = state.require_pool()?;
    let voice_profile: Option<String> =
        sqlx::query_scalar("SELECT voice_profile FROM app_project WHERE id = $1")
            .bind(body.project_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .flatten();
    let character_voice = if let Some(character_id) = body.character_id {
        sqlx::query_scalar(
            "SELECT voice_config FROM app_project_character WHERE id = $1 AND project_id = $2",
        )
        .bind(character_id)
        .bind(body.project_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    } else {
        None
    };
    let openai_cfg = load_tts_llm_config_for_user(&state, pool, uid)
        .await
        .map_err(|err| match err {
            crate::jobs::worker::JobRunError::Failed(message) => ApiError::BadRequest(message),
            crate::jobs::worker::JobRunError::FailedStructured { message, .. } => {
                ApiError::BadRequest(message)
            }
            crate::jobs::worker::JobRunError::Cancelled => {
                crate::error::bad_request_i18n("Voiceover preview was cancelled", "配音试听已取消")
            }
        })?;
    let audio = run_voice_preview(
        &state,
        &openai_cfg,
        VoicePreviewInput {
            project_voice_profile: voice_profile.as_deref(),
            character_voice_config: character_voice.as_ref(),
            text: &body.text,
            explicit_voice: body.voice.as_deref(),
            explicit_emotion: body.emotion.as_deref(),
            explicit_speed: body.speed,
            explicit_provider: body.provider.as_deref(),
        },
    )
    .await
    .map_err(ApiError::BadRequest)?;

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "audio/mpeg")
        .body(Body::from(audio))
        .map_err(|e| ApiError::BadRequest(e.to_string()))
}
