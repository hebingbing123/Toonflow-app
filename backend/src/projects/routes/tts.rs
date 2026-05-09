use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::{error::ApiError, state::AppState};

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsGenerateRequest {
    pub project_id: Uuid,
    pub shot_id: Uuid,
    pub text: String,
    pub provider: String,
    pub voice_id: String,
    pub emotion: Option<String>,
    pub speed: Option<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsGenerateResponse {
    pub task_id: Uuid,
    pub status: String,
    pub audio_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsBatchGenerateRequest {
    pub project_id: Uuid,
    pub shots: Vec<TtsGenerateRequest>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsBatchGenerateResponse {
    pub tasks: Vec<TtsGenerateResponse>,
    pub total: usize,
    pub succeeded: usize,
    pub failed: usize,
}

/// 生成单个镜头的 TTS 配音
#[utoipa::path(
    post,
    path = "/api/v1/tts/generate",
    request_body = TtsGenerateRequest,
    responses(
        (status = 200, description = "TTS 生成任务已创建", body = TtsGenerateResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn generate_tts(
    State(_state): State<AppState>,
    Json(_req): Json<TtsGenerateRequest>,
) -> Result<Json<TtsGenerateResponse>, ApiError> {
    // TODO: 实现 TTS 生成逻辑
    // 1. 验证项目权限
    // 2. 调用 TTS 服务
    // 3. 创建任务记录
    // 4. 返回任务信息

    tracing::warn!("TTS generation functionality not yet implemented");
    Err(ApiError::Internal)
}

/// 批量生成 TTS 配音
#[utoipa::path(
    post,
    path = "/api/v1/tts/batch-generate",
    request_body = TtsBatchGenerateRequest,
    responses(
        (status = 200, description = "批量 TTS 生成任务已创建", body = TtsBatchGenerateResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn batch_generate_tts(
    State(_state): State<AppState>,
    Json(_req): Json<TtsBatchGenerateRequest>,
) -> Result<Json<TtsBatchGenerateResponse>, ApiError> {
    // TODO: 实现批量 TTS 生成逻辑
    // 1. 验证项目权限
    // 2. 并发调用 TTS 服务（最多 5 个并发）
    // 3. 创建任务记录
    // 4. 返回批量结果

    tracing::warn!("Batch TTS generation functionality not yet implemented");
    Err(ApiError::Internal)
}
