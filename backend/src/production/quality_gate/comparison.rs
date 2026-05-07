//! Quality comparison across pipeline stages: storyboard → video → output.
//!
//! This module enables cross-stage quality tracking and degradation detection,
//! allowing the system to identify where quality issues are introduced in the pipeline.

use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::ApiError;

/// Quality metrics snapshot at a specific stage.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityMetrics {
    /// Generation stage (e.g., "storyboard_panel", "video_prompt")
    pub stage: Option<String>,
    /// Target type: "storyboard", "video", or "output"
    pub target_type: String,
    /// Overall quality score (1-10)
    pub overall_score: Option<i16>,
    /// Whether quality check passed
    pub passed: Option<bool>,
    /// Whether marked as bad case
    pub is_bad_case: bool,
    /// Number of reviews at this stage
    pub review_count: i64,
    /// Latest review ID
    pub latest_review_id: Option<Uuid>,
    /// Latest review timestamp
    pub latest_review_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// Quality progression across pipeline stages for a single storyboard.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StoryboardQualityProgression {
    /// Storyboard numeric ID
    pub storyboard_id: i32,
    /// Quality metrics at storyboard stage
    pub storyboard_quality: Option<QualityMetrics>,
    /// Quality metrics at video stage
    pub video_quality: Option<QualityMetrics>,
    /// Quality metrics at output stage
    pub output_quality: Option<QualityMetrics>,
    /// Whether quality degradation was detected
    pub quality_degradation_detected: bool,
    /// Stages where degradation occurred (e.g., ["storyboard_to_video"])
    pub degradation_stages: Vec<String>,
}

/// Quality degradation summary for a project or script.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityDegradationSummary {
    /// Project numeric ID
    pub project_id: i32,
    /// Script numeric ID (if filtered by script)
    pub script_id: Option<i32>,
    /// Total storyboards analyzed
    pub total_storyboards: i64,
    /// Storyboards with detected degradation
    pub storyboards_with_degradation: i64,
    /// Degradation rate as percentage
    pub degradation_rate_percent: f64,
    /// Common degradation stage transitions: (from_stage, to_stage, count)
    pub common_degradation_stages: Vec<(String, String, i64)>,
}

/// Quality comparison between two stages.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityComparison {
    /// Storyboard numeric ID
    pub storyboard_id: i32,
    /// Quality at earlier stage
    pub from_quality: Option<QualityMetrics>,
    /// Quality at later stage
    pub to_quality: Option<QualityMetrics>,
    /// Score delta (negative means degradation)
    pub score_delta: Option<i16>,
    /// Whether degradation detected
    pub degraded: bool,
}

#[derive(Debug, sqlx::FromRow)]
struct QualityProgressionRow {
    storyboard_id: i32,
    // Storyboard stage
    sb_score: Option<i16>,
    sb_passed: Option<bool>,
    sb_bad_case: Option<bool>,
    sb_review_count: Option<i64>,
    sb_latest_review_id: Option<Uuid>,
    sb_latest_review_at: Option<chrono::DateTime<chrono::Utc>>,
    sb_stage: Option<String>,
    // Video stage
    video_score: Option<i16>,
    video_passed: Option<bool>,
    video_bad_case: Option<bool>,
    video_review_count: Option<i64>,
    video_latest_review_id: Option<Uuid>,
    video_latest_review_at: Option<chrono::DateTime<chrono::Utc>>,
    video_stage: Option<String>,
    // Output stage
    output_score: Option<i16>,
    output_passed: Option<bool>,
    output_bad_case: Option<bool>,
    output_review_count: Option<i64>,
    output_latest_review_id: Option<Uuid>,
    output_latest_review_at: Option<chrono::DateTime<chrono::Utc>>,
    output_stage: Option<String>,
}

/// Fetch quality progression for a set of storyboards.
///
/// Returns quality metrics at storyboard, video, and output stages,
/// with degradation detection.
pub async fn fetch_storyboard_quality_progression(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    storyboard_ids: &[i32],
) -> Result<Vec<StoryboardQualityProgression>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(Vec::new());
    }

    let rows = sqlx::query_as::<_, QualityProgressionRow>(
        r#"
        WITH storyboard_quality AS (
          SELECT 
            target_id::int AS storyboard_id,
            MAX(overall_score) AS overall_score,
            BOOL_OR(passed) AS passed,
            BOOL_OR(is_bad_case) AS is_bad_case,
            COUNT(*) AS review_count,
            (ARRAY_AGG(id ORDER BY created_at DESC))[1] AS latest_review_id,
            MAX(created_at) AS latest_review_at,
            (ARRAY_AGG(stage ORDER BY created_at DESC))[1] AS stage
          FROM app_quality_review
          WHERE user_id = $1
            AND project_id = $2
            AND target_type = 'storyboard'
            AND target_id ~ '^[0-9]+$'
            AND (target_id::int) = ANY($3)
          GROUP BY target_id
        ),
        video_quality AS (
          SELECT 
            target_id::int AS storyboard_id,
            MAX(overall_score) AS overall_score,
            BOOL_OR(passed) AS passed,
            BOOL_OR(is_bad_case) AS is_bad_case,
            COUNT(*) AS review_count,
            (ARRAY_AGG(id ORDER BY created_at DESC))[1] AS latest_review_id,
            MAX(created_at) AS latest_review_at,
            (ARRAY_AGG(stage ORDER BY created_at DESC))[1] AS stage
          FROM app_quality_review
          WHERE user_id = $1
            AND project_id = $2
            AND target_type = 'video'
            AND target_id ~ '^[0-9]+$'
            AND (target_id::int) = ANY($3)
          GROUP BY target_id
        ),
        output_quality AS (
          SELECT 
            target_id::int AS storyboard_id,
            MAX(overall_score) AS overall_score,
            BOOL_OR(passed) AS passed,
            BOOL_OR(is_bad_case) AS is_bad_case,
            COUNT(*) AS review_count,
            (ARRAY_AGG(id ORDER BY created_at DESC))[1] AS latest_review_id,
            MAX(created_at) AS latest_review_at,
            (ARRAY_AGG(stage ORDER BY created_at DESC))[1] AS stage
          FROM app_quality_review
          WHERE user_id = $1
            AND project_id = $2
            AND target_type = 'output'
            AND target_id ~ '^[0-9]+$'
            AND (target_id::int) = ANY($3)
          GROUP BY target_id
        ),
        all_storyboards AS (
          SELECT DISTINCT unnest($3::int[]) AS storyboard_id
        )
        SELECT 
          a.storyboard_id,
          sb.overall_score AS sb_score,
          sb.passed AS sb_passed,
          sb.is_bad_case AS sb_bad_case,
          sb.review_count AS sb_review_count,
          sb.latest_review_id AS sb_latest_review_id,
          sb.latest_review_at AS sb_latest_review_at,
          sb.stage AS sb_stage,
          v.overall_score AS video_score,
          v.passed AS video_passed,
          v.is_bad_case AS video_bad_case,
          v.review_count AS video_review_count,
          v.latest_review_id AS video_latest_review_id,
          v.latest_review_at AS video_latest_review_at,
          v.stage AS video_stage,
          o.overall_score AS output_score,
          o.passed AS output_passed,
          o.is_bad_case AS output_bad_case,
          o.review_count AS output_review_count,
          o.latest_review_id AS output_latest_review_id,
          o.latest_review_at AS output_latest_review_at,
          o.stage AS output_stage
        FROM all_storyboards a
        LEFT JOIN storyboard_quality sb ON sb.storyboard_id = a.storyboard_id
        LEFT JOIN video_quality v ON v.storyboard_id = a.storyboard_id
        LEFT JOIN output_quality o ON o.storyboard_id = a.storyboard_id
        ORDER BY a.storyboard_id ASC
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows.into_iter().map(row_to_progression).collect())
}

fn row_to_progression(row: QualityProgressionRow) -> StoryboardQualityProgression {
    let storyboard_quality = if row.sb_review_count.unwrap_or(0) > 0 {
        Some(QualityMetrics {
            stage: row.sb_stage,
            target_type: "storyboard".to_string(),
            overall_score: row.sb_score,
            passed: row.sb_passed,
            is_bad_case: row.sb_bad_case.unwrap_or(false),
            review_count: row.sb_review_count.unwrap_or(0),
            latest_review_id: row.sb_latest_review_id,
            latest_review_at: row.sb_latest_review_at,
        })
    } else {
        None
    };

    let video_quality = if row.video_review_count.unwrap_or(0) > 0 {
        Some(QualityMetrics {
            stage: row.video_stage,
            target_type: "video".to_string(),
            overall_score: row.video_score,
            passed: row.video_passed,
            is_bad_case: row.video_bad_case.unwrap_or(false),
            review_count: row.video_review_count.unwrap_or(0),
            latest_review_id: row.video_latest_review_id,
            latest_review_at: row.video_latest_review_at,
        })
    } else {
        None
    };

    let output_quality = if row.output_review_count.unwrap_or(0) > 0 {
        Some(QualityMetrics {
            stage: row.output_stage,
            target_type: "output".to_string(),
            overall_score: row.output_score,
            passed: row.output_passed,
            is_bad_case: row.output_bad_case.unwrap_or(false),
            review_count: row.output_review_count.unwrap_or(0),
            latest_review_id: row.output_latest_review_id,
            latest_review_at: row.output_latest_review_at,
        })
    } else {
        None
    };

    let (quality_degradation_detected, degradation_stages) =
        detect_degradation(&storyboard_quality, &video_quality, &output_quality);

    StoryboardQualityProgression {
        storyboard_id: row.storyboard_id,
        storyboard_quality,
        video_quality,
        output_quality,
        quality_degradation_detected,
        degradation_stages,
    }
}

/// Detect quality degradation between stages.
///
/// Degradation is detected when:
/// - Overall score drops by ≥2 points between stages
/// - `passed` changes from true to false
/// - New bad_case appears in later stage
fn detect_degradation(
    storyboard: &Option<QualityMetrics>,
    video: &Option<QualityMetrics>,
    output: &Option<QualityMetrics>,
) -> (bool, Vec<String>) {
    let mut degraded = false;
    let mut stages = Vec::new();

    // Check storyboard → video degradation
    if let (Some(sb), Some(v)) = (storyboard, video) {
        if is_degraded(sb, v) {
            degraded = true;
            stages.push("storyboard_to_video".to_string());
        }
    }

    // Check video → output degradation
    if let (Some(v), Some(o)) = (video, output) {
        if is_degraded(v, o) {
            degraded = true;
            stages.push("video_to_output".to_string());
        }
    }

    // Check storyboard → output degradation (skip video)
    if let (Some(sb), Some(o)) = (storyboard, output) {
        if video.is_none() && is_degraded(sb, o) {
            degraded = true;
            stages.push("storyboard_to_output".to_string());
        }
    }

    (degraded, stages)
}

/// Check if quality degraded from earlier to later stage.
fn is_degraded(earlier: &QualityMetrics, later: &QualityMetrics) -> bool {
    // Score degradation: drop by ≥2 points
    if let (Some(earlier_score), Some(later_score)) = (earlier.overall_score, later.overall_score) {
        if earlier_score - later_score >= 2 {
            return true;
        }
    }

    // Pass status degradation: passed → failed
    if let (Some(true), Some(false)) = (earlier.passed, later.passed) {
        return true;
    }

    // Bad case introduction: not bad → bad
    if !earlier.is_bad_case && later.is_bad_case {
        return true;
    }

    false
}

/// Detect quality degradation summary for a project or script.
pub async fn detect_quality_degradation(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: Option<i32>,
) -> Result<QualityDegradationSummary, ApiError> {
    // Fetch all storyboard IDs for the project/script
    let storyboard_ids: Vec<i32> = if let Some(script_id) = script_id {
        sqlx::query_scalar(
            r#"
            SELECT sb.numeric_id
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE p.numeric_id = $2
              AND sc.numeric_id = $3
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
              )
            ORDER BY sb.numeric_id ASC
            "#,
        )
        .bind(user_id)
        .bind(project_id)
        .bind(script_id)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_scalar(
            r#"
            SELECT sb.numeric_id
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE p.numeric_id = $2
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
              )
            ORDER BY sb.numeric_id ASC
            "#,
        )
        .bind(user_id)
        .bind(project_id)
        .fetch_all(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if storyboard_ids.is_empty() {
        return Ok(QualityDegradationSummary {
            project_id,
            script_id,
            total_storyboards: 0,
            storyboards_with_degradation: 0,
            degradation_rate_percent: 0.0,
            common_degradation_stages: Vec::new(),
        });
    }

    // Fetch quality progression for all storyboards
    let progressions =
        fetch_storyboard_quality_progression(pool, user_id, project_id, &storyboard_ids).await?;

    let total_storyboards = progressions.len() as i64;
    let storyboards_with_degradation = progressions
        .iter()
        .filter(|p| p.quality_degradation_detected)
        .count() as i64;

    let degradation_rate_percent = if total_storyboards > 0 {
        (storyboards_with_degradation as f64 / total_storyboards as f64) * 100.0
    } else {
        0.0
    };

    // Count degradation by stage transition
    let mut stage_counts: std::collections::HashMap<String, i64> = std::collections::HashMap::new();
    for progression in &progressions {
        for stage in &progression.degradation_stages {
            *stage_counts.entry(stage.clone()).or_insert(0) += 1;
        }
    }

    let mut common_degradation_stages: Vec<(String, String, i64)> = stage_counts
        .into_iter()
        .map(|(stage, count)| {
            let parts: Vec<&str> = stage.split("_to_").collect();
            let from = parts.first().unwrap_or(&"unknown").to_string();
            let to = parts.get(1).unwrap_or(&"unknown").to_string();
            (from, to, count)
        })
        .collect();

    common_degradation_stages.sort_by(|a, b| b.2.cmp(&a.2));

    Ok(QualityDegradationSummary {
        project_id,
        script_id,
        total_storyboards,
        storyboards_with_degradation,
        degradation_rate_percent,
        common_degradation_stages,
    })
}

/// Compare quality metrics between two stages.
pub async fn compare_stage_quality(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    from_stage: &str,
    to_stage: &str,
    storyboard_ids: &[i32],
) -> Result<Vec<QualityComparison>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(Vec::new());
    }

    // Fetch quality progression
    let progressions =
        fetch_storyboard_quality_progression(pool, user_id, project_id, storyboard_ids).await?;

    // Map stage names to quality metrics
    let comparisons: Vec<QualityComparison> = progressions
        .into_iter()
        .map(|p| {
            let from_quality = match from_stage {
                "storyboard" => p.storyboard_quality.clone(),
                "video" => p.video_quality.clone(),
                "output" => p.output_quality.clone(),
                _ => None,
            };

            let to_quality = match to_stage {
                "storyboard" => p.storyboard_quality.clone(),
                "video" => p.video_quality.clone(),
                "output" => p.output_quality.clone(),
                _ => None,
            };

            let score_delta = match (&from_quality, &to_quality) {
                (Some(from), Some(to)) => match (from.overall_score, to.overall_score) {
                    (Some(from_score), Some(to_score)) => Some(to_score - from_score),
                    _ => None,
                },
                _ => None,
            };

            let degraded = if let (Some(from), Some(to)) = (&from_quality, &to_quality) {
                is_degraded(from, to)
            } else {
                false
            };

            QualityComparison {
                storyboard_id: p.storyboard_id,
                from_quality,
                to_quality,
                score_delta,
                degraded,
            }
        })
        .collect();

    Ok(comparisons)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_degradation_score_drop() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(8),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let video = Some(QualityMetrics {
            stage: Some("video_prompt".to_string()),
            target_type: "video".to_string(),
            overall_score: Some(6),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, stages) = detect_degradation(&storyboard, &video, &None);
        assert!(degraded);
        assert_eq!(stages, vec!["storyboard_to_video"]);
    }

    #[test]
    fn test_detect_degradation_pass_to_fail() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(7),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let video = Some(QualityMetrics {
            stage: Some("video_prompt".to_string()),
            target_type: "video".to_string(),
            overall_score: Some(7),
            passed: Some(false),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, stages) = detect_degradation(&storyboard, &video, &None);
        assert!(degraded);
        assert_eq!(stages, vec!["storyboard_to_video"]);
    }

    #[test]
    fn test_detect_degradation_bad_case_introduction() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(8),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let video = Some(QualityMetrics {
            stage: Some("video_prompt".to_string()),
            target_type: "video".to_string(),
            overall_score: Some(8),
            passed: Some(true),
            is_bad_case: true,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, stages) = detect_degradation(&storyboard, &video, &None);
        assert!(degraded);
        assert_eq!(stages, vec!["storyboard_to_video"]);
    }

    #[test]
    fn test_no_degradation_improvement() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(6),
            passed: Some(false),
            is_bad_case: true,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let video = Some(QualityMetrics {
            stage: Some("video_prompt".to_string()),
            target_type: "video".to_string(),
            overall_score: Some(8),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, _stages) = detect_degradation(&storyboard, &video, &None);
        assert!(!degraded);
    }

    #[test]
    fn test_detect_degradation_multiple_stages() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(9),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let video = Some(QualityMetrics {
            stage: Some("video_prompt".to_string()),
            target_type: "video".to_string(),
            overall_score: Some(7),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let output = Some(QualityMetrics {
            stage: None,
            target_type: "output".to_string(),
            overall_score: Some(5),
            passed: Some(false),
            is_bad_case: true,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, stages) = detect_degradation(&storyboard, &video, &output);
        assert!(degraded);
        assert_eq!(stages.len(), 2);
        assert!(stages.contains(&"storyboard_to_video".to_string()));
        assert!(stages.contains(&"video_to_output".to_string()));
    }

    #[test]
    fn test_no_degradation_missing_stages() {
        let storyboard = Some(QualityMetrics {
            stage: Some("storyboard_panel".to_string()),
            target_type: "storyboard".to_string(),
            overall_score: Some(8),
            passed: Some(true),
            is_bad_case: false,
            review_count: 1,
            latest_review_id: None,
            latest_review_at: None,
        });

        let (degraded, stages) = detect_degradation(&storyboard, &None, &None);
        assert!(!degraded);
        assert!(stages.is_empty());
    }
}
