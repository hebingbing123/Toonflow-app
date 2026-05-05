//! 短视频配置字段校验

use crate::error::ApiError;

/// 校验 mode 字段（动漫短剧 / 真人短剧）
///
/// 允许：`animated.short_drama` / `live_action.short_drama`（Space 与 PATCH 实际写入），以及历史值 `动漫` / `真人`。
pub(crate) fn validate_mode(mode: &str) -> Result<(), ApiError> {
    match mode {
        "动漫" | "真人" => Ok(()),
        "animated.short_drama" | "live_action.short_drama" => Ok(()),
        _ => Err(ApiError::BadRequest(format!(
            "mode must be 'animated.short_drama', 'live_action.short_drama', '动漫', or '真人', got '{}'",
            mode
        ))),
    }
}

/// 校验 target_market 字段
pub(crate) fn validate_target_market(market: &str) -> Result<(), ApiError> {
    match market {
        "domestic" | "overseas" | "both" => Ok(()),
        _ => Err(ApiError::BadRequest(format!(
            "target_market must be 'domestic', 'overseas', or 'both', got '{}'",
            market
        ))),
    }
}

/// 校验 duration_strategy 字段
pub(crate) fn validate_duration_strategy(strategy: &str) -> Result<(), ApiError> {
    match strategy {
        "short" | "medium" | "long" => Ok(()),
        _ => Err(ApiError::BadRequest(format!(
            "duration_strategy must be 'short', 'medium', or 'long', got '{}'",
            strategy
        ))),
    }
}

/// 校验 target_platforms 数组
pub(crate) fn validate_target_platforms(platforms: &[String]) -> Result<(), ApiError> {
    // 数组非空校验
    if platforms.is_empty() {
        return Err(ApiError::BadRequest(
            "target_platforms must not be empty".into(),
        ));
    }

    // 有效平台标识符列表（国内 + 海外）
    const VALID_PLATFORMS: &[&str] = &[
        // 国内平台
        "douyin",
        "bilibili",
        "xiaohongshu",
        "weixin_channels",
        "kuaishou",
        // 海外平台
        "tiktok",
        "youtube_shorts",
        "instagram_reels",
        "facebook_reels",
    ];

    for platform in platforms {
        if !VALID_PLATFORMS.contains(&platform.as_str()) {
            return Err(ApiError::BadRequest(format!(
                "invalid platform identifier '{}', must be one of: {}",
                platform,
                VALID_PLATFORMS.join(", ")
            )));
        }
    }

    Ok(())
}

/// 校验 quality_gate_strategy 字段
pub(crate) fn validate_quality_gate_strategy(strategy: &str) -> Result<(), ApiError> {
    match strategy {
        "off" | "warn" | "block" => Ok(()),
        _ => Err(ApiError::BadRequest(format!(
            "quality_gate_strategy must be 'off', 'warn', or 'block', got '{}'",
            strategy
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_mode() {
        assert!(validate_mode("动漫").is_ok());
        assert!(validate_mode("真人").is_ok());
        assert!(validate_mode("animated.short_drama").is_ok());
        assert!(validate_mode("live_action.short_drama").is_ok());
        assert!(validate_mode("invalid").is_err());
        assert!(validate_mode("anime").is_err());
    }

    #[test]
    fn test_validate_target_market() {
        assert!(validate_target_market("domestic").is_ok());
        assert!(validate_target_market("overseas").is_ok());
        assert!(validate_target_market("both").is_ok());
        assert!(validate_target_market("invalid").is_err());
        assert!(validate_target_market("china").is_err());
    }

    #[test]
    fn test_validate_duration_strategy() {
        assert!(validate_duration_strategy("short").is_ok());
        assert!(validate_duration_strategy("medium").is_ok());
        assert!(validate_duration_strategy("long").is_ok());
        assert!(validate_duration_strategy("invalid").is_err());
        assert!(validate_duration_strategy("very_long").is_err());
    }

    #[test]
    fn test_validate_target_platforms_empty() {
        let empty: Vec<String> = vec![];
        assert!(validate_target_platforms(&empty).is_err());
    }

    #[test]
    fn test_validate_target_platforms_valid() {
        let platforms = vec!["douyin".to_string(), "bilibili".to_string()];
        assert!(validate_target_platforms(&platforms).is_ok());

        let overseas = vec!["tiktok".to_string(), "youtube_shorts".to_string()];
        assert!(validate_target_platforms(&overseas).is_ok());

        let mixed = vec![
            "douyin".to_string(),
            "tiktok".to_string(),
            "bilibili".to_string(),
        ];
        assert!(validate_target_platforms(&mixed).is_ok());
    }

    #[test]
    fn test_validate_target_platforms_invalid() {
        let invalid = vec!["douyin".to_string(), "invalid_platform".to_string()];
        assert!(validate_target_platforms(&invalid).is_err());

        let typo = vec!["youtub_shorts".to_string()];
        assert!(validate_target_platforms(&typo).is_err());
    }

    #[test]
    fn test_validate_target_platforms_all_valid() {
        let all_platforms = vec![
            "douyin".to_string(),
            "bilibili".to_string(),
            "xiaohongshu".to_string(),
            "weixin_channels".to_string(),
            "kuaishou".to_string(),
            "tiktok".to_string(),
            "youtube_shorts".to_string(),
            "instagram_reels".to_string(),
            "facebook_reels".to_string(),
        ];
        assert!(validate_target_platforms(&all_platforms).is_ok());
    }

    #[test]
    fn test_validate_quality_gate_strategy() {
        assert!(validate_quality_gate_strategy("off").is_ok());
        assert!(validate_quality_gate_strategy("warn").is_ok());
        assert!(validate_quality_gate_strategy("block").is_ok());
        assert!(validate_quality_gate_strategy("invalid").is_err());
        assert!(validate_quality_gate_strategy("skip").is_err());
    }
}
