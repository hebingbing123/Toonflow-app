# Backend API I18n Migration Guide

## Overview

This guide documents the migration process for converting all backend API error messages to support bilingual (English/Chinese) responses based on the `Accept-Language` request header.

### Purpose

- **User Experience**: Provide error messages in the user's preferred language (English or Chinese)
- **Consistency**: Standardize error handling patterns across the entire backend codebase
- **Maintainability**: Use helper functions to reduce code duplication and ensure consistent translations

### Scope

This migration covers all error types in the `backend/src/error/` module:
- **BadRequest** errors (HTTP 400) - validation and input errors
- **Conflict** errors (HTTP 409) - resource conflicts and version mismatches
- **Forbidden** errors (HTTP 403) - authorization and permission errors
- **NotImplemented** errors (HTTP 501) - deprecated or unavailable features

### How It Works

1. **Language Detection**: The HTTP middleware extracts the `Accept-Language` header from each request
2. **Locale Storage**: The preferred language is stored in `REQUEST_LOCALE` (task-local variable)
3. **Error Construction**: Helper functions automatically select the appropriate message based on the current locale
4. **Response**: The error response includes the message in the user's preferred language

### Backward Compatibility

- Existing error constructors (e.g., `ApiError::BadRequest(String)`) continue to work unchanged
- Old patterns can coexist with new bilingual patterns during migration
- No breaking changes to the error response JSON structure

---

## Quick Reference

### Error Type Migration Table

| Old Pattern | New Pattern | Use Case |
|------------|-------------|----------|
| `ApiError::BadRequest(msg)` | `bad_request_i18n(en, zh)` | Custom validation errors |
| `ApiError::BadRequest(format!("Invalid {}", field))` | `invalid_format_i18n(field, expected)` | Format validation |
| `ApiError::BadRequest(format!("Missing {}", field))` | `missing_field_i18n(field)` | Required field missing |
| `ApiError::BadRequest(format!("{} invalid", field))` | `invalid_value_i18n(field, reason)` | Invalid field value |
| `ApiError::Conflict(msg)` | `conflict_i18n(en, zh)` | Custom conflict errors |
| `ApiError::Conflict(format!("{} exists", name))` | `duplicate_resource_i18n(type, id)` | Duplicate resource |
| `ApiError::Conflict("version mismatch")` | `version_conflict_i18n(resource)` | Version conflict |
| `ApiError::Conflict("concurrent update")` | `concurrent_modification_i18n(resource)` | Concurrent modification |
| `ApiError::Forbidden(msg)` | `forbidden_i18n(en, zh)` | Custom forbidden errors |
| `ApiError::Forbidden("no permission")` | `insufficient_permissions_i18n(action)` | Permission denied |
| `ApiError::Forbidden("feature disabled")` | `feature_not_enabled_i18n(feature)` | Feature not enabled |
| `ApiError::Forbidden("workspace access")` | `workspace_access_denied_i18n()` | Workspace access denied |
| `ApiError::NotImplemented(msg)` | `not_implemented_i18n(en, zh)` | Custom not-implemented |
| `ApiError::NotImplemented("deprecated")` | `deprecated_endpoint_i18n(alternative)` | Deprecated endpoint |
| `ApiError::NotImplemented("coming soon")` | `feature_under_development_i18n(feature)` | Feature in development |

### Validation Helper Functions

| Helper Function | Purpose | Example |
|----------------|---------|---------|
| `validate_uuid(value, field)` | UUID format validation | `validate_uuid(&id, "userId")?` |
| `validate_url(value, field)` | HTTP/HTTPS URL validation | `validate_url(&url, "webhookUrl")?` |
| `validate_email(value, field)` | Email format validation | `validate_email(&email, "email")?` |
| `validate_json(value, field)` | JSON format validation | `validate_json(&data, "metadata")?` |
| `validate_min_length(value, min, field)` | Minimum string length | `validate_min_length(&pwd, 8, "password")?` |
| `validate_array_not_empty(arr, field)` | Non-empty array | `validate_array_not_empty(&items, "items")?` |
| `validate_unique_items(arr, field)` | Array uniqueness | `validate_unique_items(&tags, "tags")?` |

---

## Error Type Migration Examples

### BadRequest Errors

#### Before: Custom validation error
```rust
// Old pattern
return Err(ApiError::BadRequest("Invalid email format".to_string()));
```

#### After: Using bilingual helper
```rust
// New pattern
return Err(bad_request_i18n(
    "Invalid email format",
    "电子邮件格式无效"
));
```

#### Before: Format validation with field name
```rust
// Old pattern
return Err(ApiError::BadRequest(format!(
    "Invalid format for field '{}': expected UUID",
    field_name
)));
```

#### After: Using format validation helper
```rust
// New pattern
return Err(invalid_format_i18n(field_name, "UUID format"));
```

#### Before: Missing required field
```rust
// Old pattern
return Err(ApiError::BadRequest(format!(
    "Missing required field '{}'",
    field_name
)));
```

#### After: Using missing field helper
```rust
// New pattern
return Err(missing_field_i18n(field_name));
```

#### Before: Invalid field value
```rust
// Old pattern
return Err(ApiError::BadRequest(format!(
    "Invalid value for field '{}': must be positive",
    field_name
)));
```

#### After: Using invalid value helper
```rust
// New pattern
return Err(invalid_value_i18n(field_name, "must be positive"));
```

#### Using Validation Helpers

Instead of manual validation + error construction, use validation helpers:

```rust
// Before: Manual UUID validation
if uuid::Uuid::parse_str(&user_id).is_err() {
    return Err(ApiError::BadRequest("Invalid user ID format".to_string()));
}

// After: Using validation helper
validate_uuid(&user_id, "userId")?;
```

```rust
// Before: Manual URL validation
if url::Url::parse(&webhook_url).is_err() {
    return Err(ApiError::BadRequest("Invalid webhook URL".to_string()));
}

// After: Using validation helper
validate_url(&webhook_url, "webhookUrl")?;
```

```rust
// Before: Manual email validation
if !email.contains('@') {
    return Err(ApiError::BadRequest("Invalid email address".to_string()));
}

// After: Using validation helper
validate_email(&email, "email")?;
```

---

### Conflict Errors

#### Before: Custom conflict error
```rust
// Old pattern
return Err(ApiError::Conflict("Resource already exists".to_string()));
```

#### After: Using bilingual helper
```rust
// New pattern
return Err(conflict_i18n(
    "Resource already exists",
    "资源已存在"
));
```

#### Before: Duplicate resource
```rust
// Old pattern
return Err(ApiError::Conflict(format!(
    "Workspace '{}' already exists",
    workspace_name
)));
```

#### After: Using duplicate resource helper
```rust
// New pattern
return Err(duplicate_resource_i18n("workspace", &workspace_name));
```

#### Before: Version conflict
```rust
// Old pattern
return Err(ApiError::Conflict("Timeline has been modified by another user".to_string()));
```

#### After: Using version conflict helper
```rust
// New pattern
return Err(version_conflict_i18n("Timeline"));
```

#### Before: Concurrent modification
```rust
// Old pattern
return Err(ApiError::Conflict("Project is being modified by another operation".to_string()));
```

#### After: Using concurrent modification helper
```rust
// New pattern
return Err(concurrent_modification_i18n("Project"));
```

#### Conflict with Details

For conflicts that need additional context (e.g., version information):

```rust
// Before: ConflictWithDetails
return Err(ApiError::ConflictWithDetails {
    message: "Version conflict".to_string(),
    details: serde_json::json!({
        "expected_version": expected,
        "current_version": current,
    }),
});

// After: Use ConflictWithDetailsI18n variant (via helper if needed)
// Note: Currently no dedicated helper for this; use the variant directly
return Err(ApiError::ConflictWithDetailsI18n {
    en: "Version conflict".to_string(),
    zh: "版本冲突".to_string(),
    details: serde_json::json!({
        "expected_version": expected,
        "current_version": current,
    }),
});
```

---

### Forbidden Errors

#### Before: Custom forbidden error
```rust
// Old pattern
return Err(ApiError::Forbidden("Access denied".to_string()));
```

#### After: Using bilingual helper
```rust
// New pattern
return Err(forbidden_i18n(
    "Access denied",
    "访问被拒绝"
));
```

#### Before: Insufficient permissions
```rust
// Old pattern
return Err(ApiError::Forbidden(format!(
    "Insufficient permissions to {}",
    action
)));
```

#### After: Using insufficient permissions helper
```rust
// New pattern
return Err(insufficient_permissions_i18n(action));
```

#### Before: Feature not enabled
```rust
// Old pattern
return Err(ApiError::Forbidden(format!(
    "Feature '{}' is not enabled",
    feature_name
)));
```

#### After: Using feature not enabled helper
```rust
// New pattern
return Err(feature_not_enabled_i18n(feature_name));
```

#### Before: Workspace access denied
```rust
// Old pattern
return Err(ApiError::Forbidden("Access to workspace denied".to_string()));
```

#### After: Using workspace access denied helper
```rust
// New pattern
return Err(workspace_access_denied_i18n());
```

---

### NotImplemented Errors

#### Before: Custom not-implemented error
```rust
// Old pattern
return Err(ApiError::NotImplemented("Feature not available".to_string()));
```

#### After: Using bilingual helper
```rust
// New pattern
return Err(not_implemented_i18n(
    "Feature not available",
    "功能不可用"
));
```

#### Before: Deprecated endpoint
```rust
// Old pattern
return Err(ApiError::NotImplemented(format!(
    "This endpoint is deprecated. Please use {} instead",
    new_endpoint
)));
```

#### After: Using deprecated endpoint helper
```rust
// New pattern
return Err(deprecated_endpoint_i18n(new_endpoint));
```

#### Before: Feature under development
```rust
// Old pattern
return Err(ApiError::NotImplemented(format!(
    "Feature '{}' is currently under development",
    feature_name
)));
```

#### After: Using feature under development helper
```rust
// New pattern
return Err(feature_under_development_i18n(feature_name));
```

---

## Dynamic Message Handling

### Variable Interpolation

When error messages need dynamic values, use Rust's `format!()` macro with the bilingual helpers:

#### Example 1: Custom message with variables
```rust
// Dynamic values
let max_size = 1024;
let actual_size = 2048;

// Construct bilingual messages with format!()
return Err(bad_request_i18n(
    &format!("File size {} exceeds maximum {}", actual_size, max_size),
    &format!("文件大小 {} 超过最大值 {}", actual_size, max_size)
));
```

#### Example 2: Resource-specific conflict
```rust
// Dynamic resource information
let resource_type = "project";
let resource_id = "proj_123";
let user_name = "Alice";

return Err(conflict_i18n(
    &format!("{} '{}' is currently being edited by {}", resource_type, resource_id, user_name),
    &format!("{} '{}' 正在被 {} 编辑", resource_type, resource_id, user_name)
));
```

#### Example 3: Permission with context
```rust
// Dynamic action and resource
let action = "delete";
let resource = "workspace settings";

return Err(forbidden_i18n(
    &format!("You do not have permission to {} {}", action, resource),
    &format!("您没有权限{}{}", action, resource)
));
```

### Best Practices for Dynamic Messages

1. **Keep translations consistent**: Ensure variable order and formatting work in both languages
2. **Use helper functions when possible**: Many common patterns have dedicated helpers
3. **Test both languages**: Verify that dynamic values render correctly in English and Chinese
4. **Avoid complex interpolation**: If the message is too complex, consider adding a new helper function

---

## Testing Guidelines

### Unit Testing Bilingual Errors

Use `REQUEST_LOCALE.scope()` to test both English and Chinese messages:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};

    #[tokio::test]
    async fn test_error_message_in_english() {
        let err = REQUEST_LOCALE.scope(ApiLocale::En, async {
            missing_field_i18n("email")
        }).await;

        match err {
            ApiError::BadRequestI18n { en, .. } => {
                assert!(en.contains("email"));
                assert!(en.contains("Missing required field"));
            }
            _ => panic!("Expected BadRequestI18n"),
        }
    }

    #[tokio::test]
    async fn test_error_message_in_chinese() {
        let err = REQUEST_LOCALE.scope(ApiLocale::Zh, async {
            missing_field_i18n("email")
        }).await;

        match err {
            ApiError::BadRequestI18n { zh, .. } => {
                assert!(zh.contains("email"));
                assert!(zh.contains("缺少必填字段"));
            }
            _ => panic!("Expected BadRequestI18n"),
        }
    }
}
```

### Testing Error Responses

Test the full HTTP response to verify correct language selection:

```rust
#[tokio::test]
async fn test_error_response_english() {
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    let err = invalid_format_i18n("userId", "UUID format");
    let resp = err.into_response();

    let bytes = to_bytes(resp.into_body(), 16 * 1024).await.expect("body bytes");
    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

    assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
    assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("bad_request"));
    
    let message = json.get("message").and_then(|v| v.as_str()).unwrap();
    assert!(message.contains("userId"));
    assert!(message.contains("UUID format"));
}

#[tokio::test]
async fn test_error_response_chinese() {
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    let resp = REQUEST_LOCALE.scope(ApiLocale::Zh, async {
        let err = invalid_format_i18n("userId", "UUID 格式");
        err.into_response()
    }).await;

    let bytes = to_bytes(resp.into_body(), 16 * 1024).await.expect("body bytes");
    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

    assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
    assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("bad_request"));
    
    let message = json.get("message").and_then(|v| v.as_str()).unwrap();
    assert!(message.contains("userId"));
    assert!(message.contains("格式无效"));
}
```

### Integration Testing with Accept-Language Header

Test end-to-end with actual HTTP requests:

```rust
#[tokio::test]
async fn test_api_endpoint_with_chinese_header() {
    use axum::http::{Request, StatusCode};
    use tower::ServiceExt;

    let app = create_test_app();

    let request = Request::builder()
        .uri("/api/v1/users")
        .header("Accept-Language", "zh-CN")
        .body(Body::empty())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    
    let body = to_bytes(response.into_body(), 16 * 1024).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    
    let message = json.get("message").and_then(|v| v.as_str()).unwrap();
    // Verify Chinese message
    assert!(message.contains("字段") || message.contains("无效"));
}
```

---

## Module Checklist

Use this checklist to track migration progress across all backend modules:

### Core Modules
- [ ] `backend/src/auth/` - Authentication and authorization
- [ ] `backend/src/middleware/` - HTTP middleware and request processing

### Resource Management
- [ ] `backend/src/workspaces/` - Workspace CRUD operations
- [ ] `backend/src/projects/` - Project management
- [ ] `backend/src/assets/` - Asset storage and retrieval
- [ ] `backend/src/settings/` - User and system settings

### Content Production
- [ ] `backend/src/production/` - Video production workflows
- [ ] `backend/src/narrative/` - Story and script management
- [ ] `backend/src/short_video/` - Short video generation
- [ ] `backend/src/scripting/` - Script processing

### Publishing & Distribution
- [ ] `backend/src/publish/` - Publishing workflows
- [ ] `backend/src/vendor/` - Third-party integrations

### Background Processing
- [ ] `backend/src/jobs/` - Background job management
- [ ] `backend/src/harness/` - Agent harness and execution

### Platform Services
- [ ] `backend/src/billing/` - Billing and subscription management
- [ ] `backend/src/metering/` - Usage tracking and metering
- [ ] `backend/src/scope/` - Workspace scope and context
- [ ] `backend/src/state/` - State management

### AI & Search
- [ ] `backend/src/llm/` - LLM integration
- [ ] `backend/src/search/` - Search functionality

---

## Migration Progress Tracker

Track completed modules and remaining work:

### Phase 1: Core Error Infrastructure ✅
- [x] Extended `ApiError` enum with bilingual variants
- [x] Implemented BadRequest helper functions
- [x] Implemented Conflict helper functions
- [x] Implemented Forbidden helper functions
- [x] Implemented NotImplemented helper functions
- [x] Implemented validation helper functions
- [x] Added comprehensive unit tests
- [x] Added property-based tests

### Phase 2: Module Migration (In Progress)
- [ ] Settings module
- [ ] Workspaces module
- [ ] Projects module
- [ ] Assets module
- [ ] Production module
- [ ] Publish module
- [ ] Jobs module
- [ ] Harness module
- [ ] Billing module
- [ ] Remaining modules

### Phase 3: Verification & Documentation ✅
- [x] Created migration guide
- [ ] Updated module documentation
- [ ] Final verification pass
- [ ] All tests passing

---

## Common Pitfalls

### 1. Forgetting to Import Helper Functions

**Problem:**
```rust
// Compiler error: cannot find function `invalid_format_i18n`
return Err(invalid_format_i18n("email", "valid email address"));
```

**Solution:**
```rust
use crate::error::helpers::invalid_format_i18n;

return Err(invalid_format_i18n("email", "valid email address"));
```

### 2. Using Old Pattern in New Code

**Problem:**
```rust
// Old pattern - not bilingual
return Err(ApiError::BadRequest("Invalid input".to_string()));
```

**Solution:**
```rust
// New pattern - bilingual
return Err(bad_request_i18n("Invalid input", "输入无效"));
```

### 3. Inconsistent Variable Order in Translations

**Problem:**
```rust
// Variable order differs between languages
return Err(bad_request_i18n(
    &format!("Field {} must be between {} and {}", field, min, max),
    &format!("{} 和 {} 之间必须是字段 {}", min, max, field) // Wrong order!
));
```

**Solution:**
```rust
// Keep variable order consistent
return Err(bad_request_i18n(
    &format!("Field {} must be between {} and {}", field, min, max),
    &format!("字段 {} 必须在 {} 和 {} 之间", field, min, max)
));
```

### 4. Not Testing Both Languages

**Problem:**
```rust
// Only testing English
#[test]
fn test_error() {
    let err = missing_field_i18n("email");
    // Only checks English message
}
```

**Solution:**
```rust
// Test both languages
#[tokio::test]
async fn test_error_english() {
    let err = REQUEST_LOCALE.scope(ApiLocale::En, async {
        missing_field_i18n("email")
    }).await;
    // Check English message
}

#[tokio::test]
async fn test_error_chinese() {
    let err = REQUEST_LOCALE.scope(ApiLocale::Zh, async {
        missing_field_i18n("email")
    }).await;
    // Check Chinese message
}
```

### 5. Using Helper Functions for Complex Cases

**Problem:**
```rust
// Trying to use a simple helper for a complex case
return Err(invalid_format_i18n(
    "configuration",
    "valid JSON with required fields: name, type, and settings"
));
```

**Solution:**
```rust
// Use custom bilingual message for complex cases
return Err(bad_request_i18n(
    "Invalid configuration format: expected valid JSON with required fields: name, type, and settings",
    "配置格式无效：期望包含必填字段的有效 JSON：name、type 和 settings"
));
```

---

## Getting Help

### Resources

- **Error Module Documentation**: `backend/src/error/mod.rs`
- **Helper Functions**: `backend/src/error/helpers.rs`
- **Test Examples**: `backend/src/error/helpers_test.rs`
- **Design Document**: `.kiro/specs/backend-api-i18n-migration/design.md`
- **Requirements**: `.kiro/specs/backend-api-i18n-migration/requirements.md`

### Questions?

If you encounter issues during migration:

1. Check existing test cases in `helpers_test.rs` for examples
2. Review the design document for architectural decisions
3. Look for similar patterns in already-migrated modules
4. Consult the team for translation accuracy

---

## Summary

This migration improves user experience by providing error messages in the user's preferred language while maintaining backward compatibility and code consistency. Follow the patterns in this guide, use the provided helper functions, and test both languages to ensure a successful migration.

**Key Takeaways:**
- Use helper functions instead of constructing errors manually
- Test both English and Chinese messages
- Keep translations consistent and accurate
- Migrate module by module to minimize risk
- Update the progress tracker as you complete each module
