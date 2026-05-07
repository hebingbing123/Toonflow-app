// Analysis and optimization suggestion logic for low-performing content

use crate::error::ApiError;
use crate::prompting::quality::{NextAction, QualityReview};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use super::metrics::{calculate_performance_score, LowPerformanceAlert, PerformanceThresholds};

/// Rework action recommendation based on performance metrics
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReworkRecommendation {
    /// Regenerate storyboard (very low completion rate)
    RegenerateStoryboard,
    /// Adjust video prompt (low engagement)
    AdjustVideoPrompt,
    /// Retry video generation (moderate issues)
    RetryVideoGeneration,
    /// Manual review needed (unclear issue)
    ManualReview,
}

impl ReworkRecommendation {
    /// Convert recommendation to NextAction
    pub fn to_next_action(&self) -> NextAction {
        match self {
            Self::RegenerateStoryboard => NextAction::RegenerateStoryboard,
            Self::AdjustVideoPrompt => NextAction::AdjustVideoPrompt,
            Self::RetryVideoGeneration => NextAction::RetryVideoGeneration,
            Self::ManualReview => NextAction::ManualReview,
        }
    }

    /// Get human-readable description
    pub fn description(&self) -> &'static str {
        match self {
            Self::RegenerateStoryboard => "完成率极低，建议重新生成分镜以改善内容结构和节奏",
            Self::AdjustVideoPrompt => "互动率低，建议调整视频提示词以提升视觉吸引力",
            Self::RetryVideoGeneration => "表现不佳，建议重试视频生成以改善质量",
            Self::ManualReview => "表现异常，需要人工审核以确定改进方向",
        }
    }
}

/// Analyze performance metrics and recommend rework action
pub fn recommend_rework_action(alert: &LowPerformanceAlert) -> ReworkRecommendation {
    // Very low completion rate (< 20%) suggests structural issues
    if alert.completion_rate < 0.2 {
        return ReworkRecommendation::RegenerateStoryboard;
    }

    // Low engagement rate (< 0.5%) suggests visual/content issues
    if alert.engagement_rate < 0.005 {
        return ReworkRecommendation::AdjustVideoPrompt;
    }

    // Moderate completion rate (20-40%) suggests quality issues
    if alert.completion_rate < 0.4 {
        return ReworkRecommendation::RetryVideoGeneration;
    }

    // Default to manual review for unclear cases
    ReworkRecommendation::ManualReview
}

/// Create quality review for low-performing content
pub async fn create_quality_review_for_low_performance(
    pool: &PgPool,
    user_id: Uuid,
    alert: &LowPerformanceAlert,
    recommendation: &ReworkRecommendation,
) -> Result<QualityReview, ApiError> {
    // Convert script_id UUID to numeric ID if available
    let (project_numeric_id, script_numeric_id) = if let Some(script_uuid) = alert.script_id {
        #[derive(sqlx::FromRow)]
        struct NumericIds {
            project_numeric_id: i32,
            script_numeric_id: i32,
        }

        let row = sqlx::query_as::<_, NumericIds>(
            r#"
            SELECT 
                p.numeric_id AS project_numeric_id,
                s.numeric_id AS script_numeric_id
            FROM app_script s
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE s.id = $1
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $2
              )
            "#,
        )
        .bind(script_uuid)
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if let Some(row) = row {
            (Some(row.project_numeric_id), Some(row.script_numeric_id))
        } else {
            (None, None)
        }
    } else {
        (None, None)
    };

    // Calculate overall score based on performance metrics
    let overall_score = calculate_performance_score(alert);

    // Build model_params with performance metrics
    let model_params = json!({
        "diagnostics": {
            "source": "low_performance_alert",
            "platform": alert.platform_id,
            "views": alert.views,
            "completion_rate": alert.completion_rate,
            "engagement_rate": alert.engagement_rate,
            "recommendation": format!("{:?}", recommendation),
            "nextAction": recommendation.to_next_action().as_str()
        }
    });

    // Create quality review
    let next_action_str = recommendation.to_next_action().as_str();
    let review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id,
            project_id,
            script_id,
            target_type,
            target_id,
            source,
            overall_score,
            passed,
            is_bad_case,
            bad_case_category,
            comments,
            model_params,
            next_action,
            stage
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
        )
        RETURNING 
            id, user_id, project_id, script_id, target_type, target_id,
            source, overall_score, plot_coherence, character_consistency,
            dialogue_naturalness, pacing, faithfulness, visual_quality,
            passed, is_bad_case, bad_case_category, comments,
            model_params, next_action, stage, grade, skill_version_hash,
            created_at, updated_at
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind("output")
    .bind(alert.target_id.to_string())
    .bind("system")
    .bind(overall_score)
    .bind(false)
    .bind(true)
    .bind(Some("low_performance"))
    .bind(Some(recommendation.description()))
    .bind(sqlx::types::Json(model_params))
    .bind(Some(next_action_str))
    .bind(Some("video_generate"))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(review)
}

/// Process low-performance alerts and create quality reviews
pub async fn process_low_performance_alerts(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    thresholds: &PerformanceThresholds,
    limit: i64,
) -> Result<Vec<QualityReview>, ApiError> {
    use super::metrics::fetch_low_performance_alerts_with_context;

    // Fetch alerts
    let alerts = fetch_low_performance_alerts_with_context(
        pool,
        project_id,
        owner_user_id,
        thresholds,
        limit,
    )
    .await?;

    let mut reviews = Vec::new();

    for alert in alerts {
        // Skip if no script_id (can't create quality review without script context)
        if alert.script_id.is_none() {
            tracing::warn!(
                target_id = %alert.target_id,
                "Skipping low-performance alert: no script_id"
            );
            continue;
        }

        // Check if quality review already exists for this target
        #[derive(sqlx::FromRow)]
        #[allow(dead_code)]
        struct ExistingReview {
            id: Uuid,
        }

        let existing = sqlx::query_as::<_, ExistingReview>(
            r#"
            SELECT id
            FROM app_quality_review
            WHERE user_id = $1
              AND target_type = 'output'
              AND target_id = $2
              AND source = 'system'
              AND bad_case_category = 'low_performance'
            LIMIT 1
            "#,
        )
        .bind(owner_user_id)
        .bind(alert.target_id.to_string())
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if existing.is_some() {
            tracing::debug!(
                target_id = %alert.target_id,
                "Skipping low-performance alert: quality review already exists"
            );
            continue;
        }

        // Recommend rework action
        let recommendation = recommend_rework_action(&alert);

        tracing::info!(
            target_id = %alert.target_id,
            platform = %alert.platform_id,
            views = alert.views,
            completion_rate = alert.completion_rate,
            engagement_rate = alert.engagement_rate,
            recommendation = ?recommendation,
            "Creating quality review for low-performance content"
        );

        // Create quality review
        match create_quality_review_for_low_performance(
            pool,
            owner_user_id,
            &alert,
            &recommendation,
        )
        .await
        {
            Ok(review) => {
                reviews.push(review);
            }
            Err(e) => {
                tracing::error!(
                    target_id = %alert.target_id,
                    error = ?e,
                    "Failed to create quality review for low-performance alert"
                );
            }
        }
    }

    Ok(reviews)
}

/// **P6**: Create rework task for low-performance content
/// Links back to original publish draft/job for operational loop
#[allow(dead_code)]
pub async fn create_rework_task_for_alert(
    pool: &PgPool,
    _user_id: Uuid,
    alert: &LowPerformanceAlert,
    recommendation: &ReworkRecommendation,
) -> Result<ReworkTaskInfo, ApiError> {
    // Fetch original publish job and draft information
    #[derive(sqlx::FromRow)]
    struct PublishContext {
        job_id: Uuid,
        draft_id: Uuid,
        project_id: Uuid,
        title: String,
        external_video_id: Option<String>,
    }

    let context = sqlx::query_as::<_, PublishContext>(
        r#"
        SELECT 
            j.id as job_id,
            d.id as draft_id,
            d.project_id,
            d.title,
            (
                SELECT external_video_id 
                FROM app_publish_performance_snapshot 
                WHERE target_id = $1 
                ORDER BY synced_at DESC 
                LIMIT 1
            ) as external_video_id
        FROM app_publish_target t
        INNER JOIN app_publish_draft d ON d.id = t.draft_id
        LEFT JOIN app_publish_job j ON j.draft_id = d.id
        WHERE t.id = $1
        LIMIT 1
        "#,
    )
    .bind(alert.target_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    // Create rework task metadata
    let task_metadata = json!({
        "source": "low_performance_alert",
        "alert": {
            "target_id": alert.target_id,
            "platform_id": alert.platform_id,
            "views": alert.views,
            "completion_rate": alert.completion_rate,
            "engagement_rate": alert.engagement_rate,
        },
        "original_publish": {
            "job_id": context.job_id,
            "draft_id": context.draft_id,
            "title": context.title,
            "external_video_id": context.external_video_id,
        },
        "recommendation": {
            "action": format!("{:?}", recommendation),
            "description": recommendation.description(),
            "next_action": recommendation.to_next_action().as_str(),
        },
    });

    Ok(ReworkTaskInfo {
        target_id: alert.target_id,
        draft_id: context.draft_id,
        job_id: context.job_id,
        project_id: context.project_id,
        recommendation: recommendation.clone(),
        task_metadata,
    })
}

/// Information about a rework task created from low-performance alert
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct ReworkTaskInfo {
    pub target_id: Uuid,
    pub draft_id: Uuid,
    pub job_id: Uuid,
    pub project_id: Uuid,
    pub recommendation: ReworkRecommendation,
    pub task_metadata: serde_json::Value,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_recommend_rework_action_very_low_completion() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 1000,
            likes: 5,
            comments: 2,
            shares: 1,
            completion_rate: 0.15,
            engagement_rate: 0.008,
        };

        let recommendation = recommend_rework_action(&alert);
        assert_eq!(recommendation, ReworkRecommendation::RegenerateStoryboard);
    }

    #[test]
    fn test_recommend_rework_action_low_engagement() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 1000,
            likes: 2,
            comments: 1,
            shares: 0,
            completion_rate: 0.5,
            engagement_rate: 0.003,
        };

        let recommendation = recommend_rework_action(&alert);
        assert_eq!(recommendation, ReworkRecommendation::AdjustVideoPrompt);
    }

    #[test]
    fn test_recommend_rework_action_moderate_completion() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 1000,
            likes: 10,
            comments: 5,
            shares: 2,
            completion_rate: 0.35,
            engagement_rate: 0.017,
        };

        let recommendation = recommend_rework_action(&alert);
        assert_eq!(recommendation, ReworkRecommendation::RetryVideoGeneration);
    }

    #[test]
    fn test_recommend_rework_action_unclear() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 1000,
            likes: 15,
            comments: 8,
            shares: 3,
            completion_rate: 0.45,
            engagement_rate: 0.026,
        };

        let recommendation = recommend_rework_action(&alert);
        assert_eq!(recommendation, ReworkRecommendation::ManualReview);
    }

    #[test]
    fn test_rework_recommendation_to_next_action() {
        assert_eq!(
            ReworkRecommendation::RegenerateStoryboard.to_next_action(),
            NextAction::RegenerateStoryboard
        );
        assert_eq!(
            ReworkRecommendation::AdjustVideoPrompt.to_next_action(),
            NextAction::AdjustVideoPrompt
        );
        assert_eq!(
            ReworkRecommendation::RetryVideoGeneration.to_next_action(),
            NextAction::RetryVideoGeneration
        );
        assert_eq!(
            ReworkRecommendation::ManualReview.to_next_action(),
            NextAction::ManualReview
        );
    }

    /// **P6 验收**: Rework task info contains all necessary context
    #[test]
    fn test_rework_task_info_structure() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 50,
            likes: 1,
            comments: 0,
            shares: 0,
            completion_rate: 0.15,
            engagement_rate: 0.02,
        };

        let recommendation = recommend_rework_action(&alert);

        // Simulate task metadata structure
        let task_metadata = json!({
            "source": "low_performance_alert",
            "alert": {
                "target_id": alert.target_id,
                "platform_id": alert.platform_id,
                "views": alert.views,
                "completion_rate": alert.completion_rate,
                "engagement_rate": alert.engagement_rate,
            },
            "recommendation": {
                "action": format!("{:?}", recommendation),
                "description": recommendation.description(),
                "next_action": recommendation.to_next_action().as_str(),
            },
        });

        // Verify structure
        assert!(task_metadata.get("source").is_some());
        assert!(task_metadata.get("alert").is_some());
        assert!(task_metadata.get("recommendation").is_some());

        let alert_data = task_metadata.get("alert").unwrap();
        assert_eq!(
            alert_data.get("platform_id").and_then(|v| v.as_str()),
            Some("tiktok")
        );
        assert_eq!(alert_data.get("views").and_then(|v| v.as_i64()), Some(50));
    }
}
