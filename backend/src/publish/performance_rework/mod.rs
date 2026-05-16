// I.5: Connect low-performance alert to rewrite/republish loop
//
// This module provides the infrastructure to:
// 1. Detect low-performing published content
// 2. Create quality reviews with appropriate next_action
// 3. Trigger rework workflows
// 4. Enable republish after rework

mod analysis;
mod metrics;

// Re-export public types and functions
pub use analysis::process_low_performance_alerts;
pub use metrics::PerformanceThresholds;

// Re-export for potential future use
#[allow(unused_imports)]
pub(crate) use analysis::{
    create_quality_review_for_low_performance, create_rework_task_for_alert,
    recommend_rework_action, ReworkRecommendation, ReworkTaskInfo,
};
#[allow(unused_imports)]
pub(crate) use metrics::{
    fetch_low_performance_alerts_with_context, EffectiveThresholds, LowPerformanceAlert,
    PlatformThresholds,
};
