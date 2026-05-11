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
//! 通用校验辅助（`helpers` 模块）中部分 `BadRequest` 文案随 `Accept-Language` 切换；其它仍为调用方字符串。
//!
//! ## Request ID 追踪
//!
//! Request ID 通过以下方式传播：
//! 1. 客户端可通过 `X-Request-ID` 请求头提供自定义 ID
//! 2. 服务器自动生成 UUID 作为 request ID（如果客户端未提供）
//! 3. Request ID 在响应头和错误体中返回
//! 4. 所有日志记录包含 request ID 以便关联
//!
//! ## 错误日志记录
//!
//! 所有错误在转换为 HTTP 响应时自动记录日志：
//! - 5xx 错误（Internal、DatabaseError）记录为 `error` 级别
//! - 配置错误（AuthNotConfigured、LlmNotConfigured）记录为 `warn` 级别
//! - 4xx 错误（BadRequest、NotFound、Unauthorized）记录为 `info` 或 `debug` 级别
//!
//! ## 错误处理辅助函数
//!
//! 使用 `helpers` 模块中的辅助函数可以简化错误处理：
//!
//! ```ignore
//! use crate::error::helpers::{db_error, validate_non_empty_string, validate_range};
//!
//! // 数据库错误处理
//! let user = sqlx::query_as("SELECT * FROM users WHERE id = $1")
//!     .bind(user_id)
//!     .fetch_one(pool)
//!     .await
//!     .map_err(|e| db_error("Failed to fetch user", e))?;
//!
//! // 输入验证
//! validate_non_empty_string(&body.name, "name")?;
//! validate_range(body.duration, 1, 300, "duration")?;
//! ```

mod api_error;
mod helpers;
pub mod locale;

// `ErrorBody` is part of the stable JSON contract but only referenced from docs / future callers.
#[allow(unused_imports)]
pub use api_error::{ApiError, ErrorBody};
pub use helpers::{
    db_error, internal_error, validate_enum, validate_input, validate_non_empty_string,
    validate_range,
};
pub use locale::ApiLocale;
