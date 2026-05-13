# Design Document: Backend API I18n Migration

## Overview

This design extends the existing bilingual error handling infrastructure in `backend/src/error/` to cover all remaining error types (BadRequest, Conflict, Forbidden, NotImplemented). The system will maintain backward compatibility while providing new bilingual constructors and helper functions that automatically select the appropriate language based on the `Accept-Language` request header.

## Architecture

### Current State

The error system already has:
- `ApiLocale` enum (En, Zh) for language selection
- `REQUEST_LOCALE` task-local variable for storing current request's language preference
- `preferred_locale_from_headers()` for parsing Accept-Language headers
- Bilingual support for fixed error messages (Unauthorized, NotFound, etc.)
- Partial bilingual support for validation helpers (`validate_non_empty_string`, `validate_range`, `validate_enum`)
- `bad_request_i18n()` and `forbidden_i18n()` helpers for custom bilingual messages

### Design Principles

1. **Backward Compatibility**: Existing error constructors continue to work unchanged
2. **Consistent Patterns**: All bilingual helpers follow the `*_i18n` naming convention
3. **Minimal Duplication**: Shared logic for language selection and error construction
4. **Type Safety**: Rust's type system ensures correct usage at compile time
5. **Zero Runtime Overhead**: Language selection happens once per request via task-local storage

## Components

### 1. Enhanced ApiError Enum

The `ApiError` enum will be extended to support bilingual variants:

```rust
pub enum ApiError {
    // ... existing variants ...
    
    // New bilingual variants (internal use only)
    BadRequestI18n { en: String, zh: String },
    ConflictI18n { en: String, zh: String },
    ConflictWithDetailsI18n { en: String, zh: String, details: serde_json::Value },
    ForbiddenI18n { en: String, zh: String },
    NotImplementedI18n { en: String, zh: String },
}
```

**Note**: The `*I18n` variants are internal implementation details. Public API uses helper functions.

### 2. Extended Helper Library

New helper functions in `helpers.rs`:

#### Error Construction Helpers

```rust
// BadRequest helpers
pub fn bad_request_i18n(en_msg: &str, zh_msg: &str) -> ApiError;
pub fn invalid_format_i18n(field_name: &str, expected: &str) -> ApiError;
pub fn missing_field_i18n(field_name: &str) -> ApiError;
pub fn invalid_value_i18n(field_name: &str, reason: &str) -> ApiError;

// Conflict helpers
pub fn conflict_i18n(en_msg: &str, zh_msg: &str) -> ApiError;
pub fn version_conflict_i18n(resource: &str) -> ApiError;
pub fn duplicate_resource_i18n(resource_type: &str, identifier: &str) -> ApiError;
pub fn concurrent_modification_i18n(resource: &str) -> ApiError;

// Forbidden helpers (forbidden_i18n already exists)
pub fn insufficient_permissions_i18n(action: &str) -> ApiError;
pub fn feature_not_enabled_i18n(feature: &str) -> ApiError;
pub fn workspace_access_denied_i18n() -> ApiError;

// NotImplemented helpers
pub fn not_implemented_i18n(en_msg: &str, zh_msg: &str) -> ApiError;
pub fn deprecated_endpoint_i18n(alternative: &str) -> ApiError;
pub fn feature_under_development_i18n(feature: &str) -> ApiError;
```

#### Validation Helpers

```rust
pub fn validate_uuid(value: &str, field_name: &str) -> Result<(), ApiError>;
pub fn validate_url(value: &str, field_name: &str) -> Result<(), ApiError>;
pub fn validate_email(value: &str, field_name: &str) -> Result<(), ApiError>;
pub fn validate_json(value: &str, field_name: &str) -> Result<(), ApiError>;
pub fn validate_min_length(value: &str, min_len: usize, field_name: &str) -> Result<(), ApiError>;
pub fn validate_array_not_empty<T>(arr: &[T], field_name: &str) -> Result<(), ApiError>;
pub fn validate_unique_items<T: Eq + std::hash::Hash>(arr: &[T], field_name: &str) -> Result<(), ApiError>;
```

### 3. IntoResponse Implementation

The `IntoResponse` implementation for `ApiError` will be updated to handle the new bilingual variants:

```rust
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        // ... existing logging ...
        
        let loc = current_locale();
        
        let (status, code, message, details) = match self {
            // ... existing variants ...
            
            ApiError::BadRequestI18n { en, zh } => {
                let msg = match loc {
                    ApiLocale::En => en,
                    ApiLocale::Zh => zh,
                };
                (StatusCode::BAD_REQUEST, "bad_request", msg, None)
            }
            
            ApiError::ConflictI18n { en, zh } => {
                let msg = match loc {
                    ApiLocale::En => en,
                    ApiLocale::Zh => zh,
                };
                (StatusCode::CONFLICT, "conflict", msg, None)
            }
            
            ApiError::ConflictWithDetailsI18n { en, zh, details } => {
                let msg = match loc {
                    ApiLocale::En => en,
                    ApiLocale::Zh => zh,
                };
                (StatusCode::CONFLICT, "conflict", msg, Some(details))
            }
            
            ApiError::ForbiddenI18n { en, zh } => {
                let msg = match loc {
                    ApiLocale::En => en,
                    ApiLocale::Zh => zh,
                };
                (StatusCode::FORBIDDEN, "forbidden", msg, None)
            }
            
            ApiError::NotImplementedI18n { en, zh } => {
                let msg = match loc {
                    ApiLocale::En => en,
                    ApiLocale::Zh => zh,
                };
                (StatusCode::NOT_IMPLEMENTED, "not_implemented", msg, None)
            }
        };
        
        // ... rest of response construction ...
    }
}
```

## Data Models

### Error Response Structure (Unchanged)

```json
{
  "status": 400,
  "code": "bad_request",
  "message": "Invalid format for field 'email': expected valid email address",
  "request_id": "req_abc123",
  "details": null,
  "retry_after_ms": null
}
```

The structure remains identical; only the `message` field content changes based on language.

## Error Handling

### Language Selection Flow

1. HTTP middleware extracts `Accept-Language` header
2. `preferred_locale_from_headers()` parses header and selects language (considering q values)
3. `REQUEST_LOCALE` task-local is set for the request scope
4. Error constructors call `current_locale()` to get the selected language
5. Appropriate message (en or zh) is selected and returned

### Fallback Behavior

- If `Accept-Language` is missing → default to English
- If `Accept-Language` contains unsupported languages → default to English
- If `REQUEST_LOCALE` is not set (e.g., in unit tests) → default to English

## Migration Strategy

### Phase 1: Extend Helper Library

1. Add new bilingual error constructors to `helpers.rs`
2. Add new validation helpers with bilingual messages
3. Add comprehensive unit tests for all new helpers

### Phase 2: Update Error Enum and IntoResponse

1. Add new `*I18n` variants to `ApiError` enum
2. Update `IntoResponse` implementation to handle new variants
3. Add tests for response structure consistency

### Phase 3: Migrate Call Sites Module by Module

Migrate in this order (from least to most complex):
1. `settings/` - configuration endpoints
2. `workspaces/` - workspace management
3. `projects/` - project CRUD
4. `assets/` - asset management
5. `production/` - production workflows
6. `publish/` - publishing logic
7. `jobs/` - background jobs
8. `harness/` - agent harness
9. `billing/` - billing integration
10. All remaining modules

For each module:
1. Identify all error construction sites
2. Replace with appropriate bilingual helper
3. Add/update tests to verify both languages
4. Update migration progress tracker

### Phase 4: Documentation and Cleanup

1. Create comprehensive migration guide
2. Update module documentation
3. Remove deprecated patterns (if any)
4. Final verification pass

## Testing Strategy

### Unit Tests

- Test each bilingual helper in both English and Chinese locales
- Test Accept-Language header parsing with various formats
- Test fallback behavior when locale is not set
- Test backward compatibility with existing error constructors

### Property-Based Tests

- Error response structure consistency across languages
- Accept-Language parsing with random q values
- Validation helpers with random valid/invalid inputs

### Integration Tests

- End-to-end API tests with different Accept-Language headers
- Verify existing API clients continue to work

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Language Selection Consistency

*For any* error type and any Accept-Language header with `zh` as the highest priority language, the returned error message SHALL be in Chinese.

**Validates: Requirements 1.1, 1.3**

### Property 2: English Default Fallback

*For any* error type and any Accept-Language header without `zh` or `en`, or with `en` as the highest priority, or with no Accept-Language header, the returned error message SHALL be in English.

**Validates: Requirements 1.2, 1.3**

### Property 3: Error Structure Preservation

*For any* error type and any language selection, the error response JSON SHALL contain exactly the fields: status (u16), code (string), message (string), and optionally request_id, details, retry_after_ms.

**Validates: Requirements 1.4**

### Property 4: Bilingual Constructor Correctness

*For any* bilingual error constructor (BadRequestI18n, ConflictI18n, ForbiddenI18n, NotImplementedI18n) and any pair of English/Chinese messages, when constructed in English locale the message SHALL be the English variant, and when constructed in Chinese locale the message SHALL be the Chinese variant.

**Validates: Requirements 2.1, 3.1, 4.1, 5.1**

### Property 5: Details Preservation Across Languages

*For any* ConflictWithDetailsI18n error and any details JSON object, the details field in the response SHALL be identical regardless of the selected language.

**Validates: Requirements 3.2**

### Property 6: Validation Helper Language Consistency

*For any* validation helper function (validate_uuid, validate_url, validate_email, validate_json, validate_min_length, validate_array_not_empty, validate_unique_items) and any invalid input, the error message language SHALL match the current REQUEST_LOCALE.

**Validates: Requirements 2.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**

### Property 7: UUID Validation Correctness

*For any* string that is a valid UUID (format: 8-4-4-4-12 hexadecimal), validate_uuid SHALL return Ok, and for any string that is not a valid UUID, validate_uuid SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.1**

### Property 8: URL Validation Correctness

*For any* string that is a valid HTTP/HTTPS URL, validate_url SHALL return Ok, and for any string that is not a valid URL, validate_url SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.2**

### Property 9: Email Validation Correctness

*For any* string that matches standard email format (local@domain), validate_email SHALL return Ok, and for any string that does not match email format, validate_email SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.3**

### Property 10: JSON Validation Correctness

*For any* string that is valid JSON, validate_json SHALL return Ok, and for any string that is not valid JSON, validate_json SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.4**

### Property 11: Minimum Length Validation Correctness

*For any* string with length >= min_length, validate_min_length SHALL return Ok, and for any string with length < min_length, validate_min_length SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.5**

### Property 12: Array Non-Empty Validation Correctness

*For any* non-empty array, validate_array_not_empty SHALL return Ok, and for any empty array, validate_array_not_empty SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.6**

### Property 13: Array Uniqueness Validation Correctness

*For any* array where all elements are unique, validate_unique_items SHALL return Ok, and for any array containing duplicate elements, validate_unique_items SHALL return an ApiError with appropriate bilingual message.

**Validates: Requirements 6.7**

### Property 14: Accept-Language Quality Value Parsing

*For any* Accept-Language header string with multiple language tags and quality values, the language with the highest quality value SHALL be selected, with ties broken in favor of the first occurrence.

**Validates: Requirements 1.3, 9.2**

## Migration Guide Structure

The migration guide (`MIGRATION_GUIDE.md`) will include:

1. **Overview**: Purpose and scope of migration
2. **Quick Reference**: Table of old patterns → new patterns
3. **Error Type Migration**:
   - BadRequest migration examples
   - Conflict migration examples
   - Forbidden migration examples
   - NotImplemented migration examples
4. **Validation Helper Usage**: Examples for each new validation helper
5. **Dynamic Message Handling**: How to handle messages with variable interpolation
6. **Testing Guidelines**: How to test bilingual errors
7. **Module Checklist**: List of all modules to migrate
8. **Progress Tracker**: Template for tracking migration progress
9. **Common Pitfalls**: Mistakes to avoid during migration

## Performance Considerations

- Language selection happens once per request (via task-local storage)
- No runtime overhead for string selection (compile-time branching)
- Error construction is already on the error path (not performance-critical)
- No additional allocations beyond existing error handling

## Security Considerations

- Error messages should not leak sensitive information in any language
- Both English and Chinese messages must be reviewed for information disclosure
- Validation error messages should be generic enough to prevent enumeration attacks

## Backward Compatibility

- All existing error constructors continue to work
- Existing API clients see no breaking changes
- Old error patterns can coexist with new patterns during migration
- No changes to error response JSON structure
