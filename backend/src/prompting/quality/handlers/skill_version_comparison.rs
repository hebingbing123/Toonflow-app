//! GET /api/v1/quality/skill-version-comparison — 技能版本变更前后评审分布对比（需求 14.4）。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use axum::extract::Query;

use super::super::types::SkillVersionComparisonItem;

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct SkillVersionComparisonQuery {
    /// 按技能文件路径过滤（可选）
    pub skill_file_path: Option<String>,
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
}

/// GET /api/v1/quality/skill-version-comparison
///
/// 按 skill_version_hash 分组对比各版本的评审通过率、平均分、bad case 率和 grade 分布。
#[utoipa::path(
    get,
    path = "/api/v1/quality/skill-version-comparison",
    operation_id = "getQualitySkillVersionComparisonV1",
    tag = "quality",
    params(SkillVersionComparisonQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_skill_version_comparison(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<SkillVersionComparisonQuery>,
) -> Result<Json<Vec<SkillVersionComparisonItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = sqlx::query_as::<_, SkillVersionComparisonItem>(
        r#"
        SELECT
            'user'::text as scope,
            skill_file_path,
            skill_version_hash,
            COUNT(*) as total_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                2
            ), 0) as pass_rate_percent,
            COALESCE(ROUND(AVG(overall_score), 2), 0) as avg_score,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE is_bad_case = true) * 100.0 / NULLIF(COUNT(*), 0),
                2
            ), 0) as bad_case_rate_percent,
            COUNT(*) FILTER (WHERE grade = 'A') as grade_a_count,
            COUNT(*) FILTER (WHERE grade = 'B') as grade_b_count,
            COUNT(*) FILTER (WHERE grade = 'C') as grade_c_count,
            COUNT(*) FILTER (WHERE grade = 'D') as grade_d_count
        FROM app_quality_review
        WHERE user_id = $1
          AND skill_file_path IS NOT NULL
          AND skill_version_hash IS NOT NULL
          AND ($2::text IS NULL OR skill_file_path = $2)
          AND ($3::int IS NULL OR project_id = $3)
          AND ($4::int IS NULL OR script_id = $4)
          AND (
            passed IS NOT NULL
            OR overall_score IS NOT NULL
            OR is_bad_case = true
            OR bad_case_category IS NOT NULL
            OR grade IS NOT NULL
          )
        GROUP BY skill_file_path, skill_version_hash
        ORDER BY skill_file_path, MAX(created_at) DESC
        "#,
    )
    .bind(user_id)
    .bind(query.skill_file_path.as_deref())
    .bind(query.project_id)
    .bind(query.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}
