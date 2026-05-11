//! 错误处理辅助函数。
//!
//! 提供常用的错误转换和日志记录模式，确保错误处理的一致性。
//!
//! 通用校验（[`validate_non_empty_string`] / [`validate_range`] / [`validate_enum`]）的文案随
//! [`super::locale::REQUEST_LOCALE`]（`Accept-Language`）切换中英文；[`validate_input`] 仍使用调用方传入的字符串。

use crate::error::locale::{current_locale, ApiLocale};
use crate::error::ApiError;
use tracing::error;

/// 将数据库错误转换为 ApiError，并记录详细的错误信息。
///
/// # 示例
///
/// ```ignore
/// let result = sqlx::query("SELECT * FROM users WHERE id = $1")
///     .bind(user_id)
///     .fetch_one(pool)
///     .await
///     .map_err(|e| db_error("Failed to fetch user", e))?;
/// ```
pub fn db_error(context: &str, err: sqlx::Error) -> ApiError {
    error!(
        target: "toonflow.db.error",
        context = %context,
        error = %err,
        error_debug = ?err,
        "Database operation failed"
    );
    ApiError::DatabaseError(format!("{}: {}", context, err))
}

/// 将任意错误转换为 Internal ApiError，并记录详细的错误信息。
///
/// 用于处理不应该暴露给客户端的内部错误。
///
/// # 示例
///
/// ```ignore
/// let data = serde_json::from_str(&json_str)
///     .map_err(|e| internal_error("Failed to parse JSON", e))?;
/// ```
pub fn internal_error<E: std::fmt::Display + std::fmt::Debug>(context: &str, err: E) -> ApiError {
    error!(
        target: "toonflow.internal.error",
        context = %context,
        error = %err,
        error_debug = ?err,
        "Internal error occurred"
    );
    ApiError::Internal
}

/// 验证输入参数，如果验证失败则返回 BadRequest 错误。
///
/// # 示例
///
/// ```ignore
/// validate_input(!name.is_empty(), "name must not be empty")?;
/// validate_input(age >= 0 && age <= 150, "age must be between 0 and 150")?;
/// ```
pub fn validate_input(condition: bool, message: &str) -> Result<(), ApiError> {
    if condition {
        Ok(())
    } else {
        Err(ApiError::BadRequest(message.to_string()))
    }
}

/// 验证字符串参数非空（去除空白后）。
///
/// # 示例
///
/// ```ignore
/// validate_non_empty_string(&body.name, "name")?;
/// validate_non_empty_string(&body.email, "email")?;
/// ```
pub fn validate_non_empty_string(value: &str, field_name: &str) -> Result<(), ApiError> {
    if value.trim().is_empty() {
        let msg = match current_locale() {
            ApiLocale::En => format!("{field_name} must not be empty"),
            ApiLocale::Zh => format!("{field_name} 不能为空"),
        };
        Err(ApiError::BadRequest(msg))
    } else {
        Ok(())
    }
}

/// 验证数值在指定范围内。
///
/// # 示例
///
/// ```ignore
/// validate_range(duration, 1, 300, "duration")?;
/// validate_range(quality, 1, 100, "quality")?;
/// ```
pub fn validate_range<T: PartialOrd + std::fmt::Display>(
    value: T,
    min: T,
    max: T,
    field_name: &str,
) -> Result<(), ApiError> {
    if value < min || value > max {
        let msg = match current_locale() {
            ApiLocale::En => format!("{field_name} must be between {min} and {max}"),
            ApiLocale::Zh => format!("{field_name} 必须在 {min} 至 {max} 之间"),
        };
        Err(ApiError::BadRequest(msg))
    } else {
        Ok(())
    }
}

/// 验证枚举值是否在允许的列表中。
///
/// # 示例
///
/// ```ignore
/// validate_enum(&format, &["mp4", "mov", "webm"], "format")?;
/// validate_enum(&status, &["pending", "active", "completed"], "status")?;
/// ```
pub fn validate_enum(value: &str, allowed: &[&str], field_name: &str) -> Result<(), ApiError> {
    if allowed.contains(&value) {
        Ok(())
    } else {
        let list = allowed.join(", ");
        let msg = match current_locale() {
            ApiLocale::En => format!("{field_name} must be one of: {list}"),
            ApiLocale::Zh => format!("{field_name} 必须是以下之一：{list}"),
        };
        Err(ApiError::BadRequest(msg))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};

    #[test]
    fn validate_input_passes_when_condition_true() {
        assert!(validate_input(true, "error message").is_ok());
    }

    #[test]
    fn validate_input_fails_when_condition_false() {
        let result = validate_input(false, "test error");
        assert!(result.is_err());
        match result.unwrap_err() {
            ApiError::BadRequest(msg) => assert_eq!(msg, "test error"),
            _ => panic!("Expected BadRequest error"),
        }
    }

    #[test]
    fn validate_non_empty_string_passes_for_non_empty() {
        assert!(validate_non_empty_string("hello", "field").is_ok());
        assert!(validate_non_empty_string("  hello  ", "field").is_ok());
    }

    #[test]
    fn validate_non_empty_string_fails_for_empty() {
        assert!(validate_non_empty_string("", "field").is_err());
        assert!(validate_non_empty_string("   ", "field").is_err());
    }

    #[test]
    fn validate_range_passes_for_valid_values() {
        assert!(validate_range(5, 1, 10, "value").is_ok());
        assert!(validate_range(1, 1, 10, "value").is_ok());
        assert!(validate_range(10, 1, 10, "value").is_ok());
    }

    #[test]
    fn validate_range_fails_for_invalid_values() {
        assert!(validate_range(0, 1, 10, "value").is_err());
        assert!(validate_range(11, 1, 10, "value").is_err());
    }

    #[test]
    fn validate_enum_passes_for_valid_values() {
        assert!(validate_enum("mp4", &["mp4", "mov", "webm"], "format").is_ok());
        assert!(validate_enum("mov", &["mp4", "mov", "webm"], "format").is_ok());
    }

    #[test]
    fn validate_enum_fails_for_invalid_values() {
        let result = validate_enum("avi", &["mp4", "mov", "webm"], "format");
        assert!(result.is_err());
        match result.unwrap_err() {
            ApiError::BadRequest(msg) => {
                assert!(msg.contains("format"));
                assert!(msg.contains("mp4, mov, webm"));
            }
            _ => panic!("Expected BadRequest error"),
        }
    }

    #[tokio::test]
    async fn validate_non_empty_string_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_non_empty_string("", "name").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "name 不能为空"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[tokio::test]
    async fn validate_range_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_range(0_i32, 1, 10, "n").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "n 必须在 1 至 10 之间"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[tokio::test]
    async fn validate_enum_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_enum("x", &["a", "b"], "kind").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "kind 必须是以下之一：a, b"),
            _ => panic!("expected BadRequest"),
        }
    }
}
