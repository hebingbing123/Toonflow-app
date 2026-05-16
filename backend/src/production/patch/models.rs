// Feature: ai-drama-quality-optimization
//! 局部返工（Patch Regeneration）数据模型（需求 35.1, 35.2）

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 返工粒度枚举（需求 35.2）
///
/// 定义可以进行局部返工的最小对象粒度，从粗到细：
/// - `Episode`：单集故事骨架或剧本
/// - `Scene`：单场
/// - `StoryboardItem`：单条分镜
/// - `VideoPrompt`：单条视频提示词
/// - `DeriveAsset`：单个衍生资产
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PatchScope {
    Episode,
    Scene,
    StoryboardItem,
    VideoPrompt,
    DeriveAsset,
}

impl PatchScope {
    /// 返回该粒度的中文描述（用于日志和错误消息）
    #[allow(dead_code)]
    pub fn label(&self) -> &'static str {
        match self {
            PatchScope::Episode => "单集",
            PatchScope::Scene => "单场",
            PatchScope::StoryboardItem => "单条分镜",
            PatchScope::VideoPrompt => "单条视频提示词",
            PatchScope::DeriveAsset => "单个衍生资产",
        }
    }
}

/// 分级模型策略（需求 35.4）
///
/// - `Low`：结构化提取、格式修复、范围压缩（低成本模型）
/// - `High`：剧情改写、情绪强化、关键镜头提示词（高能力模型）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelTier {
    Low,
    High,
}

impl ModelTier {
    /// 返回该层级的中文描述
    #[allow(dead_code)]
    pub fn label(&self) -> &'static str {
        match self {
            ModelTier::Low => "低成本模型（格式修复/范围压缩）",
            ModelTier::High => "高能力模型（剧情改写/情绪强化）",
        }
    }
}

/// `POST /api/v1/production/patch` 请求体（需求 35.1）
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PatchRequest {
    /// 项目 ID（用于权限校验、记忆写入与返工历史隔离）
    #[serde(default)]
    pub project_id: Option<i32>,
    /// 项目 UUID（`app_project.id`）；优先于 `project_id`
    #[serde(default)]
    pub project_uuid: Option<Uuid>,
    /// 剧本/集 ID（用于同项目不同剧集的返工历史隔离）
    #[serde(default)]
    pub episodes_id: Option<i32>,
    /// 返工粒度
    pub scope: PatchScope,
    /// 需要返工的对象 ID 列表（分镜 ID、资产 ID 等）
    pub ids: Vec<i64>,
    /// 返工原因（供归因分析使用）
    pub reason: String,
    /// 模型层级选择
    pub model_tier: ModelTier,
}

impl PatchRequest {
    pub fn require_project_numeric_id(&self) -> Result<i32, crate::error::ApiError> {
        self.project_id.ok_or_else(|| {
            crate::error::bad_request_i18n(
                "projectId or projectUuid is required",
                "projectId 或 projectUuid 至少需要提供一个",
            )
        })
    }
}

#[cfg(test)]
mod tests {
    use super::PatchRequest;

    #[test]
    fn patch_request_accepts_project_uuid() {
        let body: PatchRequest = serde_json::from_str(
            r#"{
                "projectUuid":"550e8400-e29b-41d4-a716-446655440000",
                "episodesId":12,
                "scope":"storyboard_item",
                "ids":[1,2],
                "reason":"repair",
                "modelTier":"low"
            }"#,
        )
        .unwrap();
        assert_eq!(body.project_id, None);
        assert_eq!(
            body.project_uuid.map(|id| id.to_string()).as_deref(),
            Some("550e8400-e29b-41d4-a716-446655440000")
        );
    }
}

/// `POST /api/v1/production/patch` 响应体
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PatchResponse {
    /// 本次返工任务 ID（用于追踪）
    pub patch_id: uuid::Uuid,
    /// 返工粒度
    pub scope: PatchScope,
    /// 实际处理的对象 ID 列表
    pub processed_ids: Vec<i64>,
    /// 使用的模型层级
    pub model_tier: ModelTier,
    /// 状态：`queued` | `in_progress` | `completed` | `failed`
    pub status: String,
    /// 连续失败次数（用于触发归因模式）
    pub consecutive_failures: u32,
    /// 是否已进入「问题归因模式」（需求 35.7）
    pub attribution_mode: bool,
    /// 归因分析结果（仅在 attribution_mode=true 时填充）
    pub attribution_summary: Option<String>,
    /// 失败归因分类
    pub attribution_category: Option<String>,
    /// 最小必要上游回退阶段
    pub suggested_upstream_stage: Option<String>,
    /// 最小必要上游回退粒度
    pub suggested_upstream_scope: Option<PatchScope>,
    /// 前端可直接展示的返工优先级建议
    pub repair_priority: Vec<String>,
    /// 相比整段重跑节省的 token 估算值
    pub saved_token_estimate: u32,
    /// 高价值归因是否已写入自动记忆
    pub memory_written: bool,
}

/// 返工历史记录（用于追踪连续失败次数，需求 35.7）
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct PatchAttempt {
    pub scope: PatchScope,
    pub ids: Vec<i64>,
    pub reason: String,
    pub model_tier: ModelTier,
    pub succeeded: bool,
}
