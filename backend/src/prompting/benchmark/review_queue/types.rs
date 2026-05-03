//! 人工复核队列 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

/// 人工复核队列项
#[derive(Debug, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ReviewQueueItem {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub experiment_run_id: Option<Uuid>,
    pub experiment_result_id: Option<Uuid>,
    pub review_type: String,
    pub status: String,
    pub priority: i32,
    pub prompt: String,
    pub rubric_snapshot: serde_json::Value,
    pub submitted_score: Option<serde_json::Value>,
    pub submitted_at: Option<chrono::DateTime<chrono::Utc>>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// 获取复核队列查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct GetReviewQueueQuery {
    pub experiment_run_id: Option<Uuid>,
    pub review_type: Option<String>,
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 提交复核结果请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SubmitReviewBody {
    pub submitted_score: serde_json::Value,
}

/// 跳过复核请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SkipReviewBody {
    pub reason: Option<String>,
}
