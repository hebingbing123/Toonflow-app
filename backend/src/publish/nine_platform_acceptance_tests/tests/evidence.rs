//! Evidence and audit trail tests

use super::*;

#[test]
fn test_evidence_generation_for_all_modes() {
    let job = sample_job();
    let draft = sample_draft();
    let platform_id = "douyin";

    // Test sandbox evidence
    let sandbox_target = sample_target(platform_id, "semi_auto");
    let sandbox_result = run_target_adapter(&job, &draft, &sandbox_target);
    let sandbox_evidence = sandbox_result.detail.get("evidence").unwrap();
    assert!(sandbox_evidence.get("request_id").is_some());

    // Test live evidence
    let live_target = sample_target(platform_id, "full_auto");
    let live_result = run_target_adapter(&job, &draft, &live_target);
    let live_evidence = live_result.detail.get("evidence").unwrap();
    assert!(live_evidence.get("request_id").is_some());
    assert!(live_evidence.get("callback_id").is_some());

    // Test manual bridge evidence
    let manual_target = sample_target(platform_id, "manual_assisted");
    let manual_result = run_target_adapter(&job, &draft, &manual_target);
    let manual_evidence = manual_result.detail.get("evidence").unwrap();
    assert!(manual_evidence.get("manual_step_id").is_some());
}

#[test]
fn test_receipt_contains_required_fields() {
    let job = sample_job();
    let draft = sample_draft();

    for platform in ALL {
        let target = sample_target(platform.platform_id, "semi_auto");
        let result = run_target_adapter(&job, &draft, &target);

        let receipt = result.detail.get("receipt").unwrap();

        // Validate required receipt fields
        assert!(receipt.get("platform_id").is_some());
        assert!(receipt.get("external_video_id").is_some());
        assert!(receipt.get("published_at").is_some());
        assert!(receipt.get("mode").is_some());
        assert!(receipt.get("path").is_some());
        assert!(receipt.get("extra").is_some());

        // Validate external_video_id format
        let external_video_id = receipt
            .get("external_video_id")
            .and_then(|v| v.as_str())
            .unwrap();
        assert!(external_video_id.contains(platform.platform_id));
    }
}
