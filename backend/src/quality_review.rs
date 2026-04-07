use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const VALID_TARGET_TYPES: &[&str] = &["storyboard", "script", "video", "asset", "output"];
const VALID_SOURCES: &[&str] = &["manual", "auto"];
const VALID_BAD_CASE_CATEGORIES: &[&str] = &[
    "plot_hole",
    "character_break",
    "storyboard_mismatch",
    "dialogue_issue",
    "visual_error",
    "pacing_issue",
    "other",
];

// ============================================================================
// 数据模型
// ============================================================================

/// 质量评估记录
#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityReview {
    pub id: Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub user_id: Uuid,
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub target_type: String,
    pub target_id: Option<String>,
    pub source: String,
    pub plot_coherence: Option<i16>,
    pub character_consistency: Option<i16>,
    pub dialogue_naturalness: Option<i16>,
    pub pacing: Option<i16>,
    pub faithfulness: Option<i16>,
    pub visual_quality: Option<i16>,
    pub overall_score: Option<i16>,
    pub passed: Option<bool>,
    pub comments: Option<String>,
    pub skill_version: Option<String>,
    pub model_name: Option<String>,
    pub model_params: Option<serde_json::Value>,
    pub reviewer_id: Option<Uuid>,
    pub is_bad_case: bool,
    pub bad_case_category: Option<String>,
}

/// 创建质量评估请求体
#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateQualityReviewBody {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub target_type: String,
    pub target_id: Option<String>,
    pub source: Option<String>,
    pub plot_coherence: Option<i16>,
    pub character_consistency: Option<i16>,
    pub dialogue_naturalness: Option<i16>,
    pub pacing: Option<i16>,
    pub faithfulness: Option<i16>,
    pub visual_quality: Option<i16>,
    pub overall_score: Option<i16>,
    pub passed: Option<bool>,
    pub comments: Option<String>,
    pub skill_version: Option<String>,
    pub model_name: Option<String>,
    pub model_params: Option<serde_json::Value>,
    pub is_bad_case: Option<bool>,
    pub bad_case_category: Option<String>,
}

/// 质量评估列表查询参数
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListQualityReviewsQuery {
    pub target_type: Option<String>,
    pub target_id: Option<String>,
    pub job_id: Option<Uuid>,
    pub is_bad_case: Option<bool>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 质量统计响应
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityStatsResponse {
    pub target_type: String,
    pub total_reviews: i64,
    pub passed_count: i64,
    pub failed_count: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: f64,
    pub avg_overall_score: f64,
}

/// 分环节通过率条目
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StagePassRateItem {
    pub target_type: String,
    pub review_date: chrono::DateTime<chrono::Utc>,
    pub total_reviews: i64,
    pub passed_count: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: Option<f64>,
    pub avg_score: Option<f64>,
}

fn validate_create_review_body(body: &CreateQualityReviewBody) -> Result<(), ApiError> {
    if !VALID_TARGET_TYPES.contains(&body.target_type.as_str()) {
        return Err(ApiError::BadRequest(format!(
            "Invalid target_type: {}, must be one of {:?}",
            body.target_type, VALID_TARGET_TYPES
        )));
    }

    if let Some(source) = body.source.as_deref() {
        if !VALID_SOURCES.contains(&source) {
            return Err(ApiError::BadRequest(format!(
                "Invalid source: {}, must be one of {:?}",
                source, VALID_SOURCES
            )));
        }
    }

    if let Some(cat) = body.bad_case_category.as_deref() {
        if !VALID_BAD_CASE_CATEGORIES.contains(&cat) {
            return Err(ApiError::BadRequest(format!(
                "Invalid bad_case_category: {}, must be one of {:?}",
                cat, VALID_BAD_CASE_CATEGORIES
            )));
        }
    }

    Ok(())
}

// ============================================================================
// 路由
// ============================================================================

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/quality/reviews",
            post(create_review).get(list_reviews),
        )
        .route("/api/v1/quality/reviews/{id}", get(get_review))
        .route("/api/v1/quality/stats", get(get_stats))
        .route("/api/v1/quality/stage-pass-rate", get(get_stage_pass_rate))
}

// ============================================================================
// 处理器
// ============================================================================

/// POST /api/v1/quality/reviews - 创建质量评估
async fn create_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateQualityReviewBody>,
) -> Result<Json<QualityReview>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_review_body(&body)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let source = body.source.as_deref().unwrap_or("manual");
    let is_bad_case = body.is_bad_case.unwrap_or(false);

    let review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id, project_id, script_id, job_id, target_type, target_id,
            source, plot_coherence, character_consistency, dialogue_naturalness,
            pacing, faithfulness, visual_quality, overall_score, passed,
            comments, skill_version, model_name, model_params,
            is_bad_case, bad_case_category
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(body.job_id)
    .bind(&body.target_type)
    .bind(&body.target_id)
    .bind(source)
    .bind(body.plot_coherence)
    .bind(body.character_consistency)
    .bind(body.dialogue_naturalness)
    .bind(body.pacing)
    .bind(body.faithfulness)
    .bind(body.visual_quality)
    .bind(body.overall_score)
    .bind(body.passed)
    .bind(&body.comments)
    .bind(&body.skill_version)
    .bind(&body.model_name)
    .bind(&body.model_params)
    .bind(is_bad_case)
    .bind(&body.bad_case_category)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(review))
}

/// GET /api/v1/quality/reviews - 列出自己的质量评估
async fn list_reviews(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListQualityReviewsQuery>,
) -> Result<Json<Vec<QualityReview>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let limit = query.limit.unwrap_or(100).clamp(1, 500);
    let offset = query.offset.unwrap_or(0).max(0);

    let reviews = if let Some(target_type) = &query.target_type {
        if let Some(target_id) = &query.target_id {
            sqlx::query_as::<_, QualityReview>(
                "SELECT * FROM app_quality_review WHERE user_id = $1 AND target_type = $2 AND target_id = $3 ORDER BY created_at DESC LIMIT $4 OFFSET $5"
            )
            .bind(user_id)
            .bind(target_type)
            .bind(target_id)
            .bind(limit)
            .bind(offset)
            .fetch_all(pool)
            .await
        } else if let Some(is_bad_case) = query.is_bad_case {
            sqlx::query_as::<_, QualityReview>(
                "SELECT * FROM app_quality_review WHERE user_id = $1 AND target_type = $2 AND is_bad_case = $3 ORDER BY created_at DESC LIMIT $4 OFFSET $5"
            )
            .bind(user_id)
            .bind(target_type)
            .bind(is_bad_case)
            .bind(limit)
            .bind(offset)
            .fetch_all(pool)
            .await
        } else {
            sqlx::query_as::<_, QualityReview>(
                "SELECT * FROM app_quality_review WHERE user_id = $1 AND target_type = $2 ORDER BY created_at DESC LIMIT $3 OFFSET $4"
            )
            .bind(user_id)
            .bind(target_type)
            .bind(limit)
            .bind(offset)
            .fetch_all(pool)
            .await
        }
    } else if let Some(job_id) = query.job_id {
        sqlx::query_as::<_, QualityReview>(
            "SELECT * FROM app_quality_review WHERE user_id = $1 AND job_id = $2 ORDER BY created_at DESC"
        )
        .bind(user_id)
        .bind(job_id)
        .fetch_all(pool)
        .await
    } else if let Some(is_bad_case) = query.is_bad_case {
        sqlx::query_as::<_, QualityReview>(
            "SELECT * FROM app_quality_review WHERE user_id = $1 AND is_bad_case = $2 ORDER BY created_at DESC LIMIT $3 OFFSET $4"
        )
        .bind(user_id)
        .bind(is_bad_case)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_as::<_, QualityReview>(
            "SELECT * FROM app_quality_review WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3"
        )
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(reviews))
}

/// GET /api/v1/quality/reviews/{id} - 获取单个质量评估
async fn get_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<QualityReview>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let review = sqlx::query_as::<_, QualityReview>(
        "SELECT * FROM app_quality_review WHERE id = $1 AND user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(review))
}

/// GET /api/v1/quality/stats - 获取质量统计
async fn get_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<QualityStatsResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let stats = sqlx::query_as::<_, QualityStatsResponse>(
        r#"
        SELECT
            target_type,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE passed = false) as failed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            COALESCE(AVG(overall_score), 0) as avg_overall_score
        FROM app_quality_review
        WHERE user_id = $1
        GROUP BY target_type
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(stats))
}

/// GET /api/v1/quality/stage-pass-rate - 分环节通过率（按日期聚合）
async fn get_stage_pass_rate(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<StagePassRateItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let items = sqlx::query_as::<_, StagePassRateItem>(
        r#"
        SELECT
            target_type,
            DATE_TRUNC('day', created_at) as review_date,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            AVG(overall_score) as avg_score
        FROM app_quality_review
        WHERE user_id = $1
        GROUP BY target_type, DATE_TRUNC('day', created_at)
        ORDER BY review_date DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

// ============================================================================
// 单元测试
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn create_quality_review_body_accepts_valid() {
        let json = json!({
            "targetType": "storyboard",
            "plotCoherence": 8,
            "characterConsistency": 9,
            "dialogueNaturalness": 7,
            "pacing": 8,
            "faithfulness": 9,
            "overallScore": 8,
            "passed": true,
            "comments": "整体质量良好",
            "isBadCase": false
        });
        let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
        assert_eq!(body.target_type, "storyboard");
        assert_eq!(body.plot_coherence, Some(8));
        assert_eq!(body.passed, Some(true));
    }

    #[test]
    fn create_quality_review_body_rejects_unknown_fields() {
        let json = json!({
            "targetType": "storyboard",
            "unknownField": "value"
        });
        let result: Result<CreateQualityReviewBody, _> = serde_json::from_value(json);
        assert!(result.is_err());
    }

    #[test]
    fn create_quality_review_body_accepts_bad_case() {
        let json = json!({
            "targetType": "script",
            "isBadCase": true,
            "badCaseCategory": "plot_hole",
            "comments": "剧情跑题严重",
            "overallScore": 3,
            "passed": false
        });
        let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
        assert_eq!(body.is_bad_case, Some(true));
        assert_eq!(body.bad_case_category, Some("plot_hole".to_string()));
    }

    #[test]
    fn create_quality_review_body_accepts_minimal() {
        let json = json!({
            "targetType": "output"
        });
        let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
        assert_eq!(body.target_type, "output");
        assert_eq!(body.source, None);
    }

    #[test]
    fn validate_create_review_body_rejects_invalid_source() {
        let body = CreateQualityReviewBody {
            target_type: "script".to_string(),
            source: Some("robot".to_string()),
            ..Default::default()
        };
        let err = validate_create_review_body(&body).expect_err("invalid source");
        assert!(matches!(err, ApiError::BadRequest(_)));
    }

    #[test]
    fn validate_create_review_body_rejects_invalid_target_type() {
        let body = CreateQualityReviewBody {
            target_type: "chapter".to_string(),
            ..Default::default()
        };
        let err = validate_create_review_body(&body).expect_err("invalid target_type");
        assert!(matches!(err, ApiError::BadRequest(_)));
    }
}
