//! HTTP 处理器。

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};

use crate::{
    auth::require_user_uuid, error::ApiError, prompting::quality::QualityReview, state::AppState,
};

use super::{
    rubric::get_rubric_for_stage,
    scorer::score_experiment_result,
    types::{ExperimentScoreSummary, QualityDimension, ScorePreviewRequest},
};

/// 获取量表配置
///
/// 返回指定阶段的量表维度和权重配置。
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/rubrics",
    params(GetRubricsQuery),
    responses(
        (status = 200, description = "量表配置", body = RubricConfigResponse),
        (status = 400, description = "请求参数错误"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn get_rubrics(
    State(_state): State<AppState>,
    _headers: HeaderMap,
    Query(query): Query<GetRubricsQuery>,
) -> Result<Json<RubricConfigResponse>, ApiError> {
    let stage = query.stage.as_deref().unwrap_or("video_prompt");
    let rubric = get_rubric_for_stage(stage);

    let dimensions: Vec<DimensionWeightItem> = rubric
        .dimension_weights
        .iter()
        .map(|(dim, weight)| DimensionWeightItem {
            dimension: *dim,
            display_name: dim.display_name().to_string(),
            weight: *weight,
        })
        .collect();

    Ok(Json(RubricConfigResponse {
        stage: stage.to_string(),
        dimensions,
        pass_threshold: rubric.pass_threshold,
        promotion_threshold: rubric.promotion_threshold,
        golden_threshold: rubric.golden_threshold,
        bad_case_threshold: rubric.bad_case_threshold,
    }))
}

/// 评分预览
///
/// 基于质量评审记录或手动输入生成评分预览，用于验证量表配置。
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/score-preview",
    request_body = ScorePreviewRequest,
    responses(
        (status = 200, description = "评分预览", body = ExperimentScoreSummary),
        (status = 400, description = "请求参数错误"),
        (status = 404, description = "质量评审记录不存在"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn score_preview(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<ScorePreviewRequest>,
) -> Result<Json<ExperimentScoreSummary>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;

    // 如果提供了 quality_review_id，从数据库加载
    if let Some(review_id) = req.quality_review_id {
        let pool = state.require_pool()?;

        let review = sqlx::query_as::<sqlx::Postgres, QualityReview>(
            r#"
            SELECT * FROM app_quality_review
            WHERE id = $1 AND user_id = $2
            "#,
        )
        .bind(review_id)
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::NotFound)?;

        let summary = score_experiment_result(&review, &req.stage);
        return Ok(Json(summary));
    }

    // 如果提供了手动分数，构造模拟评审记录
    if let Some(manual_scores) = req.manual_scores {
        let mock_review = create_mock_review_from_manual_scores(&manual_scores, user_id);
        let summary = score_experiment_result(&mock_review, &req.stage);
        return Ok(Json(summary));
    }

    Err(ApiError::BadRequest(
        "必须提供 quality_review_id 或 manual_scores".to_string(),
    ))
}

/// 从手动分数创建模拟评审记录
fn create_mock_review_from_manual_scores(
    manual_scores: &[super::types::ManualDimensionScore],
    user_id: uuid::Uuid,
) -> QualityReview {
    let mut review = QualityReview {
        id: uuid::Uuid::new_v4(),
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        user_id,
        project_id: None,
        script_id: None,
        job_id: None,
        target_type: "mock".to_string(),
        target_id: None,
        source: "manual".to_string(),
        plot_coherence: None,
        character_consistency: None,
        dialogue_naturalness: None,
        pacing: None,
        faithfulness: None,
        visual_quality: None,
        overall_score: None,
        passed: None,
        comments: None,
        skill_version: None,
        model_name: None,
        model_params: None,
        memory_delivery_priority_applied: None,
        reviewer_id: None,
        is_bad_case: false,
        bad_case_category: None,
        stage: None,
        grade: None,
        skill_file_path: None,
        skill_version_hash: None,
    };

    // 将手动分数映射回质量评审字段（简化映射）
    for manual in manual_scores {
        let score_i16 = scale_manual_score_to_review_score(manual.score);
        match manual.dimension {
            QualityDimension::CharacterConsistency => {
                review.character_consistency = Some(score_i16);
            }
            QualityDimension::DialogueNaturalness => {
                review.dialogue_naturalness = Some(score_i16);
            }
            QualityDimension::ShotRealism | QualityDimension::VisualContinuity => {
                review.visual_quality = Some(score_i16);
            }
            QualityDimension::NarrativeGrip => {
                review.plot_coherence = Some(score_i16);
                review.pacing = Some(score_i16);
            }
            QualityDimension::EmotionExpression => {
                review.overall_score = Some(score_i16);
            }
            QualityDimension::AiArtifacts => {
                if manual.score < 50.0 {
                    review.is_bad_case = true;
                    review.bad_case_category = Some("ai_artifacts".to_string());
                }
            }
        }
    }

    review
}

fn scale_manual_score_to_review_score(score: f64) -> i16 {
    (score / 10.0).round().clamp(0.0, 10.0) as i16
}

/// 获取量表配置查询参数
#[derive(Debug, Deserialize, IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct GetRubricsQuery {
    /// 生成阶段
    pub stage: Option<String>,
}

/// 量表配置响应
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RubricConfigResponse {
    pub stage: String,
    pub dimensions: Vec<DimensionWeightItem>,
    pub pass_threshold: f64,
    pub promotion_threshold: f64,
    pub golden_threshold: f64,
    pub bad_case_threshold: f64,
}

/// 维度权重条目
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct DimensionWeightItem {
    pub dimension: QualityDimension,
    pub display_name: String,
    pub weight: f64,
}

pub fn routes() -> axum::Router<AppState> {
    use axum::routing::{get, post};

    axum::Router::new()
        .route("/api/v1/benchmark/rubrics", get(get_rubrics))
        .route("/api/v1/benchmark/score-preview", post(score_preview))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_mock_review_from_manual_scores() {
        let user_id = uuid::Uuid::new_v4();
        let manual_scores = vec![super::super::types::ManualDimensionScore {
            dimension: QualityDimension::CharacterConsistency,
            score: 85.0,
            issues: None,
        }];

        let review = create_mock_review_from_manual_scores(&manual_scores, user_id);

        assert_eq!(review.user_id, user_id);
        assert_eq!(review.character_consistency, Some(9));
    }

    #[test]
    fn test_scale_manual_score_to_review_score_rounds_and_clamps() {
        assert_eq!(scale_manual_score_to_review_score(84.9), 8);
        assert_eq!(scale_manual_score_to_review_score(85.0), 9);
        assert_eq!(scale_manual_score_to_review_score(99.0), 10);
        assert_eq!(scale_manual_score_to_review_score(140.0), 10);
        assert_eq!(scale_manual_score_to_review_score(-12.0), 0);
    }
}
