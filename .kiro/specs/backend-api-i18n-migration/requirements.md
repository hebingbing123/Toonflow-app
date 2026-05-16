# Requirements Document

## Introduction

This document specifies the requirements for migrating all remaining backend API error messages to support bilingual (English/Chinese) responses based on the `Accept-Language` request header. The system currently has partial i18n support for common validation helpers, but many error types (BadRequest, Conflict, Forbidden, NotImplemented) still use hardcoded English messages. This migration will extend the existing i18n infrastructure to cover all error types comprehensively.

## Glossary

- **Error_System**: The backend error handling module (`backend/src/error/`)
- **ApiError**: The enumeration type representing all possible API errors
- **Helper_Library**: The collection of validation and error construction functions in `helpers.rs`
- **Accept_Language_Header**: HTTP request header indicating client's preferred language
- **ApiLocale**: Enumeration representing supported response languages (En, Zh)
- **REQUEST_LOCALE**: Task-local variable storing the current request's language preference
- **Error_Variant**: A specific case in the ApiError enumeration (e.g., BadRequest, Conflict)
- **Migration_Guide**: Documentation explaining the i18n migration process for developers

## Requirements

### Requirement 1

**User Story:** As an API client, I want to receive error messages in my preferred language (English or Chinese), so that I can understand and handle errors appropriately.

#### Acceptance Criteria

1. WHEN a client sends a request with `Accept-Language: zh` or `Accept-Language: zh-CN` THEN the Error_System SHALL return error messages in Chinese
2. WHEN a client sends a request with `Accept-Language: en` or no Accept-Language header THEN the Error_System SHALL return error messages in English
3. WHEN a client sends a request with multiple language preferences THEN the Error_System SHALL select the language with the highest quality value (q parameter)
4. THE Error_System SHALL preserve the existing error response structure (status, code, message, request_id, details, retry_after_ms)
5. THE Error_System SHALL maintain backward compatibility with existing API clients

### Requirement 2

**User Story:** As a backend developer, I want all BadRequest error variants to support bilingual messages, so that validation errors are accessible to all users.

#### Acceptance Criteria

1. WHEN ApiError::BadRequest is constructed with a dynamic message THEN the Error_System SHALL provide a mechanism to supply both English and Chinese versions
2. WHEN existing code uses `ApiError::BadRequest(String)` THEN the Error_System SHALL continue to support this pattern during migration
3. WHEN validation helpers create BadRequest errors THEN the Error_System SHALL automatically select the appropriate language based on REQUEST_LOCALE
4. THE Error_System SHALL provide helper functions for common BadRequest scenarios (e.g., invalid format, missing field, invalid value)

### Requirement 3

**User Story:** As a backend developer, I want all Conflict error variants to support bilingual messages, so that resource conflict errors are clear to all users.

#### Acceptance Criteria

1. WHEN ApiError::Conflict is constructed THEN the Error_System SHALL accept both English and Chinese message variants
2. WHEN ApiError::ConflictWithDetails is constructed THEN the Error_System SHALL accept bilingual messages while preserving the details JSON structure
3. THE Error_System SHALL provide helper functions for common conflict scenarios (e.g., version conflict, duplicate resource, concurrent modification)

### Requirement 4

**User Story:** As a backend developer, I want all Forbidden error variants to support bilingual messages, so that authorization errors are understandable to all users.

#### Acceptance Criteria

1. WHEN ApiError::Forbidden is constructed THEN the Error_System SHALL accept both English and Chinese message variants
2. THE Error_System SHALL provide helper functions for common forbidden scenarios (e.g., insufficient permissions, feature not enabled, workspace access denied)
3. WHEN the existing `forbidden_i18n` helper is used THEN the Error_System SHALL continue to support this pattern

### Requirement 5

**User Story:** As a backend developer, I want all NotImplemented error variants to support bilingual messages, so that feature availability messages are clear to all users.

#### Acceptance Criteria

1. WHEN ApiError::NotImplemented is constructed THEN the Error_System SHALL accept both English and Chinese message variants
2. THE Error_System SHALL provide helper functions for common not-implemented scenarios (e.g., deprecated endpoint, feature under development, platform-specific limitation)

### Requirement 6

**User Story:** As a backend developer, I want extended validation helper functions, so that I can easily create bilingual validation errors.

#### Acceptance Criteria

1. THE Helper_Library SHALL provide `validate_uuid` for UUID format validation with bilingual messages
2. THE Helper_Library SHALL provide `validate_url` for URL format validation with bilingual messages
3. THE Helper_Library SHALL provide `validate_email` for email format validation with bilingual messages
4. THE Helper_Library SHALL provide `validate_json` for JSON format validation with bilingual messages
5. THE Helper_Library SHALL provide `validate_min_length` for minimum string length validation with bilingual messages
6. THE Helper_Library SHALL provide `validate_array_not_empty` for non-empty array validation with bilingual messages
7. THE Helper_Library SHALL provide `validate_unique_items` for array uniqueness validation with bilingual messages

### Requirement 7

**User Story:** As a backend developer, I want a comprehensive migration guide, so that I can systematically update all error call sites.

#### Acceptance Criteria

1. THE Migration_Guide SHALL document the migration process for each Error_Variant
2. THE Migration_Guide SHALL provide before/after code examples for each error type
3. THE Migration_Guide SHALL list all modules that need migration
4. THE Migration_Guide SHALL provide a checklist for verifying migration completeness
5. THE Migration_Guide SHALL document testing strategies for bilingual errors
6. THE Migration_Guide SHALL explain how to handle dynamic error messages with variable interpolation

### Requirement 8

**User Story:** As a backend developer, I want all error construction patterns to be consistent, so that the codebase is maintainable and predictable.

#### Acceptance Criteria

1. THE Error_System SHALL use a consistent pattern for all bilingual error constructors
2. THE Error_System SHALL use a consistent naming convention for helper functions (e.g., `*_i18n` suffix for bilingual helpers)
3. THE Error_System SHALL provide clear documentation for when to use each helper function
4. THE Error_System SHALL minimize code duplication across error construction helpers

### Requirement 9

**User Story:** As a QA engineer, I want comprehensive test coverage for bilingual errors, so that I can verify correct language selection.

#### Acceptance Criteria

1. THE Error_System SHALL include unit tests for each bilingual error variant in both English and Chinese
2. THE Error_System SHALL include tests for Accept-Language header parsing with quality values
3. THE Error_System SHALL include tests for fallback behavior when REQUEST_LOCALE is not set
4. THE Error_System SHALL include property-based tests for error response structure consistency across languages

### Requirement 10

**User Story:** As a backend developer, I want to migrate all existing error call sites systematically, so that no error messages are missed.

#### Acceptance Criteria

1. WHEN migrating BadRequest errors THEN the Error_System SHALL update all call sites in all backend modules
2. WHEN migrating Conflict errors THEN the Error_System SHALL update all call sites in all backend modules
3. WHEN migrating Forbidden errors THEN the Error_System SHALL update all call sites in all backend modules
4. WHEN migrating NotImplemented errors THEN the Error_System SHALL update all call sites in all backend modules
5. THE Error_System SHALL maintain a migration progress tracker documenting completed modules
