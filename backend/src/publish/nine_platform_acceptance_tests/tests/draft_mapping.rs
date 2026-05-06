//! Draft-to-platform mapping tests

use super::*;

#[test]
fn test_draft_maps_to_all_platforms() {
    let job = sample_job();
    let draft = sample_draft();

    // Test that a single draft can be published to all 9 platforms
    for platform in ALL {
        let target = sample_target(platform.platform_id, "semi_auto");
        let result = run_target_adapter(&job, &draft, &target);

        assert_eq!(result.status, "succeeded");

        // Validate draft_id is preserved in result
        let result_draft_id = result
            .detail
            .get("draft_id")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(result_draft_id, draft.id.to_string());
    }
}

#[test]
fn test_multiple_targets_per_draft() {
    let job = sample_job();
    let draft = sample_draft();

    // Simulate publishing to multiple platforms simultaneously
    let platforms = ["douyin", "tiktok", "youtube_shorts"];
    let mut results = Vec::new();

    for platform_id in platforms {
        let target = sample_target(platform_id, "semi_auto");
        let result = run_target_adapter(&job, &draft, &target);
        results.push((platform_id, result));
    }

    // All should succeed
    for (platform_id, result) in results {
        assert_eq!(
            result.status, "succeeded",
            "Platform {} should succeed",
            platform_id
        );
    }
}
