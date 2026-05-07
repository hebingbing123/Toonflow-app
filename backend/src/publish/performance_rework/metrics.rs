// Metrics collection and aggregation for performance monitoring

use crate::error::ApiError;
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

/// Calculate performance score (0-10) based on metrics
pub(crate) fn calculate_performance_score(alert: &LowPerformanceAlert) -> i16 {
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

#[cfg(test)]
mod tests {
    use super::*;

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
            (4..=7).contains(&score),
            "Expected moderate score, got {}",
            score
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
}
