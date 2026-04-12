//! OpenAPI aggregate for billing routes (child of `billing` — can reference `super::` handlers).

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(super::post_billing_webhook, super::list_billing_webhook_events),
    components(schemas(
        super::BillingWebhookResponse,
        super::BillingWebhookEventItem,
        super::BillingWebhookEventsResponse,
        crate::error::ErrorBody,
    )),
    tags((name = "webhooks", description = "Billing webhooks and audit"))
)]
pub struct BillingApi;
