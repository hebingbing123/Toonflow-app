//! Delivery mode tests (sandbox/live/manual_bridge)

use super::*;

#[test]
fn test_semi_auto_maps_to_sandbox() {
    let job = sample_job();
    let draft = sample_draft();

    for platform in ALL {
        let target = sample_target(platform.platform_id, "semi_auto");
        let result = run_target_adapter(&job, &draft, &target);

        let delivery_mode = result
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            delivery_mode, "sandbox",
            "semi_auto should map to sandbox for {}",
            platform.platform_id
        );

        let receipt_mode = result
            .detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            receipt_mode, "sandbox_closure",
            "semi_auto receipt mode should be sandbox_closure for {}",
            platform.platform_id
        );
    }
}

#[test]
fn test_full_auto_maps_to_live() {
    let job = sample_job();
    let draft = sample_draft();

    for platform in ALL {
        let target = sample_target(platform.platform_id, "full_auto");
        let result = run_target_adapter(&job, &draft, &target);

        let delivery_mode = result
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            delivery_mode, "live",
            "full_auto should map to live for {}",
            platform.platform_id
        );

        let receipt_mode = result
            .detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            receipt_mode, "live_api",
            "full_auto receipt mode should be live_api for {}",
            platform.platform_id
        );

        // Validate evidence contains request_id and callback_id for live mode
        let evidence = result.detail.get("evidence").unwrap();
        assert!(evidence.get("request_id").is_some());
        assert!(evidence.get("callback_id").is_some());
    }
}

#[test]
fn test_manual_assisted_maps_to_manual_bridge() {
    let job = sample_job();
    let draft = sample_draft();

    for platform in ALL {
        let target = sample_target(platform.platform_id, "manual_assisted");
        let result = run_target_adapter(&job, &draft, &target);

        let delivery_mode = result
            .detail
            .get("delivery_mode")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            delivery_mode, "manual_bridge",
            "manual_assisted should map to manual_bridge for {}",
            platform.platform_id
        );

        let receipt_mode = result
            .detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(
            receipt_mode, "manual_bridge",
            "manual_assisted receipt mode should be manual_bridge for {}",
            platform.platform_id
        );

        // Validate evidence contains manual_step_id for manual mode
        let evidence = result.detail.get("evidence").unwrap();
        assert!(evidence.get("manual_step_id").is_some());
    }
}
