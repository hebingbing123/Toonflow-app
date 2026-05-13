//! 错误处理辅助函数。
//!
//! 提供常用的错误转换和日志记录模式，确保错误处理的一致性。
//!
//! 通用校验（[`validate_non_empty_string`] / [`validate_range`] / [`validate_enum`]）的文案随
//! [`super::locale::REQUEST_LOCALE`]（`Accept-Language`）切换中英文；[`validate_input`] 仍使用调用方传入的字符串。
//!
//! 新增双语辅助函数（[`bad_request_i18n`] / [`forbidden_i18n`] / [`validate_positive`] / [`validate_max_length`]）
//! 用于常见错误场景的中英文消息。

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

/// 创建带中英文消息的 BadRequest 错误。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(bad_request_i18n(
///     "field is required",
///     "字段为必填项"
/// ));
/// ```
pub fn bad_request_i18n(en_msg: &str, zh_msg: &str) -> ApiError {
    let msg = match current_locale() {
        ApiLocale::En => en_msg,
        ApiLocale::Zh => zh_msg,
    };
    ApiError::BadRequest(msg.to_string())
}

/// 创建带中英文消息的 Forbidden 错误。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(forbidden_i18n(
///     "access denied",
///     "访问被拒绝"
/// ));
/// ```
pub fn forbidden_i18n(en_msg: &str, zh_msg: &str) -> ApiError {
    let msg = match current_locale() {
        ApiLocale::En => en_msg,
        ApiLocale::Zh => zh_msg,
    };
    ApiError::Forbidden(msg.to_string())
}

/// 验证数值为正数（> 0）。
///
/// # 示例
///
/// ```ignore
/// validate_positive(body.id, "id")?;
/// validate_positive(body.project_id, "projectId")?;
/// ```
pub fn validate_positive<T: PartialOrd + Default + std::fmt::Display>(
    value: T,
    field_name: &str,
) -> Result<(), ApiError> {
    if value <= T::default() {
        let msg = match current_locale() {
            ApiLocale::En => format!("{field_name} must be positive"),
            ApiLocale::Zh => format!("{field_name} 必须为正数"),
        };
        Err(ApiError::BadRequest(msg))
    } else {
        Ok(())
    }
}

/// 验证字符串长度不超过最大值。
///
/// # 示例
///
/// ```ignore
/// validate_max_length(&body.name, 100, "name")?;
/// validate_max_length(&body.description, 500, "description")?;
/// ```
pub fn validate_max_length(value: &str, max_len: usize, field_name: &str) -> Result<(), ApiError> {
    if value.len() > max_len {
        let msg = match current_locale() {
            ApiLocale::En => format!("{field_name} must be at most {max_len} characters"),
            ApiLocale::Zh => format!("{field_name} 长度不能超过 {max_len} 个字符"),
        };
        Err(ApiError::BadRequest(msg))
    } else {
        Ok(())
    }
}

/// 创建带中英文消息的 Conflict 错误。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(conflict_i18n(
///     "resource already exists",
///     "资源已存在"
/// ));
/// ```
#[allow(dead_code)] // Public helper for handlers; not all call sites wired yet.
pub fn conflict_i18n(en_msg: &str, zh_msg: &str) -> ApiError {
    ApiError::ConflictI18n {
        en: en_msg.to_string(),
        zh: zh_msg.to_string(),
    }
}

/// 创建格式验证错误（带字段名和期望格式参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(invalid_format_i18n("email", "valid email address"));
/// return Err(invalid_format_i18n("uuid", "UUID format"));
/// ```
pub fn invalid_format_i18n(field_name: &str, expected: &str) -> ApiError {
    ApiError::BadRequestI18n {
        en: format!(
            "Invalid format for field '{}': expected {}",
            field_name, expected
        ),
        zh: format!("字段 '{}' 格式无效：期望 {}", field_name, expected),
    }
}

/// 创建无效值错误（带字段名和原因参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(invalid_value_i18n("age", "must be between 0 and 150"));
/// return Err(invalid_value_i18n("status", "must be one of: active, inactive"));
/// ```
pub fn invalid_value_i18n(field_name: &str, reason: &str) -> ApiError {
    ApiError::BadRequestI18n {
        en: format!("Invalid value for field '{}': {}", field_name, reason),
        zh: format!("字段 '{}' 的值无效：{}", field_name, reason),
    }
}

/// 创建缺少必填字段错误（带字段名参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(missing_field_i18n("email"));
/// return Err(missing_field_i18n("name"));
/// ```
pub fn missing_field_i18n(field_name: &str) -> ApiError {
    ApiError::BadRequestI18n {
        en: format!("Missing required field '{}'", field_name),
        zh: format!("缺少必填字段 '{}'", field_name),
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

    #[test]
    fn validate_positive_passes_for_positive() {
        assert!(validate_positive(1, "id").is_ok());
        assert!(validate_positive(100, "count").is_ok());
    }

    #[test]
    fn validate_positive_fails_for_non_positive() {
        assert!(validate_positive(0, "id").is_err());
        assert!(validate_positive(-1, "id").is_err());
    }

    #[tokio::test]
    async fn validate_positive_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_positive(0, "id").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "id 必须为正数"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[test]
    fn validate_max_length_passes_for_valid() {
        assert!(validate_max_length("hello", 10, "name").is_ok());
        assert!(validate_max_length("", 10, "name").is_ok());
    }

    #[test]
    fn validate_max_length_fails_for_too_long() {
        assert!(validate_max_length("hello world", 5, "name").is_err());
    }

    #[tokio::test]
    async fn validate_max_length_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_max_length("hello world", 5, "name").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "name 长度不能超过 5 个字符"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[tokio::test]
    async fn bad_request_i18n_en() {
        let err = bad_request_i18n("field is required", "字段为必填项");
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "field is required"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[tokio::test]
    async fn bad_request_i18n_zh() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                bad_request_i18n("field is required", "字段为必填项")
            })
            .await;
        match err {
            ApiError::BadRequest(m) => assert_eq!(m, "字段为必填项"),
            _ => panic!("expected BadRequest"),
        }
    }

    #[tokio::test]
    async fn forbidden_i18n_en() {
        let err = forbidden_i18n("access denied", "访问被拒绝");
        match err {
            ApiError::Forbidden(m) => assert_eq!(m, "access denied"),
            _ => panic!("expected Forbidden"),
        }
    }

    #[tokio::test]
    async fn forbidden_i18n_zh() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                forbidden_i18n("access denied", "访问被拒绝")
            })
            .await;
        match err {
            ApiError::Forbidden(m) => assert_eq!(m, "访问被拒绝"),
            _ => panic!("expected Forbidden"),
        }
    }

    #[test]
    fn invalid_format_i18n_en() {
        let err = invalid_format_i18n("email", "valid email address");
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(
                    en,
                    "Invalid format for field 'email': expected valid email address"
                );
                assert_eq!(zh, "字段 'email' 格式无效：期望 valid email address");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn invalid_format_i18n_with_different_field() {
        let err = invalid_format_i18n("uuid", "UUID format");
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(en, "Invalid format for field 'uuid': expected UUID format");
                assert_eq!(zh, "字段 'uuid' 格式无效：期望 UUID format");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn missing_field_i18n_en() {
        let err = missing_field_i18n("email");
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(en, "Missing required field 'email'");
                assert_eq!(zh, "缺少必填字段 'email'");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn missing_field_i18n_zh() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async { missing_field_i18n("name") })
            .await;
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(en, "Missing required field 'name'");
                assert_eq!(zh, "缺少必填字段 'name'");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn missing_field_i18n_various_field_names() {
        let test_cases = vec![
            (
                "email",
                "Missing required field 'email'",
                "缺少必填字段 'email'",
            ),
            (
                "name",
                "Missing required field 'name'",
                "缺少必填字段 'name'",
            ),
            (
                "userId",
                "Missing required field 'userId'",
                "缺少必填字段 'userId'",
            ),
            (
                "projectId",
                "Missing required field 'projectId'",
                "缺少必填字段 'projectId'",
            ),
        ];

        for (field_name, expected_en, expected_zh) in test_cases {
            let err = missing_field_i18n(field_name);
            match err {
                ApiError::BadRequestI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected BadRequestI18n"),
            }
        }
    }

    #[test]
    fn invalid_value_i18n_en() {
        let err = invalid_value_i18n("age", "must be between 0 and 150");
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(
                    en,
                    "Invalid value for field 'age': must be between 0 and 150"
                );
                assert_eq!(zh, "字段 'age' 的值无效：must be between 0 and 150");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn invalid_value_i18n_with_different_reason() {
        let err = invalid_value_i18n("status", "must be one of: active, inactive");
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(
                    en,
                    "Invalid value for field 'status': must be one of: active, inactive"
                );
                assert_eq!(
                    zh,
                    "字段 'status' 的值无效：must be one of: active, inactive"
                );
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn invalid_format_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = invalid_format_i18n("email", "valid email address");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Invalid format for field 'email': expected valid email address")
        );
    }

    #[tokio::test]
    async fn invalid_format_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = invalid_format_i18n("email", "valid email address");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("字段 'email' 格式无效：期望 valid email address")
        );
    }
}
