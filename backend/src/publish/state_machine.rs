//! Publish job status guards (**E5** + **P10**) — pure helpers + unit tests.

/// **P10**: 生产级状态机，包含人工桥接、回调超时、补偿等状态
pub(crate) fn is_terminal_status(status: &str) -> bool {
    matches!(
        status,
        "succeeded" | "failed" | "cancelled" | "partial_failed"
    )
}

/// **P10**: 人工桥接待处理状态（需要人工操作才能继续）
#[allow(dead_code)]
pub(crate) fn is_manual_pending(status: &str) -> bool {
    status == "manual_pending"
}

/// **P10**: 回调超时状态（平台回调未在预期时间内到达）
#[allow(dead_code)]
pub(crate) fn is_callback_timeout(status: &str) -> bool {
    status == "callback_timeout"
}

/// **P10**: 补偿中状态（系统正在执行补偿逻辑）
#[allow(dead_code)]
pub(crate) fn is_compensating(status: &str) -> bool {
    status == "compensating"
}

pub(crate) fn can_cancel(status: &str) -> bool {
    !is_terminal_status(status)
}

pub(crate) fn can_retry(status: &str) -> bool {
    matches!(
        status,
        "failed" | "cancelled" | "partial_failed" | "callback_timeout"
    )
}

pub(crate) fn can_confirm_semi_auto(status: &str) -> bool {
    status == "awaiting_confirmation"
}

/// **P10**: 是否可以触发补偿（从 callback_timeout 或 platform_processing 超时）
#[allow(dead_code)]
pub(crate) fn can_compensate(status: &str) -> bool {
    matches!(status, "callback_timeout" | "platform_processing")
}

/// **P10**: 是否可以完成人工桥接（从 manual_pending 到下一状态）
#[allow(dead_code)]
pub(crate) fn can_complete_manual_bridge(status: &str) -> bool {
    status == "manual_pending"
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

    /// **P10 验收**: 新增生产状态的识别和转换规则
    #[test]
    fn p10_production_states() {
        // 测试新状态识别
        assert!(is_manual_pending("manual_pending"));
        assert!(!is_manual_pending("queued"));

        assert!(is_callback_timeout("callback_timeout"));
        assert!(!is_callback_timeout("failed"));

        assert!(is_compensating("compensating"));
        assert!(!is_compensating("uploading"));

        // 测试 callback_timeout 可以重试
        assert!(can_retry("callback_timeout"));
        assert!(can_retry("failed"));
        assert!(!can_retry("succeeded"));

        // 测试补偿触发条件
        assert!(can_compensate("callback_timeout"));
        assert!(can_compensate("platform_processing"));
        assert!(!can_compensate("succeeded"));

        // 测试人工桥接完成条件
        assert!(can_complete_manual_bridge("manual_pending"));
        assert!(!can_complete_manual_bridge("uploading"));

        // 测试新状态不是终态
        assert!(!is_terminal_status("manual_pending"));
        assert!(!is_terminal_status("callback_timeout"));
        assert!(!is_terminal_status("compensating"));

        // 测试新状态可以取消
        assert!(can_cancel("manual_pending"));
        assert!(can_cancel("callback_timeout"));
        assert!(can_cancel("compensating"));
    }

    /// **P10 验收**: 状态转换合法性
    #[test]
    fn p10_state_transitions() {
        // manual_assisted 流程：queued → validating → manual_pending → uploading → succeeded
        let manual_flow = vec![
            "queued",
            "validating",
            "manual_pending",
            "uploading",
            "platform_processing",
            "succeeded",
        ];

        for status in &manual_flow {
            if *status != "succeeded" {
                assert!(can_cancel(status), "Should be able to cancel at {}", status);
            }
        }

        // callback_timeout 流程：platform_processing → callback_timeout → compensating → succeeded/failed
        assert!(can_compensate("callback_timeout"));
        assert!(can_retry("callback_timeout"));
    }
}
