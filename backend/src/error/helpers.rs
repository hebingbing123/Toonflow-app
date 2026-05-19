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
        target: "openflow.db.error",
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
        target: "openflow.internal.error",
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

/// 创建权限不足错误（带操作名称参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(insufficient_permissions_i18n("delete workspace"));
/// return Err(insufficient_permissions_i18n("modify project settings"));
/// ```
pub fn insufficient_permissions_i18n(action: &str) -> ApiError {
    ApiError::ForbiddenI18n {
        en: format!("Insufficient permissions to {}", action),
        zh: format!("权限不足，无法{}", action),
    }
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
pub fn conflict_i18n(en_msg: &str, zh_msg: &str) -> ApiError {
    ApiError::ConflictI18n {
        en: en_msg.to_string(),
        zh: zh_msg.to_string(),
    }
}

/// Bilingual conflict with structured **`details`** (e.g. per-storyboard readiness gates).
pub fn conflict_with_details_i18n(
    en_msg: &str,
    zh_msg: &str,
    details: serde_json::Value,
) -> ApiError {
    ApiError::ConflictWithDetailsI18n {
        en: en_msg.to_string(),
        zh: zh_msg.to_string(),
        details,
    }
}

/// 创建重复资源错误（带资源类型和标识符参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(duplicate_resource_i18n("workspace", "my-workspace"));
/// return Err(duplicate_resource_i18n("project", "project-123"));
/// ```
pub fn duplicate_resource_i18n(resource_type: &str, identifier: &str) -> ApiError {
    ApiError::ConflictI18n {
        en: format!("{} '{}' already exists", resource_type, identifier),
        zh: format!("{} '{}' 已存在", resource_type, identifier),
    }
}

/// 创建版本冲突错误（带资源名称参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(version_conflict_i18n("Timeline"));
/// return Err(version_conflict_i18n("Project"));
/// ```
pub fn version_conflict_i18n(resource: &str) -> ApiError {
    ApiError::ConflictI18n {
        en: format!("{} has been modified by another user", resource),
        zh: format!("{} 已被其他用户修改", resource),
    }
}

/// 创建并发修改错误（带资源名称参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(concurrent_modification_i18n("Timeline"));
/// return Err(concurrent_modification_i18n("Project"));
/// ```
pub fn concurrent_modification_i18n(resource: &str) -> ApiError {
    ApiError::ConflictI18n {
        en: format!("{} is being modified by another operation", resource),
        zh: format!("{} 正在被其他操作修改", resource),
    }
}

/// 创建功能未启用错误（带功能名称参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(feature_not_enabled_i18n("billing"));
/// return Err(feature_not_enabled_i18n("advanced_analytics"));
/// ```
pub fn feature_not_enabled_i18n(feature: &str) -> ApiError {
    ApiError::ForbiddenI18n {
        en: format!("Feature '{}' is not enabled", feature),
        zh: format!("功能 '{}' 未启用", feature),
    }
}

/// 创建工作区访问被拒绝错误（无参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(workspace_access_denied_i18n());
/// ```
pub fn workspace_access_denied_i18n() -> ApiError {
    ApiError::ForbiddenI18n {
        en: "Access to workspace denied".to_string(),
        zh: "工作区访问被拒绝".to_string(),
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

/// 创建带中英文消息的 NotImplemented 错误。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(not_implemented_i18n(
///     "feature not available",
///     "功能不可用"
/// ));
/// ```
pub fn not_implemented_i18n(en_msg: &str, zh_msg: &str) -> ApiError {
    ApiError::NotImplementedI18n {
        en: en_msg.to_string(),
        zh: zh_msg.to_string(),
    }
}

/// 创建已弃用端点错误（带替代端点参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(deprecated_endpoint_i18n("/api/v2/users"));
/// return Err(deprecated_endpoint_i18n("/api/v2/projects"));
/// ```
pub fn deprecated_endpoint_i18n(alternative: &str) -> ApiError {
    ApiError::NotImplementedI18n {
        en: format!(
            "This endpoint is deprecated. Please use {} instead",
            alternative
        ),
        zh: format!("此端点已弃用。请改用 {}", alternative),
    }
}

/// 创建开发中功能错误（带功能名称参数）。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// return Err(feature_under_development_i18n("advanced_analytics"));
/// return Err(feature_under_development_i18n("video_export"));
/// ```
#[allow(dead_code)] // Public helper for handlers; not all call sites wired yet.
pub fn feature_under_development_i18n(feature: &str) -> ApiError {
    ApiError::NotImplementedI18n {
        en: format!("Feature '{}' is currently under development", feature),
        zh: format!("功能 '{}' 正在开发中", feature),
    }
}

/// 验证 UUID 格式。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// validate_uuid(&body.user_id, "userId")?;
/// validate_uuid(&body.workspace_id, "workspaceId")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual UUID validation; exercised in unit tests.
pub fn validate_uuid(value: &str, field_name: &str) -> Result<(), ApiError> {
    match uuid::Uuid::parse_str(value) {
        Ok(_) => Ok(()),
        Err(_) => Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid format for field '{}': expected valid UUID",
                field_name
            ),
            zh: format!("字段 '{}' 格式无效：期望有效的 UUID", field_name),
        }),
    }
}

/// 验证 URL 格式。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
/// 仅接受 HTTP 和 HTTPS 协议的 URL。
///
/// # 示例
///
/// ```ignore
/// validate_url(&body.webhook_url, "webhookUrl")?;
/// validate_url(&body.callback_url, "callbackUrl")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual URL validation; exercised in unit tests.
pub fn validate_url(value: &str, field_name: &str) -> Result<(), ApiError> {
    match url::Url::parse(value) {
        Ok(parsed_url) => {
            // Only accept HTTP and HTTPS URLs
            let scheme = parsed_url.scheme();
            if scheme == "http" || scheme == "https" {
                Ok(())
            } else {
                Err(ApiError::BadRequestI18n {
                    en: format!(
                        "Invalid format for field '{}': expected valid HTTP/HTTPS URL",
                        field_name
                    ),
                    zh: format!("字段 '{}' 格式无效：期望有效的 HTTP/HTTPS URL", field_name),
                })
            }
        }
        Err(_) => Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid format for field '{}': expected valid HTTP/HTTPS URL",
                field_name
            ),
            zh: format!("字段 '{}' 格式无效：期望有效的 HTTP/HTTPS URL", field_name),
        }),
    }
}

/// 验证 Email 格式。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
/// 使用基本的 email 格式验证（local@domain）。
///
/// # 示例
///
/// ```ignore
/// validate_email(&body.email, "email")?;
/// validate_email(&body.contact_email, "contactEmail")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual email validation; exercised in unit tests.
pub fn validate_email(value: &str, field_name: &str) -> Result<(), ApiError> {
    // Basic email validation regex: local@domain
    // This is a simplified pattern that covers most common cases
    // Pattern: one or more characters before @, then one or more characters, then a dot, then 2+ characters
    let email_regex = regex::Regex::new(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").unwrap();

    if email_regex.is_match(value) {
        Ok(())
    } else {
        Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid format for field '{}': expected valid email address",
                field_name
            ),
            zh: format!("字段 '{}' 格式无效：期望有效的电子邮件地址", field_name),
        })
    }
}

/// 验证 JSON 格式。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
/// 使用 serde_json 验证 JSON 格式是否有效。
///
/// # 示例
///
/// ```ignore
/// validate_json(&body.metadata, "metadata")?;
/// validate_json(&body.config, "config")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual JSON validation; exercised in unit tests.
pub fn validate_json(value: &str, field_name: &str) -> Result<(), ApiError> {
    match serde_json::from_str::<serde_json::Value>(value) {
        Ok(_) => Ok(()),
        Err(_) => Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid format for field '{}': expected valid JSON",
                field_name
            ),
            zh: format!("字段 '{}' 格式无效：期望有效的 JSON", field_name),
        }),
    }
}

/// 验证字符串最小长度。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// validate_min_length(&body.password, 8, "password")?;
/// validate_min_length(&body.name, 3, "name")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual min length validation; exercised in unit tests.
pub fn validate_min_length(value: &str, min_len: usize, field_name: &str) -> Result<(), ApiError> {
    if value.len() >= min_len {
        Ok(())
    } else {
        Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid value for field '{}': must be at least {} characters",
                field_name, min_len
            ),
            zh: format!(
                "字段 '{}' 的值无效：长度必须至少为 {} 个字符",
                field_name, min_len
            ),
        })
    }
}

/// 验证数组非空。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
///
/// # 示例
///
/// ```ignore
/// validate_array_not_empty(&body.items, "items")?;
/// validate_array_not_empty(&body.tags, "tags")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual array validation; exercised in unit tests.
pub fn validate_array_not_empty<T>(arr: &[T], field_name: &str) -> Result<(), ApiError> {
    if !arr.is_empty() {
        Ok(())
    } else {
        Err(ApiError::BadRequestI18n {
            en: format!(
                "Invalid value for field '{}': array must not be empty",
                field_name
            ),
            zh: format!("字段 '{}' 的值无效：数组不能为空", field_name),
        })
    }
}

/// 验证数组元素唯一性。
///
/// 根据当前请求的 `Accept-Language` 偏好返回对应语言的错误消息。
/// 使用 HashSet 检测重复元素。
///
/// # 示例
///
/// ```ignore
/// validate_unique_items(&body.tags, "tags")?;
/// validate_unique_items(&body.ids, "ids")?;
/// ```
#[allow(dead_code)] // Staged helper for bilingual uniqueness validation; exercised in unit tests.
pub fn validate_unique_items<T: Eq + std::hash::Hash>(
    arr: &[T],
    field_name: &str,
) -> Result<(), ApiError> {
    let mut seen = std::collections::HashSet::new();
    for item in arr {
        if !seen.insert(item) {
            return Err(ApiError::BadRequestI18n {
                en: format!(
                    "Invalid value for field '{}': array contains duplicate items",
                    field_name
                ),
                zh: format!("字段 '{}' 的值无效：数组包含重复项", field_name),
            });
        }
    }
    Ok(())
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
    fn validate_uuid_accepts_valid() {
        assert!(validate_uuid("550e8400-e29b-41d4-a716-446655440000", "id",).is_ok());
    }

    #[test]
    fn validate_uuid_rejects_invalid() {
        let err = validate_uuid("not-a-uuid", "userId").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => assert!(en.contains("userId")),
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn validate_url_accepts_valid_http() {
        assert!(validate_url("http://example.com", "url").is_ok());
        assert!(validate_url("http://example.com/path", "url").is_ok());
        assert!(validate_url("http://example.com:8080/path?query=value", "url").is_ok());
    }

    #[test]
    fn validate_url_accepts_valid_https() {
        assert!(validate_url("https://example.com", "url").is_ok());
        assert!(validate_url("https://example.com/path", "url").is_ok());
        assert!(validate_url("https://api.example.com/v1/endpoint", "url").is_ok());
    }

    #[test]
    fn validate_url_rejects_invalid() {
        let err = validate_url("not-a-url", "webhookUrl").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("webhookUrl"));
                assert!(en.contains("HTTP/HTTPS"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn validate_url_rejects_non_http_schemes() {
        // FTP should be rejected
        let err = validate_url("ftp://example.com", "url").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("HTTP/HTTPS"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // File scheme should be rejected
        let err = validate_url("file:///path/to/file", "url").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("HTTP/HTTPS"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_url_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_url("not-a-url", "webhookUrl").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("webhookUrl"));
                assert!(zh.contains("HTTP/HTTPS"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_url_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = validate_url("invalid-url", "callbackUrl").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("callbackUrl"));
        assert!(message.contains("HTTP/HTTPS"));
    }

    #[tokio::test]
    async fn validate_url_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = validate_url("invalid-url", "callbackUrl").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("callbackUrl"));
        assert!(message.contains("HTTP/HTTPS"));
    }

    #[test]
    fn validate_email_accepts_valid() {
        assert!(validate_email("user@example.com", "email").is_ok());
        assert!(validate_email("test.user@example.com", "email").is_ok());
        assert!(validate_email("user+tag@example.co.uk", "email").is_ok());
        assert!(validate_email("user_name@sub.example.com", "email").is_ok());
    }

    #[test]
    fn validate_email_rejects_invalid() {
        // No @ symbol
        let err = validate_email("notanemail", "email").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
                assert!(en.contains("valid email address"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // No domain
        let err = validate_email("user@", "email").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // No local part
        let err = validate_email("@example.com", "email").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // No TLD
        let err = validate_email("user@example", "email").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // Contains whitespace
        let err = validate_email("user @example.com", "email").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_email_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_email("invalid-email", "email").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("email"));
                assert!(zh.contains("电子邮件地址"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_email_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = validate_email("invalid-email", "contactEmail").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("contactEmail"));
        assert!(message.contains("valid email address"));
    }

    #[tokio::test]
    async fn validate_email_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = validate_email("invalid-email", "contactEmail").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("contactEmail"));
        assert!(message.contains("电子邮件地址"));
    }

    #[test]
    fn validate_json_accepts_valid() {
        assert!(validate_json(r#"{"key": "value"}"#, "metadata").is_ok());
        assert!(validate_json(r#"[]"#, "items").is_ok());
        assert!(validate_json(r#"null"#, "data").is_ok());
        assert!(validate_json(r#"123"#, "number").is_ok());
        assert!(validate_json(r#""string""#, "text").is_ok());
        assert!(validate_json(r#"true"#, "flag").is_ok());
        assert!(validate_json(r#"{"nested": {"object": {"with": "values"}}}"#, "config").is_ok());
    }

    #[test]
    fn validate_json_rejects_invalid() {
        // Invalid JSON syntax
        let err = validate_json(r#"{"key": "value""#, "metadata").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("metadata"));
                assert!(en.contains("valid JSON"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // Not JSON at all
        let err = validate_json("not json", "config").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("config"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // Empty string
        let err = validate_json("", "data").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("data"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // Unclosed array
        let err = validate_json("[1, 2, 3", "items").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("items"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_json_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_json("invalid json", "metadata").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("metadata"));
                assert!(zh.contains("JSON"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_json_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = validate_json("invalid json", "config").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("config"));
        assert!(message.contains("valid JSON"));
    }

    #[tokio::test]
    async fn validate_json_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = validate_json("invalid json", "config").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("config"));
        assert!(message.contains("JSON"));
    }

    #[test]
    fn validate_min_length_accepts_valid() {
        assert!(validate_min_length("password123", 8, "password").is_ok());
        assert!(validate_min_length("exactly8", 8, "password").is_ok());
        assert!(validate_min_length("hello", 3, "name").is_ok());
        assert!(validate_min_length("a", 1, "code").is_ok());
    }

    #[test]
    fn validate_min_length_rejects_too_short() {
        // Too short
        let err = validate_min_length("short", 8, "password").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("password"));
                assert!(en.contains("at least 8 characters"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // Empty string
        let err = validate_min_length("", 1, "name").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("name"));
                assert!(en.contains("at least 1 characters"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        // One character short
        let err = validate_min_length("1234567", 8, "code").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("code"));
                assert!(en.contains("at least 8 characters"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_min_length_zh_locale() {
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_min_length("short", 8, "password").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("password"));
                assert!(zh.contains("至少为 8 个字符"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_min_length_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = validate_min_length("abc", 5, "username").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("username"));
        assert!(message.contains("at least 5 characters"));
    }

    #[tokio::test]
    async fn validate_min_length_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = validate_min_length("abc", 5, "username").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("username"));
        assert!(message.contains("至少为 5 个字符"));
    }

    #[test]
    fn validate_array_not_empty_accepts_non_empty() {
        let items = vec![1, 2, 3];
        assert!(validate_array_not_empty(&items, "items").is_ok());

        let single_item = vec!["hello"];
        assert!(validate_array_not_empty(&single_item, "tags").is_ok());

        let strings = vec!["a".to_string(), "b".to_string()];
        assert!(validate_array_not_empty(&strings, "names").is_ok());
    }

    #[test]
    fn validate_array_not_empty_rejects_empty() {
        let empty_vec: Vec<i32> = vec![];
        let err = validate_array_not_empty(&empty_vec, "items").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("items"));
                assert!(en.contains("array must not be empty"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        let empty_strings: Vec<String> = vec![];
        let err = validate_array_not_empty(&empty_strings, "tags").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("tags"));
                assert!(en.contains("array must not be empty"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_array_not_empty_zh_locale() {
        let empty_vec: Vec<i32> = vec![];
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_array_not_empty(&empty_vec, "items").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("items"));
                assert!(zh.contains("数组不能为空"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_array_not_empty_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let empty_vec: Vec<String> = vec![];
        let err = validate_array_not_empty(&empty_vec, "tags").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("tags"));
        assert!(message.contains("array must not be empty"));
    }

    #[tokio::test]
    async fn validate_array_not_empty_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let empty_vec: Vec<i32> = vec![];
                let err = validate_array_not_empty(&empty_vec, "items").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("items"));
        assert!(message.contains("数组不能为空"));
    }

    #[test]
    fn validate_unique_items_accepts_unique() {
        let items = vec![1, 2, 3, 4, 5];
        assert!(validate_unique_items(&items, "items").is_ok());

        let strings = vec!["a", "b", "c"];
        assert!(validate_unique_items(&strings, "tags").is_ok());

        let single_item = vec![42];
        assert!(validate_unique_items(&single_item, "ids").is_ok());

        let empty_vec: Vec<i32> = vec![];
        assert!(validate_unique_items(&empty_vec, "items").is_ok());
    }

    #[test]
    fn validate_unique_items_rejects_duplicates() {
        let items = vec![1, 2, 3, 2, 4];
        let err = validate_unique_items(&items, "items").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("items"));
                assert!(en.contains("array contains duplicate items"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        let strings = vec!["a", "b", "a"];
        let err = validate_unique_items(&strings, "tags").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("tags"));
                assert!(en.contains("array contains duplicate items"));
            }
            _ => panic!("expected BadRequestI18n"),
        }

        let all_same = vec![1, 1, 1];
        let err = validate_unique_items(&all_same, "ids").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("ids"));
                assert!(en.contains("array contains duplicate items"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_unique_items_zh_locale() {
        let items = vec![1, 2, 3, 2];
        let err = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                validate_unique_items(&items, "items").unwrap_err()
            })
            .await;
        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("items"));
                assert!(zh.contains("数组包含重复项"));
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_unique_items_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let items = vec!["a", "b", "c", "b"];
        let err = validate_unique_items(&items, "tags").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("tags"));
        assert!(message.contains("array contains duplicate items"));
    }

    #[tokio::test]
    async fn validate_unique_items_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let items = vec![1, 2, 3, 1];
                let err = validate_unique_items(&items, "ids").unwrap_err();
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
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("ids"));
        assert!(message.contains("数组包含重复项"));
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

    #[tokio::test]
    async fn missing_field_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = missing_field_i18n("email");
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
            Some("Missing required field 'email'")
        );
    }

    #[tokio::test]
    async fn missing_field_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = missing_field_i18n("name");
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
            Some("缺少必填字段 'name'")
        );
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
    async fn invalid_value_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = invalid_value_i18n("age", "must be between 0 and 150");
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
            Some("Invalid value for field 'age': must be between 0 and 150")
        );
    }

    #[tokio::test]
    async fn invalid_value_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = invalid_value_i18n("status", "must be one of: active, inactive");
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
            Some("字段 'status' 的值无效：must be one of: active, inactive")
        );
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

    #[test]
    fn version_conflict_i18n_en() {
        let err = version_conflict_i18n("Timeline");
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "Timeline has been modified by another user");
                assert_eq!(zh, "Timeline 已被其他用户修改");
            }
            _ => panic!("expected ConflictI18n"),
        }
    }

    #[test]
    fn version_conflict_i18n_with_different_resource() {
        let err = version_conflict_i18n("Project");
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "Project has been modified by another user");
                assert_eq!(zh, "Project 已被其他用户修改");
            }
            _ => panic!("expected ConflictI18n"),
        }
    }

    #[tokio::test]
    async fn version_conflict_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = version_conflict_i18n("Timeline");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Timeline has been modified by another user")
        );
    }

    #[tokio::test]
    async fn version_conflict_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = version_conflict_i18n("Timeline");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Timeline 已被其他用户修改")
        );
    }

    #[test]
    fn duplicate_resource_i18n_en() {
        let err = duplicate_resource_i18n("workspace", "my-workspace");
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "workspace 'my-workspace' already exists");
                assert_eq!(zh, "workspace 'my-workspace' 已存在");
            }
            _ => panic!("expected ConflictI18n"),
        }
    }

    #[test]
    fn duplicate_resource_i18n_with_different_resource_types() {
        let test_cases = vec![
            (
                "workspace",
                "my-workspace",
                "workspace 'my-workspace' already exists",
                "workspace 'my-workspace' 已存在",
            ),
            (
                "project",
                "project-123",
                "project 'project-123' already exists",
                "project 'project-123' 已存在",
            ),
            (
                "user",
                "john@example.com",
                "user 'john@example.com' already exists",
                "user 'john@example.com' 已存在",
            ),
        ];

        for (resource_type, identifier, expected_en, expected_zh) in test_cases {
            let err = duplicate_resource_i18n(resource_type, identifier);
            match err {
                ApiError::ConflictI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected ConflictI18n"),
            }
        }
    }

    #[tokio::test]
    async fn duplicate_resource_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = duplicate_resource_i18n("workspace", "my-workspace");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("workspace 'my-workspace' already exists")
        );
    }

    #[tokio::test]
    async fn duplicate_resource_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = duplicate_resource_i18n("project", "project-123");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("project 'project-123' 已存在")
        );
    }

    #[test]
    fn concurrent_modification_i18n_en() {
        let err = concurrent_modification_i18n("Timeline");
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "Timeline is being modified by another operation");
                assert_eq!(zh, "Timeline 正在被其他操作修改");
            }
            _ => panic!("expected ConflictI18n"),
        }
    }

    #[test]
    fn concurrent_modification_i18n_with_different_resource() {
        let err = concurrent_modification_i18n("Project");
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, "Project is being modified by another operation");
                assert_eq!(zh, "Project 正在被其他操作修改");
            }
            _ => panic!("expected ConflictI18n"),
        }
    }

    #[tokio::test]
    async fn concurrent_modification_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = concurrent_modification_i18n("Timeline");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Timeline is being modified by another operation")
        );
    }

    #[tokio::test]
    async fn concurrent_modification_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = concurrent_modification_i18n("Project");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Project 正在被其他操作修改")
        );
    }

    #[test]
    fn feature_not_enabled_i18n_en() {
        let err = feature_not_enabled_i18n("billing");
        match err {
            ApiError::ForbiddenI18n { en, zh } => {
                assert_eq!(en, "Feature 'billing' is not enabled");
                assert_eq!(zh, "功能 'billing' 未启用");
            }
            _ => panic!("expected ForbiddenI18n"),
        }
    }

    #[test]
    fn feature_not_enabled_i18n_with_different_features() {
        let test_cases = vec![
            (
                "billing",
                "Feature 'billing' is not enabled",
                "功能 'billing' 未启用",
            ),
            (
                "advanced_analytics",
                "Feature 'advanced_analytics' is not enabled",
                "功能 'advanced_analytics' 未启用",
            ),
            (
                "export",
                "Feature 'export' is not enabled",
                "功能 'export' 未启用",
            ),
        ];

        for (feature, expected_en, expected_zh) in test_cases {
            let err = feature_not_enabled_i18n(feature);
            match err {
                ApiError::ForbiddenI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected ForbiddenI18n"),
            }
        }
    }

    #[tokio::test]
    async fn feature_not_enabled_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = feature_not_enabled_i18n("billing");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Feature 'billing' is not enabled")
        );
    }

    #[tokio::test]
    async fn feature_not_enabled_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = feature_not_enabled_i18n("advanced_analytics");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("功能 'advanced_analytics' 未启用")
        );
    }

    #[test]
    fn insufficient_permissions_i18n_en() {
        let err = insufficient_permissions_i18n("delete workspace");
        match err {
            ApiError::ForbiddenI18n { en, zh } => {
                assert_eq!(en, "Insufficient permissions to delete workspace");
                assert_eq!(zh, "权限不足，无法delete workspace");
            }
            _ => panic!("expected ForbiddenI18n"),
        }
    }

    #[test]
    fn insufficient_permissions_i18n_with_different_actions() {
        let test_cases = vec![
            (
                "delete workspace",
                "Insufficient permissions to delete workspace",
                "权限不足，无法delete workspace",
            ),
            (
                "modify project settings",
                "Insufficient permissions to modify project settings",
                "权限不足，无法modify project settings",
            ),
            (
                "access billing information",
                "Insufficient permissions to access billing information",
                "权限不足，无法access billing information",
            ),
            (
                "create new project",
                "Insufficient permissions to create new project",
                "权限不足，无法create new project",
            ),
        ];

        for (action, expected_en, expected_zh) in test_cases {
            let err = insufficient_permissions_i18n(action);
            match err {
                ApiError::ForbiddenI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected ForbiddenI18n"),
            }
        }
    }

    #[tokio::test]
    async fn insufficient_permissions_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = insufficient_permissions_i18n("delete workspace");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Insufficient permissions to delete workspace")
        );
    }

    #[tokio::test]
    async fn insufficient_permissions_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = insufficient_permissions_i18n("modify project settings");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("权限不足，无法modify project settings")
        );
    }

    #[test]
    fn workspace_access_denied_i18n_en() {
        let err = workspace_access_denied_i18n();
        match err {
            ApiError::ForbiddenI18n { en, zh } => {
                assert_eq!(en, "Access to workspace denied");
                assert_eq!(zh, "工作区访问被拒绝");
            }
            _ => panic!("expected ForbiddenI18n"),
        }
    }

    #[tokio::test]
    async fn workspace_access_denied_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = workspace_access_denied_i18n();
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Access to workspace denied")
        );
    }

    #[tokio::test]
    async fn workspace_access_denied_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = workspace_access_denied_i18n();
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("工作区访问被拒绝")
        );
    }

    #[test]
    fn not_implemented_i18n_en() {
        let err = not_implemented_i18n("feature not available", "功能不可用");
        match err {
            ApiError::NotImplementedI18n { en, zh } => {
                assert_eq!(en, "feature not available");
                assert_eq!(zh, "功能不可用");
            }
            _ => panic!("expected NotImplementedI18n"),
        }
    }

    #[test]
    fn not_implemented_i18n_with_different_messages() {
        let test_cases = vec![
            ("feature not available", "功能不可用"),
            ("endpoint deprecated", "端点已弃用"),
            ("under development", "开发中"),
        ];

        for (en_msg, zh_msg) in test_cases {
            let err = not_implemented_i18n(en_msg, zh_msg);
            match err {
                ApiError::NotImplementedI18n { en, zh } => {
                    assert_eq!(en, en_msg);
                    assert_eq!(zh, zh_msg);
                }
                _ => panic!("expected NotImplementedI18n"),
            }
        }
    }

    #[tokio::test]
    async fn not_implemented_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = not_implemented_i18n("feature not available", "功能不可用");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("feature not available")
        );
    }

    #[tokio::test]
    async fn not_implemented_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = not_implemented_i18n("feature not available", "功能不可用");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("功能不可用")
        );
    }

    #[test]
    fn deprecated_endpoint_i18n_en() {
        let err = deprecated_endpoint_i18n("/api/v2/users");
        match err {
            ApiError::NotImplementedI18n { en, zh } => {
                assert_eq!(
                    en,
                    "This endpoint is deprecated. Please use /api/v2/users instead"
                );
                assert_eq!(zh, "此端点已弃用。请改用 /api/v2/users");
            }
            _ => panic!("expected NotImplementedI18n"),
        }
    }

    #[test]
    fn deprecated_endpoint_i18n_with_different_alternatives() {
        let test_cases = vec![
            (
                "/api/v2/users",
                "This endpoint is deprecated. Please use /api/v2/users instead",
                "此端点已弃用。请改用 /api/v2/users",
            ),
            (
                "/api/v2/projects",
                "This endpoint is deprecated. Please use /api/v2/projects instead",
                "此端点已弃用。请改用 /api/v2/projects",
            ),
            (
                "/api/v2/workspaces",
                "This endpoint is deprecated. Please use /api/v2/workspaces instead",
                "此端点已弃用。请改用 /api/v2/workspaces",
            ),
        ];

        for (alternative, expected_en, expected_zh) in test_cases {
            let err = deprecated_endpoint_i18n(alternative);
            match err {
                ApiError::NotImplementedI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected NotImplementedI18n"),
            }
        }
    }

    #[tokio::test]
    async fn deprecated_endpoint_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = deprecated_endpoint_i18n("/api/v2/users");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("This endpoint is deprecated. Please use /api/v2/users instead")
        );
    }

    #[tokio::test]
    async fn deprecated_endpoint_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = deprecated_endpoint_i18n("/api/v2/projects");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("此端点已弃用。请改用 /api/v2/projects")
        );
    }

    #[test]
    fn feature_under_development_i18n_en() {
        let err = feature_under_development_i18n("advanced_analytics");
        match err {
            ApiError::NotImplementedI18n { en, zh } => {
                assert_eq!(
                    en,
                    "Feature 'advanced_analytics' is currently under development"
                );
                assert_eq!(zh, "功能 'advanced_analytics' 正在开发中");
            }
            _ => panic!("expected NotImplementedI18n"),
        }
    }

    #[test]
    fn feature_under_development_i18n_with_different_features() {
        let test_cases = vec![
            (
                "advanced_analytics",
                "Feature 'advanced_analytics' is currently under development",
                "功能 'advanced_analytics' 正在开发中",
            ),
            (
                "video_export",
                "Feature 'video_export' is currently under development",
                "功能 'video_export' 正在开发中",
            ),
            (
                "real_time_collaboration",
                "Feature 'real_time_collaboration' is currently under development",
                "功能 'real_time_collaboration' 正在开发中",
            ),
        ];

        for (feature, expected_en, expected_zh) in test_cases {
            let err = feature_under_development_i18n(feature);
            match err {
                ApiError::NotImplementedI18n { en, zh } => {
                    assert_eq!(en, expected_en);
                    assert_eq!(zh, expected_zh);
                }
                _ => panic!("expected NotImplementedI18n"),
            }
        }
    }

    #[tokio::test]
    async fn feature_under_development_i18n_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = feature_under_development_i18n("advanced_analytics");
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("Feature 'advanced_analytics' is currently under development")
        );
    }

    #[tokio::test]
    async fn feature_under_development_i18n_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = feature_under_development_i18n("video_export");
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("功能 'video_export' 正在开发中")
        );
    }

    #[test]
    fn validate_uuid_passes_for_valid_uuids() {
        // Test various valid UUID formats
        assert!(validate_uuid("550e8400-e29b-41d4-a716-446655440000", "userId").is_ok());
        assert!(validate_uuid("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "workspaceId").is_ok());
        assert!(validate_uuid("00000000-0000-0000-0000-000000000000", "id").is_ok());
        assert!(validate_uuid("ffffffff-ffff-ffff-ffff-ffffffffffff", "id").is_ok());
    }

    #[test]
    fn validate_uuid_fails_for_invalid_uuids() {
        // Test various invalid UUID formats
        assert!(validate_uuid("not-a-uuid", "userId").is_err());
        assert!(validate_uuid("", "userId").is_err());
        assert!(validate_uuid("550e8400-e29b-41d4-a716", "userId").is_err()); // Too short
        assert!(validate_uuid("550e8400-e29b-41d4-a716-446655440000-extra", "userId").is_err()); // Too long
        assert!(validate_uuid("550e8400-e29b-41d4-a716-44665544000g", "userId").is_err()); // Invalid character
        assert!(validate_uuid("not a valid uuid at all", "userId").is_err());
    }

    #[test]
    fn validate_uuid_error_message_en() {
        let err = validate_uuid("invalid-uuid", "userId").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(en, "Invalid format for field 'userId': expected valid UUID");
                assert_eq!(zh, "字段 'userId' 格式无效：期望有效的 UUID");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[test]
    fn validate_uuid_error_message_with_different_field() {
        let err = validate_uuid("not-a-uuid", "workspaceId").unwrap_err();
        match err {
            ApiError::BadRequestI18n { en, zh } => {
                assert_eq!(
                    en,
                    "Invalid format for field 'workspaceId': expected valid UUID"
                );
                assert_eq!(zh, "字段 'workspaceId' 格式无效：期望有效的 UUID");
            }
            _ => panic!("expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn validate_uuid_response_en() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let err = validate_uuid("invalid-uuid", "userId").unwrap_err();
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
            Some("Invalid format for field 'userId': expected valid UUID")
        );
    }

    #[tokio::test]
    async fn validate_uuid_response_zh() {
        use axum::body::to_bytes;
        use axum::response::IntoResponse;

        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = validate_uuid("not-a-uuid", "workspaceId").unwrap_err();
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
            Some("字段 'workspaceId' 格式无效：期望有效的 UUID")
        );
    }
}
