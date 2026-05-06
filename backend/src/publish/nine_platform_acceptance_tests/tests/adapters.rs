//! Adapter routing tests (capability detection)

use super::*;

#[test]
fn test_all_platforms_have_adapters() {
    let job = sample_job();
    let draft = sample_draft();

    // Test that all 9 platforms have working adapters
    for platform in ALL {
        let target = sample_target(platform.platform_id, "semi_auto");
        let result = run_target_adapter(&job, &draft, &target);

        assert_eq!(
            result.status, "succeeded",
            "Platform {} adapter should succeed",
            platform.platform_id
        );
        assert!(
            result.error_message.is_none(),
            "Platform {} should not have error",
            platform.platform_id
        );

        // Validate adapter name matches platform
        let adapter_name = result
            .detail
            .get("adapter")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert!(
            adapter_name.contains(platform.platform_id.split('_').next().unwrap()),
            "Adapter name {} should contain platform {}",
            adapter_name,
            platform.platform_id
        );
    }
}

#[test]
fn test_unsupported_platform_fails() {
    let job = sample_job();
    let draft = sample_draft();
    let target = sample_target("unsupported_platform", "semi_auto");

    let result = run_target_adapter(&job, &draft, &target);

    assert_eq!(result.status, "failed");
    assert!(result.error_message.is_some());
    assert_eq!(
        result
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .unwrap_or(""),
        "unknown"
    );
}
