// Task B3: Example usage of short video config consumers
// Requirements: 需求 2 - Demonstrate "单一配置源" (single source of truth)
//
// This file provides example code showing how downstream systems consume
// the centralized project-level short video configuration.

#![allow(dead_code)]

use sqlx::PgPool;
use uuid::Uuid;

use super::short_video_config::load_storyboard_generation_config;
use crate::error::ApiError;

/// Example 1: Storyboard generation workflow consuming project config
///
/// This demonstrates how the storyboard generation system reads from the
/// centralized project configuration to determine generation parameters.
pub async fn example_storyboard_generation_with_config(
    pool: &PgPool,
    project_id: Uuid,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    // Load project-level configuration (single source of truth)
    let config = load_storyboard_generation_config(pool, project_id).await?;

    // Consumer 1: Use video_ratio for generation request
    let aspect_ratio = config.video_ratio.as_deref().unwrap_or("16:9");
    tracing::info!(
        storyboard_id = storyboard_id,
        aspect_ratio = aspect_ratio,
        "Using project-level video_ratio for generation"
    );

    // Consumer 2: Apply mode-specific prompt adjustments
    if let Some(mode) = &config.mode {
        if mode.contains("live_action") {
            tracing::info!("Applying live-action prompt presets");
            // Apply live-action specific prompt adjustments
        } else if mode.contains("animated") {
            tracing::info!("Applying animated prompt presets");
            // Apply animated specific prompt adjustments
        }
    }

    // Consumer 3: Use voice_profile for narration
    if let Some(voice_profile) = &config.voice_profile {
        tracing::info!(
            voice_profile = voice_profile,
            "Using project-level voice profile"
        );
    }

    // Consumer 4: Use subtitle_style for subtitle generation
    if let Some(subtitle_style) = &config.subtitle_style {
        tracing::info!(
            subtitle_style = subtitle_style,
            "Using project-level subtitle style"
        );
    }

    // Consumer 5: Apply platform-specific constraints
    if let Some(platforms) = &config.target_platforms {
        for platform in platforms {
            match platform.as_str() {
                "douyin" => {
                    tracing::info!("Applying Douyin-specific constraints");
                    // Max duration, specific aspect ratios, etc.
                }
                "tiktok" => {
                    tracing::info!("Applying TikTok-specific constraints");
                }
                "youtube_shorts" => {
                    tracing::info!("Applying YouTube Shorts-specific constraints");
                }
                _ => {}
            }
        }
    }

    Ok(())
}

/// Example 2: Duration strategy affecting generation parameters
///
/// This demonstrates how duration_strategy from project config influences
/// the generation workflow.
pub async fn example_duration_strategy_consumer(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<u32, ApiError> {
    let config = load_storyboard_generation_config(pool, project_id).await?;

    // Consumer: Use duration_strategy to determine default video duration
    let default_duration = match config.duration_strategy.as_deref() {
        Some("short") => 15,  // 15 seconds for short videos
        Some("medium") => 30, // 30 seconds for medium videos
        Some("long") => 60,   // 60 seconds for long videos
        _ => 30,              // Default to 30 seconds
    };

    tracing::info!(
        duration_strategy = config.duration_strategy.as_deref(),
        default_duration = default_duration,
        "Using project-level duration strategy"
    );

    Ok(default_duration)
}

/// Example 3: Target market affecting content generation
///
/// This demonstrates how target_market from project config influences
/// content generation decisions.
pub async fn example_target_market_consumer(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<String, ApiError> {
    let config = load_storyboard_generation_config(pool, project_id).await?;

    // Consumer: Use target_market to adjust content style
    let content_style = match config.target_market.as_deref() {
        Some("domestic") => {
            tracing::info!("Optimizing for domestic market");
            "domestic_optimized".to_string()
        }
        Some("overseas") => {
            tracing::info!("Optimizing for overseas market");
            "international_optimized".to_string()
        }
        Some("both") => {
            tracing::info!("Optimizing for both markets");
            "universal_optimized".to_string()
        }
        _ => "default".to_string(),
    };

    Ok(content_style)
}

#[cfg(test)]
mod tests {
    #[test]
    fn example_functions_are_well_typed() {
        // These examples demonstrate the type-safe API for consumers
        // The functions compile, proving the consumer interface is usable
    }
}
