//! Metrics collection and SLI tracking for critical paths.
//!
//! This module provides:
//! - Request latency tracking (p50, p95, p99)
//! - Success rate monitoring
//! - Error rate categorization
//! - SLI (Service Level Indicator) definitions for critical paths

pub mod middleware;
pub mod registry;
pub mod sli;

pub use registry::{MetricsRegistry, RequestMetrics};
pub use sli::{CriticalPath, SliDefinition, SliSnapshot, SLI_DEFINITIONS};
