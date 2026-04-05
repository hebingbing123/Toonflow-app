//! Stable JSON error shape for HTTP API (`code`, `message`, optional `request_id`).

mod api_error;

// `ErrorBody` is part of the stable JSON contract but only referenced from docs / future callers.
#[allow(unused_imports)]
pub use api_error::{ApiError, ErrorBody};
