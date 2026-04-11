//! 错误模块：HTTP API 的稳定 JSON 错误格式。
//!
//! 提供统一的错误响应结构（code、message、可选的 request_id），
//! 确保 API 错误格式的一致性。

mod api_error;

// `ErrorBody` is part of the stable JSON contract but only referenced from docs / future callers.
#[allow(unused_imports)]
pub use api_error::{ApiError, ErrorBody};
