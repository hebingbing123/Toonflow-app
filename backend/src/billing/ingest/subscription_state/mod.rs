//! 订阅字段解析和合并规则，用于 Webhook 驱动的配置文件更新。

mod parse;
mod resolve;
mod types;

pub(in crate::billing::ingest) use parse::{
    parse_subscription_period_end, parse_subscription_status, parse_subscription_status_updated_at,
};
pub(in crate::billing::ingest) use resolve::resolve_subscription_state;
pub(in crate::billing::ingest) use types::{
    ExistingSubscriptionState, IncomingSubscriptionState, SubscriptionStatusSource,
};
