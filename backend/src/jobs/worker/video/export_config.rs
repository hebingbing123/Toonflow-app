// Task B3: Consumer integration for project-level short video configuration
// Requirements: 需求 2 - "单一配置源" (single source of truth)
//
// This module provides read-only access to project-level short video configuration
// for export default settings, demonstrating that downstream systems read from
// the centralized project configuration.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

/// Project-level short video configuration for export defaults
#[allow(dead_code)]
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct ExportDefaultConfig {
    /// Video aspect ratio for export (e.g., "9:16", "16:9", "1:1")
    pub video_ratio: Option<String>,
    /// Target platforms that may have specific export requirements
    pub target_platforms: Option<Vec<String>>,
    /// Target market (domestic/overseas) may affect encoding settings
    pub target_market: Option<String>,
    /// Duration strategy may affect export optimization
    pub duration_strategy: Option<String>,
}

/// Load project-level short video configuration for export defaults.
///
/// This function reads from the centralized project configuration (app_project table)
/// to provide default settings for video export, proving the "single source of truth"
/// principle.
///
/// # Consumer Integration Point 2: Export Default Settings
///
/// This function is called by export workflows to:
/// - Determine default aspect ratio for exported videos
/// - Apply platform-specific export constraints (resolution, bitrate, format)
/// - Configure encoding settings based on target market
/// - Optimize export parameters based on duration strategy
///
/// # Example Usage
///
/// ```rust,ignore
/// let config = load_export_default_config(pool, project_id).await?;
/// if let Some(ratio) = &config.video_ratio {
///     // Use ratio to determine export resolution
///     let resolution = match ratio.as_str() {
///         "9:16" => "1080x1920", // vertical
///         "16:9" => "1920x1080", // horizontal
///         "1:1" => "1080x1080",  // square
///         _ => "1920x1080",
///     };
/// }
/// if config.target_platforms.contains(&"douyin".to_string()) {
///     // Apply Douyin-specific export settings
/// }
/// ```
pub async fn load_export_default_config(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<ExportDefaultConfig, ApiError> {
    let row = sqlx::query_as::<_, ExportDefaultConfig>(
        r#"
        SELECT 
            video_ratio,
            target_platforms,
            target_market,
            duration_strategy
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

/// Resolve export resolution from video ratio configuration.
///
/// Maps the project's video_ratio to a concrete resolution string suitable
/// for export encoding parameters.
pub fn resolve_export_resolution(video_ratio: Option<&str>) -> &'static str {
    match video_ratio {
        Some("9:16") => "1080x1920", // vertical (short video standard)
        Some("16:9") => "1920x1080", // horizontal
        Some("1:1") => "1080x1080",  // square
        _ => "1920x1080",            // default to horizontal
    }
}

/// Check if a platform requires specific export constraints.
///
/// Returns true if the platform has known constraints that should be applied
/// during export (e.g., maximum duration, specific codecs, bitrate limits).
pub fn platform_has_export_constraints(platform: &str) -> bool {
    matches!(
        platform,
        "douyin" | "tiktok" | "youtube_shorts" | "instagram_reels" | "facebook_reels"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn export_default_config_structure() {
        let config = ExportDefaultConfig {
            video_ratio: Some("9:16".to_string()),
            target_platforms: Some(vec!["douyin".to_string(), "tiktok".to_string()]),
            target_market: Some("both".to_string()),
            duration_strategy: Some("short".to_string()),
        };

        assert_eq!(config.video_ratio, Some("9:16".to_string()));
        assert_eq!(config.target_platforms.as_ref().map(|v| v.len()), Some(2));
    }

    #[test]
    fn resolve_export_resolution_handles_all_ratios() {
        assert_eq!(resolve_export_resolution(Some("9:16")), "1080x1920");
        assert_eq!(resolve_export_resolution(Some("16:9")), "1920x1080");
        assert_eq!(resolve_export_resolution(Some("1:1")), "1080x1080");
        assert_eq!(resolve_export_resolution(None), "1920x1080");
        assert_eq!(resolve_export_resolution(Some("unknown")), "1920x1080");
    }

    #[test]
    fn platform_has_export_constraints_recognizes_major_platforms() {
        assert!(platform_has_export_constraints("douyin"));
        assert!(platform_has_export_constraints("tiktok"));
        assert!(platform_has_export_constraints("youtube_shorts"));
        assert!(platform_has_export_constraints("instagram_reels"));
        assert!(platform_has_export_constraints("facebook_reels"));
        assert!(!platform_has_export_constraints("unknown_platform"));
    }
}
