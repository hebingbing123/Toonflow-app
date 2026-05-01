// Feature: ai-drama-quality-optimization
//! 局部返工（Patch Regeneration）数据模型（需求 35.1, 35.2）

use serde::{Deserialize, Serialize};

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
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PatchRequest {
    /// 返工粒度
    pub scope: PatchScope,
    /// 需要返工的对象 ID 列表（分镜 ID、资产 ID 等）
    pub ids: Vec<i64>,
    /// 返工原因（供归因分析使用）
    pub reason: String,
    /// 模型层级选择
    pub model_tier: ModelTier,
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
}

/// 返工历史记录（用于追踪连续失败次数，需求 35.7）
#[derive(Debug, Clone)]
pub struct PatchAttempt {
    pub scope: PatchScope,
    pub ids: Vec<i64>,
    pub reason: String,
    pub model_tier: ModelTier,
    pub succeeded: bool,
}
