//! 实验运行与变体快照 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

/// 实验运行记录
#[derive(Debug, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExperimentRun {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub name: String,
    pub status: String,
    pub sample_tier: String,
    pub stage_scope: serde_json::Value,
    pub baseline_variant_id: Option<Uuid>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub started_at: Option<chrono::DateTime<chrono::Utc>>,
    pub completed_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// 实验变体快照
#[derive(Debug, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExperimentVariant {
    pub id: Uuid,
    pub experiment_run_id: Uuid,
    pub label: String,
    pub is_baseline: bool,
    pub skill_snapshot: serde_json::Value,
    pub prompt_snapshot: serde_json::Value,
    pub memory_budget_snapshot: serde_json::Value,
    pub observation_policy_snapshot: serde_json::Value,
    pub model_route_snapshot: serde_json::Value,
    pub notes: Option<String>,
}

/// 技能版本快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SkillSnapshot {
    pub skill_files: Vec<SkillFileSnapshot>,
    pub version_tag: Option<String>,
}

/// 技能文件快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SkillFileSnapshot {
    pub path: String,
    pub hash: String,
    pub content: Option<String>,
}

/// 提示词模板快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PromptSnapshot {
    pub templates: Vec<PromptTemplateSnapshot>,
    pub version_tag: Option<String>,
}

/// 提示词模板快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PromptTemplateSnapshot {
    pub stage: String,
    pub template_content: String,
    pub hash: String,
}

/// 记忆预算档快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MemoryBudgetSnapshot {
    pub budget_tier: String,
    pub compression_rules: serde_json::Value,
    pub retention_buckets: serde_json::Value,
    pub observation_note_limit: Option<i32>,
    pub character_memory_priority: Option<serde_json::Value>,
}

/// 观察治理策略快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ObservationPolicySnapshot {
    pub negative_constraints: Vec<String>,
    pub observation_note_limit: i32,
    pub auto_negative_source: Option<String>,
    pub policy_version: Option<String>,
}

/// 模型路由配置快照
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRouteSnapshot {
    pub model_name: String,
    pub temperature: Option<f64>,
    pub max_tokens: Option<i32>,
    pub routing_rules: Option<serde_json::Value>,
}

/// 创建实验运行请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateExperimentBody {
    pub name: String,
    pub sample_tier: String,
    pub stage_scope: Vec<String>,
    pub variants: Vec<CreateVariantBody>,
    pub baseline_variant_label: Option<String>,
}

/// 创建变体请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateVariantBody {
    pub label: String,
    pub skill_snapshot: SkillSnapshot,
    pub prompt_snapshot: PromptSnapshot,
    pub memory_budget_snapshot: MemoryBudgetSnapshot,
    pub observation_policy_snapshot: ObservationPolicySnapshot,
    pub model_route_snapshot: ModelRouteSnapshot,
    pub notes: Option<String>,
}

/// 实验运行列表查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct ListExperimentsQuery {
    pub status: Option<String>,
    pub sample_tier: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 实验运行详情响应
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExperimentDetail {
    pub experiment: ExperimentRun,
    pub variants: Vec<ExperimentVariant>,
}
