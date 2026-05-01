// Feature: ai-drama-quality-optimization
//! 局部返工（Patch Regeneration）模块（需求 35.1, 35.2, 35.4, 35.7）
//!
//! 提供 `POST /api/v1/production/patch` 端点，支持对失败的集、场、分镜、
//! 视频提示词或衍生资产做定点重生成，不整段重跑。

pub mod dispatch;
pub mod models;

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use models::{PatchRequest, PatchResponse};

/// `POST /api/v1/production/patch`
///
/// 局部返工端点。接受返工粒度、目标 ID 列表、原因和模型层级，
/// 返回返工任务信息（含是否进入归因模式）。
///
/// 注意：本端点当前实现为「派发层」——验证请求、判断归因模式、返回任务元数据。
/// 实际的 Agent 重生成调用由 Harness WebSocket 层异步执行。
pub async fn post_production_patch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PatchRequest>,
) -> Result<Json<PatchResponse>, ApiError> {
    // 验证用户身份
    let _uid = require_user_uuid(&state, &headers)?;

    // 验证 reason 非空
    if body.reason.trim().is_empty() {
        return Err(ApiError::BadRequest(
            "reason 不能为空，请说明返工原因".into(),
        ));
    }

    // 派发：解析最小修复范围 + 构建响应（历史记录暂时为空，后续可从 DB 读取）
    let response = dispatch::build_patch_response(&body, &[])
        .map_err(|e| ApiError::BadRequest(e))?;

    Ok(Json(response))
}
