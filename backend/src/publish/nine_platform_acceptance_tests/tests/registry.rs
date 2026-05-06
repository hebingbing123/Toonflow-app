//! Platform registry tests

use super::*;

#[test]
fn test_nine_platforms_registered() {
    // Validate that exactly 9 platforms are registered
    assert_eq!(
        ALL.len(),
        9,
        "Platform registry must contain exactly 9 platforms"
    );

    // Validate platform IDs are unique
    let mut seen = std::collections::HashSet::new();
    for platform in ALL {
        assert!(
            seen.insert(platform.platform_id),
            "Duplicate platform_id: {}",
            platform.platform_id
        );
    }
}

#[test]
fn test_domestic_platforms_count() {
    // Validate 5 domestic platforms
    let domestic_platforms: Vec<_> = ALL
        .iter()
        .filter(|p| {
            matches!(
                p.region,
                crate::publish::platform_registry::MarketRegion::Domestic
            )
        })
        .collect();

    assert_eq!(
        domestic_platforms.len(),
        5,
        "Must have exactly 5 domestic platforms"
    );

    // Validate expected domestic platforms
    let domestic_ids: Vec<&str> =
        domestic_platforms.iter().map(|p| p.platform_id).collect();
    assert!(domestic_ids.contains(&"douyin"));
    assert!(domestic_ids.contains(&"bilibili"));
    assert!(domestic_ids.contains(&"xiaohongshu"));
    assert!(domestic_ids.contains(&"weixin_channels"));
    assert!(domestic_ids.contains(&"kuaishou"));
}

#[test]
fn test_overseas_platforms_count() {
    // Validate 4 overseas platforms
    let overseas_platforms: Vec<_> = ALL
        .iter()
        .filter(|p| {
            matches!(
                p.region,
                crate::publish::platform_registry::MarketRegion::Overseas
            )
        })
        .collect();

    assert_eq!(
        overseas_platforms.len(),
        4,
        "Must have exactly 4 overseas platforms"
    );

    // Validate expected overseas platforms
    let overseas_ids: Vec<&str> =
        overseas_platforms.iter().map(|p| p.platform_id).collect();
    assert!(overseas_ids.contains(&"tiktok"));
    assert!(overseas_ids.contains(&"youtube_shorts"));
    assert!(overseas_ids.contains(&"instagram_reels"));
    assert!(overseas_ids.contains(&"facebook_reels"));
}

#[test]
fn test_platform_capability_lookup() {
    // Test that all 9 platforms can be looked up by ID
    let platform_ids = [
        "douyin",
        "bilibili",
        "xiaohongshu",
        "weixin_channels",
        "kuaishou",
        "tiktok",
        "youtube_shorts",
        "instagram_reels",
        "facebook_reels",
    ];

    for platform_id in platform_ids {
        let spec = spec_for_platform(platform_id);
        assert!(
            spec.is_some(),
            "Platform {} must be found in registry",
            platform_id
        );
        assert_eq!(spec.unwrap().platform_id, platform_id);
    }

    // Test unknown platform returns None
    assert!(spec_for_platform("unknown_platform").is_none());
}

#[test]
fn test_platform_capability_matrix_api() {
    // Test the API response format
    let matrix = capability_matrix();
    assert_eq!(matrix.len(), 9, "Matrix must contain 9 platforms");

    for row in matrix {
        // Validate required fields are present
        assert!(!row.platform_id.is_empty());
        assert!(!row.label_zh.is_empty());
        assert!(!row.market_region.is_empty());
        assert!(!row.automation_mode.is_empty());
        assert!(row.title_max_chars > 0);
        assert!(row.tags_max > 0);
        assert!(row.description_max_chars > 0);
    }
}
