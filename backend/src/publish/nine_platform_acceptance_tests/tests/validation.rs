//! Platform-specific validation tests

use super::*;

#[test]
fn test_platform_specific_constraints() {
    // Test that each platform has appropriate constraints
    for platform in ALL {
        let spec = spec_for_platform(platform.platform_id).unwrap();

        // All platforms should have reasonable limits
        assert!(
            spec.title_max_chars >= 60,
            "{} title limit too low",
            platform.platform_id
        );
        assert!(
            spec.tags_max >= 10,
            "{} tags limit too low",
            platform.platform_id
        );
        assert!(
            spec.description_max_chars >= 600,
            "{} description limit too low",
            platform.platform_id
        );

        // Validate automation mode is valid
        assert!(
            validate_automation_mode(spec.recommended_tier).is_ok(),
            "{} has invalid automation mode: {}",
            platform.platform_id,
            spec.recommended_tier
        );
    }
}

#[test]
fn test_domestic_platforms_require_cover() {
    // All domestic platforms should require cover images
    for platform in ALL {
        if matches!(
            platform.region,
            crate::publish::platform_registry::MarketRegion::Domestic
        ) {
            assert!(
                platform.requires_cover,
                "Domestic platform {} should require cover",
                platform.platform_id
            );
        }
    }
}

#[test]
fn test_overseas_platforms_cover_optional() {
    // Overseas platforms typically don't require cover
    for platform in ALL {
        if matches!(
            platform.region,
            crate::publish::platform_registry::MarketRegion::Overseas
        ) {
            assert!(
                !platform.requires_cover,
                "Overseas platform {} should not require cover",
                platform.platform_id
            );
        }
    }
}
