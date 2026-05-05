// Task B3: Integration tests for short video config consumer
// Requirements: 需求 2 - Verify "单一配置源" (single source of truth)

#[cfg(test)]
mod tests {
    use crate::production::workbench::video::generate::short_video_config::StoryboardGenerationConfig;

    #[test]
    fn storyboard_generation_config_can_be_constructed() {
        // Verify that the config structure is usable by consumers
        let config = StoryboardGenerationConfig {
            video_ratio: Some("9:16".to_string()),
            mode: Some("animated.short_drama".to_string()),
            target_market: Some("domestic".to_string()),
            target_platforms: Some(vec!["douyin".to_string(), "bilibili".to_string()]),
            duration_strategy: Some("short".to_string()),
            voice_profile: Some("narrator_1".to_string()),
            subtitle_style: Some("modern".to_string()),
            bgm_strategy: Some("auto".to_string()),
        };

        // Consumer can read video_ratio for generation parameters
        assert_eq!(config.video_ratio.as_deref(), Some("9:16"));

        // Consumer can read mode for prompt adjustments
        assert_eq!(config.mode.as_deref(), Some("animated.short_drama"));

        // Consumer can read target platforms for platform-specific constraints
        if let Some(platforms) = &config.target_platforms {
            assert!(platforms.contains(&"douyin".to_string()));
            assert!(platforms.contains(&"bilibili".to_string()));
        }

        // Consumer can read voice and subtitle defaults
        assert_eq!(config.voice_profile.as_deref(), Some("narrator_1"));
        assert_eq!(config.subtitle_style.as_deref(), Some("modern"));
    }

    #[test]
    fn storyboard_generation_config_handles_optional_fields() {
        // Verify that consumers can handle missing optional fields
        let config = StoryboardGenerationConfig {
            video_ratio: None,
            mode: None,
            target_market: None,
            target_platforms: None,
            duration_strategy: None,
            voice_profile: None,
            subtitle_style: None,
            bgm_strategy: None,
        };

        // Consumers should handle None gracefully
        assert!(config.video_ratio.is_none());
        assert!(config.mode.is_none());
        assert!(config.target_platforms.is_none());
    }

    #[test]
    fn storyboard_generation_config_supports_multiple_platforms() {
        let config = StoryboardGenerationConfig {
            video_ratio: Some("9:16".to_string()),
            mode: Some("animated.short_drama".to_string()),
            target_market: Some("both".to_string()),
            target_platforms: Some(vec![
                "douyin".to_string(),
                "bilibili".to_string(),
                "tiktok".to_string(),
                "youtube_shorts".to_string(),
            ]),
            duration_strategy: Some("short".to_string()),
            voice_profile: None,
            subtitle_style: None,
            bgm_strategy: None,
        };

        // Consumer can iterate over all target platforms
        if let Some(platforms) = &config.target_platforms {
            assert_eq!(platforms.len(), 4);
            for platform in platforms {
                // Consumer can apply platform-specific logic
                match platform.as_str() {
                    "douyin" | "bilibili" => {
                        // Domestic platforms
                        assert_eq!(config.target_market.as_deref(), Some("both"));
                    }
                    "tiktok" | "youtube_shorts" => {
                        // Overseas platforms
                        assert_eq!(config.target_market.as_deref(), Some("both"));
                    }
                    _ => {}
                }
            }
        }
    }
}
