//! Integration tests for short video configuration validation
//! These tests verify that validation is properly applied in the API endpoints

#[cfg(test)]
mod tests {
    use crate::error::ApiError;
    use crate::projects::routes::validation::{
        validate_duration_strategy, validate_mode, validate_target_market,
        validate_target_platforms,
    };

    #[test]
    fn test_mode_validation_in_api_context() {
        // Valid modes
        assert!(validate_mode("动漫").is_ok());
        assert!(validate_mode("真人").is_ok());

        // Invalid modes should return BadRequest
        let result = validate_mode("anime");
        assert!(matches!(result, Err(ApiError::BadRequest(_))));
        if let Err(ApiError::BadRequest(msg)) = result {
            assert!(msg.contains("mode must be"));
            assert!(msg.contains("动漫"));
            assert!(msg.contains("真人"));
        }
    }

    #[test]
    fn test_target_market_validation_in_api_context() {
        // Valid markets
        assert!(validate_target_market("domestic").is_ok());
        assert!(validate_target_market("overseas").is_ok());
        assert!(validate_target_market("both").is_ok());

        // Invalid market
        let result = validate_target_market("china");
        assert!(matches!(result, Err(ApiError::BadRequest(_))));
        if let Err(ApiError::BadRequest(msg)) = result {
            assert!(msg.contains("target_market must be"));
        }
    }

    #[test]
    fn test_duration_strategy_validation_in_api_context() {
        // Valid strategies
        assert!(validate_duration_strategy("short").is_ok());
        assert!(validate_duration_strategy("medium").is_ok());
        assert!(validate_duration_strategy("long").is_ok());

        // Invalid strategy
        let result = validate_duration_strategy("very_long");
        assert!(matches!(result, Err(ApiError::BadRequest(_))));
    }

    #[test]
    fn test_target_platforms_validation_comprehensive() {
        // Empty array should fail
        let empty: Vec<String> = vec![];
        assert!(validate_target_platforms(&empty).is_err());

        // Valid domestic platforms
        let domestic = vec![
            "douyin".to_string(),
            "bilibili".to_string(),
            "xiaohongshu".to_string(),
            "weixin_channels".to_string(),
            "kuaishou".to_string(),
        ];
        assert!(validate_target_platforms(&domestic).is_ok());

        // Valid overseas platforms
        let overseas = vec![
            "tiktok".to_string(),
            "youtube_shorts".to_string(),
            "instagram_reels".to_string(),
            "facebook_reels".to_string(),
        ];
        assert!(validate_target_platforms(&overseas).is_ok());

        // Mixed valid platforms
        let mixed = vec![
            "douyin".to_string(),
            "tiktok".to_string(),
            "bilibili".to_string(),
            "youtube_shorts".to_string(),
        ];
        assert!(validate_target_platforms(&mixed).is_ok());

        // Invalid platform in list
        let invalid = vec!["douyin".to_string(), "invalid_platform".to_string()];
        let result = validate_target_platforms(&invalid);
        assert!(matches!(result, Err(ApiError::BadRequest(_))));
        if let Err(ApiError::BadRequest(msg)) = result {
            assert!(msg.contains("invalid platform identifier"));
            assert!(msg.contains("invalid_platform"));
        }
    }

    #[test]
    fn test_validation_error_messages_are_actionable() {
        // Mode error should list valid options
        if let Err(ApiError::BadRequest(msg)) = validate_mode("wrong") {
            assert!(msg.contains("动漫"));
            assert!(msg.contains("真人"));
        }

        // Market error should list valid options
        if let Err(ApiError::BadRequest(msg)) = validate_target_market("wrong") {
            assert!(msg.contains("domestic"));
            assert!(msg.contains("overseas"));
            assert!(msg.contains("both"));
        }

        // Strategy error should list valid options
        if let Err(ApiError::BadRequest(msg)) = validate_duration_strategy("wrong") {
            assert!(msg.contains("short"));
            assert!(msg.contains("medium"));
            assert!(msg.contains("long"));
        }

        // Platform error should list valid platforms
        let invalid = vec!["wrong".to_string()];
        if let Err(ApiError::BadRequest(msg)) = validate_target_platforms(&invalid) {
            assert!(msg.contains("douyin"));
            assert!(msg.contains("tiktok"));
            assert!(msg.contains("bilibili"));
        }
    }
}
