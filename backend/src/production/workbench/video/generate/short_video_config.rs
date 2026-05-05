// Task B3: Consumer integration for project-level short video configuration
// Requirements: 需求 2 - "单一配置源" (single source of truth)
//
// This module provides read-only access to project-level short video configuration
// for storyboard generation parameters, demonstrating that downstream systems
// read from the centralized project configuration.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// Project-level short video configuration for storyboard generation
#[allow(dead_code)]
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct StoryboardGenerationConfig {
    /// Video aspect ratio (e.g., "9:16", "16:9", "1:1")
    pub video_ratio: Option<String>,
    /// Production mode (e.g., "animated.short_drama", "live_action.short_drama")
    pub mode: Option<String>,
    /// Target market (e.g., "domestic", "overseas", "both")
    pub target_market: Option<String>,
    /// Target platforms (e.g., ["douyin", "bilibili", "tiktok"])
    pub target_platforms: Option<Vec<String>>,
    /// Duration strategy (e.g., "short", "medium", "long")
    pub duration_strategy: Option<String>,
    /// Voice profile identifier for narration
    pub voice_profile: Option<String>,
    /// Subtitle style identifier
    pub subtitle_style: Option<String>,
    /// Background music strategy
    pub bgm_strategy: Option<String>,
}

/// Load project-level short video configuration for storyboard generation.
///
/// This function reads from the centralized project configuration (app_project table)
/// to provide parameters for storyboard generation, proving the "single source of truth"
/// principle.
///
/// # Consumer Integration Point 1: Storyboard Generation Parameters
///
/// This function is called by storyboard generation workflows to:
/// - Determine video aspect ratio for generation requests
/// - Apply mode-specific prompt presets (animated vs live-action)
/// - Configure voice and subtitle defaults
/// - Apply platform-specific constraints
///
/// # Example Usage
///
/// ```rust,ignore
/// let config = load_storyboard_generation_config(pool, project_id).await?;
/// if let Some(ratio) = &config.video_ratio {
///     // Use ratio for video generation request
/// }
/// if let Some(mode) = &config.mode {
///     // Apply mode-specific prompt adjustments
/// }
/// ```
pub async fn load_storyboard_generation_config(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<StoryboardGenerationConfig, ApiError> {
    let row = sqlx::query_as::<_, StoryboardGenerationConfig>(
        r#"
        SELECT 
            video_ratio,
            mode,
            target_market,
            target_platforms,
            duration_strategy,
            voice_profile,
            subtitle_style,
            bgm_strategy
        FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| match e {
        sqlx::Error::RowNotFound => ApiError::NotFound,
        _ => ApiError::DatabaseError(e.to_string()),
    })?;

    Ok(row)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn storyboard_generation_config_structure() {
        // Verify the config structure is well-formed
        let config = StoryboardGenerationConfig {
            video_ratio: Some("9:16".to_string()),
            mode: Some("animated.short_drama".to_string()),
            target_market: Some("domestic".to_string()),
            target_platforms: Some(vec!["douyin".to_string(), "bilibili".to_string()]),
            duration_strategy: Some("short".to_string()),
            voice_profile: Some("default_narrator".to_string()),
            subtitle_style: Some("modern".to_string()),
            bgm_strategy: Some("auto".to_string()),
        };

        assert_eq!(config.video_ratio, Some("9:16".to_string()));
        assert_eq!(config.mode, Some("animated.short_drama".to_string()));
        assert_eq!(config.target_platforms.as_ref().map(|v| v.len()), Some(2));
    }
}
