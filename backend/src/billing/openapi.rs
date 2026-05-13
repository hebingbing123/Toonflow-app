//! OpenAPI aggregate for billing routes (child of `billing` — can reference `super::` handlers).

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        super::post_billing_webhook,
        super::events_list::list_billing_webhook_events,
        super::post_billing_reconcile,
        super::ops_view::get_workspace_subscription,
        super::ops_view::get_workspace_job_aggregates,
    ),
    components(schemas(
        super::BillingWebhookResponse,
        super::BillingReconcileResponse,
        super::BillingMismatchDetail,
        super::events_list::BillingWebhookEventItem,
        super::events_list::BillingWebhookEventsResponse,
        super::ops_view::WorkspaceSubscriptionSnapshot,
        super::ops_view::WorkspaceJobAggregates,
        super::ops_view::WorkspaceSubscriptionResponse,
        super::ops_view::WorkspaceJobAggregatesResponse,
        crate::error::ErrorBody,
    )),
    tags(
        (name = "webhooks", description = "Billing webhooks and audit"),
        (name = "billing-ops", description = "Internal ops endpoints for workspace billing queries")
    )
)]
pub struct BillingApi;
