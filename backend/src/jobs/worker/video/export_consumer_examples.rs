// Task B3: Example usage of export config consumers
// Requirements: 需求 2 - Demonstrate "单一配置源" (single source of truth)
//
// This file provides example code showing how export workflows consume
// the centralized project-level short video configuration.

#![allow(dead_code)]

use sqlx::PgPool;
use uuid::Uuid;

use super::export_config::{
    load_export_default_config, platform_has_export_constraints, resolve_export_resolution,
};
use crate::error::ApiError;

/// Example 1: Export workflow consuming project config for default settings
///
/// This demonstrates how the export system reads from the centralized
/// project configuration to determine export parameters.
pub async fn example_export_with_project_config(
    pool: &PgPool,
    project_id: Uuid,
    _source_url: &str,
) -> Result<ExportParameters, ApiError> {
    // Load project-level configuration (single source of truth)
    let config = load_export_default_config(pool, project_id).await?;

    // Consumer 1: Use video_ratio to determine export resolution
    let resolution = resolve_export_resolution(config.video_ratio.as_deref());
    tracing::info!(
        video_ratio = config.video_ratio.as_deref(),
        resolution = resolution,
        "Using project-level video_ratio for export resolution"
    );

    // Consumer 2: Apply platform-specific export constraints
    let mut export_params = ExportParameters {
        resolution: resolution.to_string(),
        format: "mp4".to_string(),
        bitrate: "5M".to_string(),
        codec: "h264".to_string(),
    };

    if let Some(platforms) = &config.target_platforms {
        for platform in platforms {
            if platform_has_export_constraints(platform) {
                tracing::info!(
                    platform = platform,
                    "Applying platform-specific export constraints"
                );

                match platform.as_str() {
                    "douyin" => {
                        // Douyin constraints: max 60s, specific bitrate
                        export_params.bitrate = "4M".to_string();
                    }
                    "tiktok" => {
                        // TikTok constraints: max 60s, specific codec
                        export_params.codec = "h264".to_string();
                    }
                    "youtube_shorts" => {
                        // YouTube Shorts: max 60s, higher quality
                        export_params.bitrate = "8M".to_string();
                    }
                    "instagram_reels" | "facebook_reels" => {
                        // Meta platforms: specific constraints
                        export_params.bitrate = "6M".to_string();
                    }
                    _ => {}
                }
            }
        }
    }

    // Consumer 3: Adjust encoding based on target market
    if let Some(market) = &config.target_market {
        match market.as_str() {
            "domestic" => {
                tracing::info!("Optimizing export for domestic CDN delivery");
                // May use different encoding settings for domestic networks
            }
            "overseas" => {
                tracing::info!("Optimizing export for international CDN delivery");
                // May use different encoding settings for international networks
            }
            "both" => {
                tracing::info!("Using universal export settings");
            }
            _ => {}
        }
    }

    Ok(export_params)
}

/// Example 2: Batch export consuming project config
///
/// This demonstrates how batch export operations read from project config
/// to apply consistent settings across multiple videos.
pub async fn example_batch_export_with_config(
    pool: &PgPool,
    project_id: Uuid,
    video_urls: Vec<String>,
) -> Result<Vec<ExportParameters>, ApiError> {
    // Load project-level configuration once (single source of truth)
    let config = load_export_default_config(pool, project_id).await?;

    let resolution = resolve_export_resolution(config.video_ratio.as_deref());

    // Apply same project-level settings to all videos in batch
    let mut results = Vec::new();
    for url in video_urls {
        tracing::info!(
            url = url,
            resolution = resolution,
            "Exporting with project-level settings"
        );

        results.push(ExportParameters {
            resolution: resolution.to_string(),
            format: "mp4".to_string(),
            bitrate: "5M".to_string(),
            codec: "h264".to_string(),
        });
    }

    Ok(results)
}

/// Example 3: Platform-specific export variants
///
/// This demonstrates how to generate multiple export variants for different
/// platforms based on project config.
pub async fn example_multi_platform_export(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Vec<PlatformExportVariant>, ApiError> {
    let config = load_export_default_config(pool, project_id).await?;

    let base_resolution = resolve_export_resolution(config.video_ratio.as_deref());

    // Generate export variants for each target platform
    let mut variants = Vec::new();
    if let Some(platforms) = &config.target_platforms {
        for platform in platforms {
            let variant = match platform.as_str() {
                "douyin" => PlatformExportVariant {
                    platform: platform.clone(),
                    resolution: base_resolution.to_string(),
                    format: "mp4".to_string(),
                    max_duration: 60,
                    bitrate: "4M".to_string(),
                },
                "tiktok" => PlatformExportVariant {
                    platform: platform.clone(),
                    resolution: base_resolution.to_string(),
                    format: "mp4".to_string(),
                    max_duration: 60,
                    bitrate: "5M".to_string(),
                },
                "youtube_shorts" => PlatformExportVariant {
                    platform: platform.clone(),
                    resolution: base_resolution.to_string(),
                    format: "mp4".to_string(),
                    max_duration: 60,
                    bitrate: "8M".to_string(),
                },
                _ => PlatformExportVariant {
                    platform: platform.clone(),
                    resolution: base_resolution.to_string(),
                    format: "mp4".to_string(),
                    max_duration: 60,
                    bitrate: "5M".to_string(),
                },
            };

            tracing::info!(
                platform = platform,
                resolution = variant.resolution,
                "Generated export variant for platform"
            );

            variants.push(variant);
        }
    }

    Ok(variants)
}

#[derive(Debug, Clone)]
pub struct ExportParameters {
    pub resolution: String,
    pub format: String,
    pub bitrate: String,
    pub codec: String,
}

#[derive(Debug, Clone)]
pub struct PlatformExportVariant {
    pub platform: String,
    pub resolution: String,
    pub format: String,
    pub max_duration: u32,
    pub bitrate: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::jobs::worker::video::export_config::resolve_export_resolution;

    #[test]
    fn export_parameters_structure() {
        let params = ExportParameters {
            resolution: "1080x1920".to_string(),
            format: "mp4".to_string(),
            bitrate: "5M".to_string(),
            codec: "h264".to_string(),
        };

        assert_eq!(params.resolution, "1080x1920");
        assert_eq!(params.format, "mp4");
    }

    #[test]
    fn resolve_export_resolution_maps_ratios_correctly() {
        assert_eq!(resolve_export_resolution(Some("9:16")), "1080x1920");
        assert_eq!(resolve_export_resolution(Some("16:9")), "1920x1080");
        assert_eq!(resolve_export_resolution(Some("1:1")), "1080x1080");
        assert_eq!(resolve_export_resolution(None), "1920x1080");
    }

    #[test]
    fn platform_export_variant_structure() {
        let variant = PlatformExportVariant {
            platform: "douyin".to_string(),
            resolution: "1080x1920".to_string(),
            format: "mp4".to_string(),
            max_duration: 60,
            bitrate: "4M".to_string(),
        };

        assert_eq!(variant.platform, "douyin");
        assert_eq!(variant.max_duration, 60);
    }
}
