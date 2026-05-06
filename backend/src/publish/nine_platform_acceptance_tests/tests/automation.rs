//! Automation mode validation tests

use super::*;

#[test]
fn test_valid_automation_modes() {
    let valid_modes = ["full_auto", "semi_auto", "manual_assisted"];

    for mode in valid_modes {
        assert!(
            validate_automation_mode(mode).is_ok(),
            "Mode {} should be valid",
            mode
        );
    }
}

#[test]
fn test_invalid_automation_modes() {
    let invalid_modes = ["invalid", "auto", "manual", "", "FULL_AUTO"];

    for mode in invalid_modes {
        assert!(
            validate_automation_mode(mode).is_err(),
            "Mode {} should be invalid",
            mode
        );
    }
}
