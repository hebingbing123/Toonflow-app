//! Metrics fetching tests (real capability)

use super::*;

#[test]
fn test_sandbox_metrics_fetch_for_all_platforms() {
    // Test that sandbox metrics can be fetched for all platforms
    for platform in ALL {
        let external_video_id = format!("{}:test-123", platform.platform_id);
        let result =
            fetch_platform_metrics(platform.platform_id, &external_video_id, "sandbox");

        assert!(
            result.is_ok(),
            "Sandbox metrics should succeed for {}",
            platform.platform_id
        );

        let metrics = result.unwrap();
        assert_eq!(metrics.metric_window, "lifetime");
        assert!(metrics.views > 0);
        assert!(metrics.likes > 0);
        assert!(metrics.completion_rate > 0.0);
        assert!(metrics.completion_rate <= 1.0);

        // Validate source is sandbox
        let source = metrics
            .raw_payload
            .get("source")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert_eq!(source, "sandbox_metrics_mock");
    }
}

#[test]
fn test_live_metrics_fetch_capability() {
    // Test live metrics fetch (may succeed or fail based on availability)
    let platform_id = "douyin";
    let external_video_id = "douyin:live-456";

    let result = fetch_platform_metrics(platform_id, external_video_id, "live");

    // Live metrics may succeed or fail (simulating real API behavior)
    match result {
        Ok(metrics) => {
            assert_eq!(metrics.metric_window, "lifetime");
            assert!(metrics.views >= 2_000); // Live metrics have higher baseline
            let source = metrics
                .raw_payload
                .get("source")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            assert_eq!(source, "live_platform_api");
        }
        Err(e) => {
            // Expected failure case
            assert!(e.contains("unavailable") || e.contains("requires"));
        }
    }
}

#[test]
fn test_manual_bridge_metrics_fetch_capability() {
    // Test manual bridge metrics fetch
    let platform_id = "tiktok";
    let external_video_id = "tiktok:manual-789";

    let result = fetch_platform_metrics(platform_id, external_video_id, "manual_bridge");

    // Manual bridge metrics may succeed or fail
    match result {
        Ok(metrics) => {
            assert_eq!(metrics.metric_window, "lifetime");
            assert!(metrics.views >= 1_200); // Manual bridge has medium baseline
            let source = metrics
                .raw_payload
                .get("source")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            assert_eq!(source, "manual_bridge_receipt");
        }
        Err(e) => {
            // Expected failure case
            assert!(e.contains("not ready") || e.contains("requires"));
        }
    }
}

#[test]
fn test_metrics_fetch_requires_valid_delivery_mode() {
    let platform_id = "douyin";
    let external_video_id = "douyin:test-999";

    let result = fetch_platform_metrics(platform_id, external_video_id, "invalid_mode");

    assert!(result.is_err());
    assert!(result.unwrap_err().contains("unsupported delivery_mode"));
}

#[test]
fn test_metrics_fetch_requires_non_empty_video_id() {
    let platform_id = "douyin";

    // Test live mode with empty video ID
    let result = fetch_platform_metrics(platform_id, "", "live");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("requires non-empty"));

    // Test manual bridge with empty video ID
    let result = fetch_platform_metrics(platform_id, "", "manual_bridge");
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("requires non-empty"));
}
