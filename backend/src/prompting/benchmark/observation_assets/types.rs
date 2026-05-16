//! 观察资产治理 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

/// 观察资产记录
#[derive(Debug, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ObservationAsset {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub project_id: Option<i32>,
    pub scope_kind: String,
    pub issue_type: String,
    pub source_kind: String,
    pub source_ref: Option<String>,
    pub signal_strength: i32,
    pub hit_count: i32,
    pub falsified_count: i32,
    pub status: String,
    pub normalized_note: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub last_hit_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// 创建观察资产请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateObservationAssetBody {
    pub project_id: Option<i32>,
    pub scope_kind: String,
    pub issue_type: String,
    pub source_kind: String,
    pub source_ref: Option<String>,
    pub signal_strength: Option<i32>,
    pub normalized_note: String,
}

/// 更新观察资产请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct UpdateObservationAssetBody {
    pub scope_kind: Option<String>,
    pub issue_type: Option<String>,
    pub signal_strength: Option<i32>,
    pub normalized_note: Option<String>,
    pub status: Option<String>,
}

/// 观察资产列表查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct ListObservationAssetsQuery {
    pub project_id: Option<i32>,
    pub scope_kind: Option<String>,
    pub issue_type: Option<String>,
    pub source_kind: Option<String>,
    pub status: Option<String>,
    pub min_signal_strength: Option<i32>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}
