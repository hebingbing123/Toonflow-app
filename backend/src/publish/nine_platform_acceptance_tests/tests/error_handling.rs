//! Error handling tests

use super::*;

#[test]
fn test_error_handling_for_unsupported_platform() {
    let job = sample_job();
    let draft = sample_draft();
    let target = sample_target("fake_platform", "semi_auto");

    let result = run_target_adapter(&job, &draft, &target);

    assert_eq!(result.status, "failed");
    assert!(result.error_message.is_some());
    let error_msg = result.error_message.unwrap();
    assert!(error_msg.contains("unsupported"));
    assert!(error_msg.contains("fake_platform"));
}

#[test]
fn test_delivery_mode_consistency() {
    let job = sample_job();
    let draft = sample_draft();

    // Test that delivery_mode in detail matches automation_mode mapping
    let test_cases = vec![
        ("semi_auto", "sandbox"),
        ("full_auto", "live"),
        ("manual_assisted", "manual_bridge"),
    ];

    for (automation_mode, expected_delivery_mode) in test_cases {
        let target = sample_target("douyin", automation_mode);
        let result = run_target_adapter(&job, &draft, &target);

        let delivery_mode = result
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            delivery_mode, expected_delivery_mode,
            "automation_mode {} should map to delivery_mode {}",
            automation_mode, expected_delivery_mode
        );
    }
}
