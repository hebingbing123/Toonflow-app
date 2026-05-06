// I.5: Connect low-performance alert to rewrite/republish loop
//
// This module provides the infrastructure to:
// 1. Detect low-performing published content
// 2. Create quality reviews with appropriate next_action
// 3. Trigger rework workflows
// 4. Enable republish after rework

use crate::error::ApiError;
use crate::prompting::quality::{NextAction, QualityReview};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

/// Performance thresholds for triggering rework
#[derive(Debug, Clone)]
pub struct PerformanceThresholds {
    /// Minimum views to consider content as low-performing
    pub min_views: i64,
    /// Minimum completion rate (0.0-1.0) to consider content as low-performing
    pub min_completion_rate: f64,
    /// Minimum engagement rate (likes+comments+shares / views) to consider content as low-performing
    pub min_engagement_rate: f64,
    /// Platform-specific overrides (platform_id -> thresholds)
    pub platform_overrides: std::collections::HashMap<String, PlatformThresholds>,
}

/// Platform-specific performance thresholds
#[derive(Debug, Clone)]
pub struct PlatformThresholds {
    pub min_views: Option<i64>,
    pub min_completion_rate: Option<f64>,
    pub min_engagement_rate: Option<f64>,
}

impl PerformanceThresholds {
    /// Get effective thresholds for a specific platform
    pub fn for_platform(&self, platform_id: &str) -> EffectiveThresholds {
        if let Some(override_thresholds) = self.platform_overrides.get(platform_id) {
            EffectiveThresholds {
                min_views: override_thresholds.min_views.unwrap_or(self.min_views),
                min_completion_rate: override_thresholds
                    .min_completion_rate
                    .unwrap_or(self.min_completion_rate),
                min_engagement_rate: override_thresholds
                    .min_engagement_rate
                    .unwrap_or(self.min_engagement_rate),
            }
        } else {
            EffectiveThresholds {
                min_views: self.min_views,
                min_completion_rate: self.min_completion_rate,
                min_engagement_rate: self.min_engagement_rate,
            }
        }
    }
}

/// Effective thresholds after applying platform overrides
#[derive(Debug, Clone)]
pub struct EffectiveThresholds {
    pub min_views: i64,
    pub min_completion_rate: f64,
    pub min_engagement_rate: f64,
}

impl Default for PerformanceThresholds {
    fn default() -> Self {
        Self {
            min_views: 100,
            min_completion_rate: 0.3,
            min_engagement_rate: 0.01,
            platform_overrides: std::collections::HashMap::new(),
        }
    }
}

/// Low-performance alert with associated draft and script information
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct LowPerformanceAlert {
    pub target_id: Uuid,
    pub draft_id: Uuid,
    pub script_id: Option<Uuid>,
    pub platform_id: String,
    pub views: i64,
    pub likes: i64,
    pub comments: i64,
    pub shares: i64,
    pub completion_rate: f64,
    pub engagement_rate: f64,
}

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

/// Fetch low-performance alerts with associated draft and script information
/// **P5**: Now supports platform-specific threshold overrides
pub async fn fetch_low_performance_alerts_with_context(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    thresholds: &PerformanceThresholds,
    limit: i64,
) -> Result<Vec<LowPerformanceAlert>, ApiError> {
    let capped_limit = limit.clamp(1, 200);

    #[derive(sqlx::FromRow)]
    struct Row {
        target_id: Uuid,
        draft_id: Uuid,
        script_id: Option<Uuid>,
        platform_id: String,
        views: i64,
        likes: i64,
        comments: i64,
        shares: i64,
        completion_rate: f64,
    }

    let rows = sqlx::query_as::<_, Row>(
        r#"
        SELECT
          s.target_id,
          s.draft_id,
          d.script_id,
          s.platform_id,
          COALESCE(s.views, 0)::BIGINT AS views,
          COALESCE(s.likes, 0)::BIGINT AS likes,
          COALESCE(s.comments, 0)::BIGINT AS comments,
          COALESCE(s.shares, 0)::BIGINT AS shares,
          COALESCE(s.completion_rate, 0)::DOUBLE PRECISION AS completion_rate
        FROM (
          SELECT DISTINCT ON (target_id)
            target_id, draft_id, platform_id, views, likes, comments, shares, completion_rate, synced_at
          FROM app_publish_performance_snapshot
          WHERE project_id = $1
          ORDER BY target_id, synced_at DESC
        ) AS s
        INNER JOIN app_publish_draft AS d ON d.id = s.draft_id
        INNER JOIN app_project AS p ON p.id = d.project_id
        WHERE p.owner_user_id = $2
        ORDER BY s.synced_at DESC
        LIMIT $3
        "#,
    )
    .bind(project_id)
    .bind(owner_user_id)
    .bind(capped_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let alerts = rows
        .into_iter()
        .filter_map(|row| {
            let views = row.views;
            let likes = row.likes;
            let comments = row.comments;
            let shares = row.shares;
            let engagement = likes + comments + shares;
            let engagement_rate = if views > 0 {
                engagement as f64 / views as f64
            } else {
                0.0
            };

            // P5: Apply platform-specific thresholds
            let effective = thresholds.for_platform(&row.platform_id);

            // Check if this row meets low-performance criteria for its platform
            let is_low_performing = views < effective.min_views
                || row.completion_rate < effective.min_completion_rate
                || engagement_rate < effective.min_engagement_rate;

            if !is_low_performing {
                return None;
            }

            Some(LowPerformanceAlert {
                target_id: row.target_id,
                draft_id: row.draft_id,
                script_id: row.script_id,
                platform_id: row.platform_id,
                views,
                likes,
                comments,
                shares,
                completion_rate: row.completion_rate,
                engagement_rate,
            })
        })
        .collect();

    Ok(alerts)
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
            WHERE s.id = $1 AND p.owner_user_id = $2
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

/// Calculate performance score (0-10) based on metrics
fn calculate_performance_score(alert: &LowPerformanceAlert) -> i16 {
    // Weight factors
    let completion_weight = 0.5;
    let engagement_weight = 0.3;
    let views_weight = 0.2;

    // Normalize metrics to 0-10 scale
    let completion_score = (alert.completion_rate * 10.0).min(10.0);
    let engagement_score = (alert.engagement_rate * 1000.0).min(10.0); // 1% engagement = 10 points
    let views_score = ((alert.views as f64 / 1000.0) * 10.0).min(10.0); // 1000 views = 10 points

    // Weighted average
    let weighted_score = completion_score * completion_weight
        + engagement_score * engagement_weight
        + views_score * views_weight;

    weighted_score.round() as i16
}

/// Process low-performance alerts and create quality reviews
pub async fn process_low_performance_alerts(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    thresholds: &PerformanceThresholds,
    limit: i64,
) -> Result<Vec<QualityReview>, ApiError> {
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
    fn test_calculate_performance_score_low() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 50,
            likes: 1,
            comments: 0,
            shares: 0,
            completion_rate: 0.1,
            engagement_rate: 0.02,
        };

        let score = calculate_performance_score(&alert);
        assert!(score <= 4, "Expected low score, got {}", score);
    }

    #[test]
    fn test_calculate_performance_score_moderate() {
        let alert = LowPerformanceAlert {
            target_id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            script_id: Some(Uuid::new_v4()),
            platform_id: "tiktok".to_string(),
            views: 500,
            likes: 25,
            comments: 10,
            shares: 5,
            completion_rate: 0.5,
            engagement_rate: 0.08,
        };

        let score = calculate_performance_score(&alert);
        assert!(
            score >= 4 && score <= 7,
            "Expected moderate score, got {}",
            score
        );
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

    #[test]
    fn test_default_thresholds() {
        let thresholds = PerformanceThresholds::default();
        assert_eq!(thresholds.min_views, 100);
        assert_eq!(thresholds.min_completion_rate, 0.3);
        assert_eq!(thresholds.min_engagement_rate, 0.01);
    }

    /// **P5 验收**: Platform-specific threshold overrides work correctly
    #[test]
    fn test_platform_specific_thresholds() {
        let mut thresholds = PerformanceThresholds::default();

        // Add platform-specific override for TikTok (higher thresholds)
        thresholds.platform_overrides.insert(
            "tiktok".to_string(),
            PlatformThresholds {
                min_views: Some(500),
                min_completion_rate: Some(0.4),
                min_engagement_rate: Some(0.02),
            },
        );

        // Add platform-specific override for Bilibili (lower completion rate)
        thresholds.platform_overrides.insert(
            "bilibili".to_string(),
            PlatformThresholds {
                min_views: None, // Use default
                min_completion_rate: Some(0.25),
                min_engagement_rate: None, // Use default
            },
        );

        // Test TikTok overrides
        let tiktok_effective = thresholds.for_platform("tiktok");
        assert_eq!(tiktok_effective.min_views, 500);
        assert_eq!(tiktok_effective.min_completion_rate, 0.4);
        assert_eq!(tiktok_effective.min_engagement_rate, 0.02);

        // Test Bilibili partial override
        let bilibili_effective = thresholds.for_platform("bilibili");
        assert_eq!(bilibili_effective.min_views, 100); // Default
        assert_eq!(bilibili_effective.min_completion_rate, 0.25); // Override
        assert_eq!(bilibili_effective.min_engagement_rate, 0.01); // Default

        // Test platform without override uses defaults
        let douyin_effective = thresholds.for_platform("douyin");
        assert_eq!(douyin_effective.min_views, 100);
        assert_eq!(douyin_effective.min_completion_rate, 0.3);
        assert_eq!(douyin_effective.min_engagement_rate, 0.01);
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
