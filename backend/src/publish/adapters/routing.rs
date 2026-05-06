//! Delivery route determination and evidence generation

use serde_json::{json, Value};
use uuid::Uuid;

pub(crate) struct DeliveryRoute {
    pub(crate) route_key: &'static str,
    pub(crate) receipt_mode: &'static str,
    pub(crate) path: &'static str,
}

pub(crate) fn route_for_mode(automation_mode: &str) -> DeliveryRoute {
    match automation_mode {
        "full_auto" => DeliveryRoute {
            route_key: "live",
            receipt_mode: "live_api",
            path: "adapter.live.direct_api",
        },
        "manual_assisted" => DeliveryRoute {
            route_key: "manual_bridge",
            receipt_mode: "manual_bridge",
            path: "adapter.manual.bridge",
        },
        _ => DeliveryRoute {
            route_key: "sandbox",
            receipt_mode: "sandbox_closure",
            path: "adapter.sandbox.closure",
        },
    }
}

pub(crate) fn evidence_for_mode(
    automation_mode: &str,
    job_id: Uuid,
    platform_id: &str,
) -> (&'static str, Value) {
    match automation_mode {
        "full_auto" => (
            "live",
            json!({
                "request_id": format!("req_{platform_id}_{job_id}"),
                "callback_id": format!("cb_{platform_id}_{job_id}"),
            }),
        ),
        "manual_assisted" => (
            "manual_bridge",
            json!({
                "manual_step_id": format!("manual_{platform_id}_{job_id}"),
            }),
        ),
        _ => (
            "sandbox",
            json!({
                "request_id": format!("req_{platform_id}_{job_id}"),
            }),
        ),
    }
}
