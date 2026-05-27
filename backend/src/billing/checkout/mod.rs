//! Self-serve checkout: plan catalog, sessions, Alipay / Stripe / BitPay.

mod alipay;
mod bitpay;
mod catalog;
mod complete;
pub(crate) mod handlers;
mod session;
pub(crate) mod stripe_checkout;

pub use handlers::{
    get_billing_plans, get_checkout_session, get_mock_pay, post_alipay_notify,
    post_billing_checkout, post_billing_portal, post_bitpay_notify, post_stripe_checkout_webhook,
};
pub use handlers::{
    BillingPlanPublic, BillingPlansResponse, BillingPortalResponse, CheckoutRequest,
    CheckoutResponse, CheckoutSessionResponse,
};

#[cfg(test)]
pub(crate) use complete::complete_checkout_session;
#[cfg(test)]
pub(crate) use session::{find_by_id as find_checkout_session, mark_paid as mark_checkout_paid};

#[cfg(test)]
mod tests;
