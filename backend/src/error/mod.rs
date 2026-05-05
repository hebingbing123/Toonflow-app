//! 错误模块：HTTP API 的稳定 JSON 错误格式。
//!
//! 提供统一的错误响应结构（status、code、message、request_id、details），
//! 确保 API 错误格式的一致性。
//!
//! ## 标准错误格式
//!
//! 所有 API 错误响应遵循以下格式：
//!
//! ```json
//! {
//!   "status": 409,
//!   "code": "version_conflict",
//!   "message": "Timeline has been modified by another user",
//!   "request_id": "req_abc123xyz",
//!   "details": {
//!     "expected_version": "2025-01-15 10:30:45",
//!     "current_version": "2025-01-15 10:35:12",
//!     "conflict_type": "version_mismatch"
//!   }
//! }
//! ```
//!
//! ### 字段说明
//!
//! - `status` (u16): HTTP 状态码 (e.g., 400, 404, 409, 500)
//! - `code` (string): 机器可读的错误代码 (e.g., "validation_error", "not_found", "conflict")
//! - `message` (string): 人类可读的错误消息
//! - `request_id` (string, optional): 请求 ID，用于追踪和调试（由中间件注入）
//! - `details` (object, optional): 额外的上下文信息（如字段级验证错误、版本冲突详情）
//! - `retry_after_ms` (u64, optional): 速率限制重试等待时间（仅 429 响应）
//!
//! ## Request ID 追踪
//!
//! Request ID 通过以下方式传播：
//! 1. 客户端可通过 `X-Request-ID` 请求头提供自定义 ID
//! 2. 服务器自动生成 UUID 作为 request ID（如果客户端未提供）
//! 3. Request ID 在响应头和错误体中返回
//! 4. 所有日志记录包含 request ID 以便关联

mod api_error;

// `ErrorBody` is part of the stable JSON contract but only referenced from docs / future callers.
#[allow(unused_imports)]
pub use api_error::{ApiError, ErrorBody};
