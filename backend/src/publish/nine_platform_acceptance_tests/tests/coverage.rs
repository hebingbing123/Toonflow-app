//! Coverage matrix summary test

use super::*;

#[test]
fn test_nine_platform_matrix_coverage() {
    // This test validates the complete coverage matrix:
    // 9 platforms × 3 delivery modes = 27 combinations

    let job = sample_job();
    let draft = sample_draft();
    let automation_modes = ["semi_auto", "full_auto", "manual_assisted"];
    let expected_delivery_modes = ["sandbox", "live", "manual_bridge"];

    let mut coverage_matrix = Vec::new();

    for platform in ALL {
        for (automation_mode, expected_delivery_mode) in
            automation_modes.iter().zip(expected_delivery_modes.iter())
        {
            let target = sample_target(platform.platform_id, automation_mode);
            let result = run_target_adapter(&job, &draft, &target);

            let delivery_mode = result
                .detail
                .get("delivery_mode")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(); // Convert to owned String

            coverage_matrix.push((
                platform.platform_id.to_string(),   // Convert to owned String
                automation_mode.to_string(),        // Convert to owned String
                expected_delivery_mode.to_string(), // Convert to owned String
                delivery_mode.clone(),
                result.status.to_string(), // Convert to owned String
            ));

            // Validate each combination
            assert_eq!(
                result.status, "succeeded",
                "Platform {} with mode {} should succeed",
                platform.platform_id, automation_mode
            );
            assert_eq!(
                delivery_mode, *expected_delivery_mode,
                "Platform {} with mode {} should have delivery_mode {}",
                platform.platform_id, automation_mode, expected_delivery_mode
            );
        }
    }

    // Validate we tested all 27 combinations
    assert_eq!(
        coverage_matrix.len(),
        27,
        "Should test 9 platforms × 3 modes = 27 combinations"
    );

    // Print coverage summary (visible with --nocapture)
    println!("\n=== Nine-Platform Matrix Coverage Summary ===");
    println!("Total combinations tested: {}", coverage_matrix.len());
    println!("\nPlatform Coverage:");
    for platform in ALL {
        let platform_tests: Vec<_> = coverage_matrix
            .iter()
            .filter(|(pid, _, _, _, _)| pid == platform.platform_id)
            .collect();
        println!(
            "  {} ({}): {} modes tested",
            platform.platform_id,
            platform.label_zh,
            platform_tests.len()
        );
    }
    println!("\nDelivery Mode Coverage:");
    for mode in expected_delivery_modes {
        let mode_tests: Vec<_> = coverage_matrix
            .iter()
            .filter(|(_, _, _, dm, _)| dm == mode)
            .collect();
        println!("  {}: {} platforms tested", mode, mode_tests.len());
    }
}
