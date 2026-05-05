//! Publish job status guards (**E5**) — pure helpers + unit tests.

pub(crate) fn is_terminal_status(status: &str) -> bool {
    matches!(
        status,
        "succeeded" | "failed" | "cancelled" | "partial_failed"
    )
}

pub(crate) fn can_cancel(status: &str) -> bool {
    !is_terminal_status(status)
}

pub(crate) fn can_retry(status: &str) -> bool {
    matches!(status, "failed" | "cancelled" | "partial_failed")
}

pub(crate) fn can_confirm_semi_auto(status: &str) -> bool {
    status == "awaiting_confirmation"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn terminal_detection() {
        assert!(is_terminal_status("succeeded"));
        assert!(is_terminal_status("failed"));
        assert!(!is_terminal_status("queued"));
        assert!(!can_cancel("succeeded"));
        assert!(can_cancel("queued"));
        assert!(can_retry("failed"));
        assert!(!can_retry("queued"));
        assert!(can_confirm_semi_auto("awaiting_confirmation"));
        assert!(!can_confirm_semi_auto("uploading"));
    }
}
