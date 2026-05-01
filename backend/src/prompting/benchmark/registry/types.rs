//! 基线样本注册表 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

/// 基线样本记录
#[derive(Debug, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BenchmarkCase {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub project_id: i32,
    pub script_id: Option<i32>,
    pub stage: String,
    pub case_type: String,
    pub issue_tags: serde_json::Value,
    pub weight: i32,
    pub source_kind: String,
    pub source_ref: Option<String>,
    pub summary: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub last_verified_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// 创建基线样本请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateBenchmarkCaseBody {
    pub project_id: i32,
    pub script_id: Option<i32>,
    pub stage: String,
    pub case_type: String,
    pub issue_tags: Option<Vec<String>>,
    pub weight: Option<i32>,
    pub source_kind: String,
    pub source_ref: Option<String>,
    pub summary: String,
}

/// 更新基线样本请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct UpdateBenchmarkCaseBody {
    pub stage: Option<String>,
    pub case_type: Option<String>,
    pub issue_tags: Option<Vec<String>>,
    pub weight: Option<i32>,
    pub summary: Option<String>,
    pub last_verified_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// 基线样本列表查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct ListBenchmarkCasesQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub stage: Option<String>,
    pub case_type: Option<String>,
    pub source_kind: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 从质量评审提升为基线样本请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PromoteFromQualityReviewBody {
    pub quality_review_id: Uuid,
    pub case_type: String,
    pub issue_tags: Option<Vec<String>>,
    pub weight: Option<i32>,
    pub summary: String,
}
