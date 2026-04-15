//! OpenAPI aggregate for billing routes (child of `billing` — can reference `super::` handlers).

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(super::post_billing_webhook, super::events_list::list_billing_webhook_events),
    components(schemas(
        super::BillingWebhookResponse,
        super::events_list::BillingWebhookEventItem,
        super::events_list::BillingWebhookEventsResponse,
        crate::error::ErrorBody,
    )),
    tags((name = "webhooks", description = "Billing webhooks and audit"))
)]
pub struct BillingApi;
