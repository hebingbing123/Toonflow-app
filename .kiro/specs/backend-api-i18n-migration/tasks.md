# Implementation Plan: Backend API I18n Migration

## Overview

This plan implements comprehensive bilingual (English/Chinese) error message support for all remaining backend API error types. The implementation extends the existing i18n infrastructure in `backend/src/error/` to cover BadRequest, Conflict, Forbidden, and NotImplemented errors, while maintaining full backward compatibility.

## Tasks

- [x] 1. Extend ApiError enum with bilingual variants
  - Add `BadRequestI18n`, `ConflictI18n`, `ConflictWithDetailsI18n`, `ForbiddenI18n`, `NotImplementedI18n` variants to the ApiError enum in `backend/src/error/mod.rs`
  - Update `IntoResponse` implementation to handle new variants with language selection based on `current_locale()`
  - Add logging for new error variants
  - _Requirements: 2.1, 3.1, 4.1, 5.1_

- [x] 1.1 Write property test for bilingual constructor correctness
  - **Property 4: Bilingual Constructor Correctness**
  - **Validates: Requirements 2.1, 3.1, 4.1, 5.1**

- [x] 1.2 Write property test for error structure preservation
  - **Property 3: Error Structure Preservation**
  - **Validates: Requirements 1.4**

- [x] 2. Implement BadRequest helper functions
  - [x] 2.1 Implement `invalid_format_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for format validation errors with field name and expected format parameters
    - Return `ApiError::BadRequestI18n` with appropriate English and Chinese messages
    - _Requirements: 2.4_
  
  - [x] 2.2 Implement `missing_field_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for missing required field errors with field name parameter
    - Return `ApiError::BadRequestI18n` with appropriate English and Chinese messages
    - _Requirements: 2.4_
  
  - [x] 2.3 Implement `invalid_value_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for invalid value errors with field name and reason parameters
    - Return `ApiError::BadRequestI18n` with appropriate English and Chinese messages
    - _Requirements: 2.4_
  
  - [x] 2.4 Write unit tests for BadRequest helpers in `backend/src/error/helpers_test.rs`
    - Test each helper in both English and Chinese locales using `REQUEST_LOCALE.scope()`
    - Test with various field names and reasons
    - _Requirements: 2.4, 9.1_

- [x] 3. Implement Conflict helper functions
  - [x] 3.1 Implement `conflict_i18n` helper in `backend/src/error/helpers.rs`
    - Create general-purpose conflict error helper accepting en_msg and zh_msg parameters
    - Return `ApiError::ConflictI18n`
    - _Requirements: 3.3_
  
  - [x] 3.2 Implement `version_conflict_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for version conflict errors with resource name parameter
    - Return `ApiError::ConflictI18n` with appropriate messages
    - _Requirements: 3.3_
  
  - [x] 3.3 Implement `duplicate_resource_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for duplicate resource errors with resource_type and identifier parameters
    - Return `ApiError::ConflictI18n` with appropriate messages
    - _Requirements: 3.3_
  
  - [x] 3.4 Implement `concurrent_modification_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for concurrent modification errors with resource parameter
    - Return `ApiError::ConflictI18n` with appropriate messages
    - _Requirements: 3.3_
  
  - [x] 3.5 Write property test for details preservation in `backend/src/error/helpers_test.rs`
    - **Property 5: Details Preservation Across Languages**
    - **Validates: Requirements 3.2**
  
  - [x] 3.6 Write unit tests for Conflict helpers in `backend/src/error/helpers_test.rs`
    - Test each helper in both English and Chinese locales
    - _Requirements: 3.3, 9.1_

- [x] 4. Implement Forbidden helper functions
  - [x] 4.1 Implement `insufficient_permissions_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for permission errors with action name parameter
    - Return `ApiError::ForbiddenI18n` with appropriate messages
    - _Requirements: 4.2_
  
  - [x] 4.2 Implement `feature_not_enabled_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for disabled feature errors with feature name parameter
    - Return `ApiError::ForbiddenI18n` with appropriate messages
    - _Requirements: 4.2_
  
  - [x] 4.3 Implement `workspace_access_denied_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for workspace access errors (no parameters needed)
    - Return `ApiError::ForbiddenI18n` with appropriate messages
    - _Requirements: 4.2_
  
  - [x] 4.4 Write unit tests for Forbidden helpers in `backend/src/error/helpers_test.rs`
    - Test each helper in both English and Chinese locales
    - _Requirements: 4.2, 9.1_

- [x] 5. Implement NotImplemented helper functions
  - [x] 5.1 Implement `not_implemented_i18n` helper in `backend/src/error/helpers.rs`
    - Create general-purpose not-implemented error helper accepting en_msg and zh_msg parameters
    - Return `ApiError::NotImplementedI18n`
    - _Requirements: 5.2_
  
  - [x] 5.2 Implement `deprecated_endpoint_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for deprecated endpoint errors with alternative endpoint parameter
    - Return `ApiError::NotImplementedI18n` with appropriate messages
    - _Requirements: 5.2_
  
  - [x] 5.3 Implement `feature_under_development_i18n` helper in `backend/src/error/helpers.rs`
    - Create helper for features under development with feature name parameter
    - Return `ApiError::NotImplementedI18n` with appropriate messages
    - _Requirements: 5.2_
  
  - [x] 5.4 Write unit tests for NotImplemented helpers in `backend/src/error/helpers_test.rs`
    - Test each helper in both English and Chinese locales
    - _Requirements: 5.2, 9.1_

- [x] 6. Checkpoint - Ensure all tests pass
  - Run `cargo test` in `backend/` directory to verify all error helper tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement validation helper functions
  - [x] 7.1 Implement `validate_uuid` helper in `backend/src/error/helpers.rs`
    - Add UUID format validation using `uuid` crate's `Uuid::parse_str()`
    - Return `Ok(())` for valid UUIDs, `Err(ApiError::BadRequestI18n)` with bilingual messages for invalid
    - _Requirements: 6.1_
  
  - [x] 7.2 Write property test for UUID validation in `backend/src/error/helpers_test.rs`
    - **Property 7: UUID Validation Correctness**
    - **Validates: Requirements 6.1**
  
  - [x] 7.3 Implement `validate_url` helper in `backend/src/error/helpers.rs`
    - Add URL format validation using `url` crate's `Url::parse()`
    - Return `Ok(())` for valid HTTP/HTTPS URLs, `Err(ApiError::BadRequestI18n)` with bilingual messages for invalid
    - _Requirements: 6.2_
  
  - [x] 7.4 Write property test for URL validation in `backend/src/error/helpers_test.rs`
    - **Property 8: URL Validation Correctness**
    - **Validates: Requirements 6.2**
  
  - [x] 7.5 Implement `validate_email` helper in `backend/src/error/helpers.rs`
    - Add email format validation using regex pattern for basic email validation (local@domain)
    - Return `Ok(())` for valid emails, `Err(ApiError::BadRequestI18n)` with bilingual messages for invalid
    - _Requirements: 6.3_
  
  - [x] 7.6 Write property test for email validation in `backend/src/error/helpers_test.rs`
    - **Property 9: Email Validation Correctness**
    - **Validates: Requirements 6.3**
  
  - [x] 7.7 Implement `validate_json` helper in `backend/src/error/helpers.rs`
    - Add JSON format validation using `serde_json::from_str::<serde_json::Value>()`
    - Return `Ok(())` for valid JSON, `Err(ApiError::BadRequestI18n)` with bilingual messages for invalid
    - _Requirements: 6.4_
  
  - [x] 7.8 Write property test for JSON validation in `backend/src/error/helpers_test.rs`
    - **Property 10: JSON Validation Correctness**
    - **Validates: Requirements 6.4**
  
  - [x] 7.9 Implement `validate_min_length` helper in `backend/src/error/helpers.rs`
    - Add minimum string length validation checking `value.len() >= min_len`
    - Return `Ok(())` for valid length, `Err(ApiError::BadRequestI18n)` with bilingual messages for too short
    - _Requirements: 6.5_
  
  - [x] 7.10 Write property test for minimum length validation in `backend/src/error/helpers_test.rs`
    - **Property 11: Minimum Length Validation Correctness**
    - **Validates: Requirements 6.5**
  
  - [x] 7.11 Implement `validate_array_not_empty` helper in `backend/src/error/helpers.rs`
    - Add non-empty array validation checking `!arr.is_empty()`
    - Return `Ok(())` for non-empty arrays, `Err(ApiError::BadRequestI18n)` with bilingual messages for empty
    - _Requirements: 6.6_
  
  - [x] 7.12 Write property test for array non-empty validation in `backend/src/error/helpers_test.rs`
    - **Property 12: Array Non-Empty Validation Correctness**
    - **Validates: Requirements 6.6**
  
  - [x] 7.13 Implement `validate_unique_items` helper in `backend/src/error/helpers.rs`
    - Add array uniqueness validation using `HashSet` for duplicate detection
    - Return `Ok(())` for unique items, `Err(ApiError::BadRequestI18n)` with bilingual messages for duplicates
    - _Requirements: 6.7_
  
  - [x] 7.14 Write property test for array uniqueness validation in `backend/src/error/helpers_test.rs`
    - **Property 13: Array Uniqueness Validation Correctness**
    - **Validates: Requirements 6.7**
  
  - [x] 7.15 Write property test for validation helper language consistency in `backend/src/error/helpers_test.rs`
    - **Property 6: Validation Helper Language Consistency**
    - **Validates: Requirements 2.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7**

- [x] 8. Checkpoint - Ensure all tests pass
  - Run `cargo test` in `backend/` directory to verify all validation helper tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Create migration guide documentation
  - [x] 9.1 Create `backend/src/error/MIGRATION_GUIDE.md` with overview and quick reference
    - Document migration purpose, scope, and quick reference table mapping old patterns to new helpers
    - _Requirements: 7.1, 7.2_
  
  - [x] 9.2 Add error type migration examples to MIGRATION_GUIDE.md
    - Provide before/after code examples for BadRequest, Conflict, Forbidden, NotImplemented migrations
    - Show how to replace `ApiError::BadRequest(String)` with `bad_request_i18n()` or specific helpers
    - _Requirements: 7.2_
  
  - [x] 9.3 Add validation helper usage examples to MIGRATION_GUIDE.md
    - Document usage patterns for all new validation helpers with code examples
    - _Requirements: 7.2_
  
  - [x] 9.4 Add dynamic message handling guide to MIGRATION_GUIDE.md
    - Explain how to handle messages with variable interpolation using `format!()` macro
    - Show examples of constructing bilingual messages with dynamic values
    - _Requirements: 7.6_
  
  - [x] 9.5 Add testing guidelines to MIGRATION_GUIDE.md
    - Document how to test bilingual errors using `REQUEST_LOCALE.scope()`
    - Provide test template for verifying both English and Chinese messages
    - _Requirements: 7.5_
  
  - [x] 9.6 Add module checklist and progress tracker to MIGRATION_GUIDE.md
    - List all backend modules that need migration: auth/, assets/, billing/, harness/, jobs/, llm/, metering/, middleware/, narrative/, production/, projects/, publish/, scope/, scripting/, search/, settings/, short_video/, state/, vendor/, workspaces/
    - Provide markdown checklist template for tracking progress
    - _Requirements: 7.3, 7.4_

- [x] 10. Migrate settings module
  - [x] 10.1 Identify and migrate all error call sites in `backend/src/settings/`
    - Search for `ApiError::BadRequest`, `ApiError::Conflict`, `ApiError::Forbidden`, `ApiError::NotImplemented` patterns
    - Replace with appropriate bilingual helpers (`bad_request_i18n`, `conflict_i18n`, `forbidden_i18n`, `not_implemented_i18n` or specific helpers)
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 10.2 Add/update tests for settings module in `backend/src/settings/` test files
    - Verify both English and Chinese error messages using `REQUEST_LOCALE.scope()`
    - _Requirements: 9.1_
  
  - [x] 10.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - Mark settings module as complete with checkmark
    - _Requirements: 10.5_

- [x] 11. Migrate workspaces module
  - [x] 11.1 Identify and migrate all error call sites in `backend/src/workspaces/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 11.2 Add/update tests for workspaces module in `backend/src/workspaces/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 11.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 12. Migrate projects module
  - [x] 12.1 Identify and migrate all error call sites in `backend/src/projects/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 12.2 Add/update tests for projects module in `backend/src/projects/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 12.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 13. Checkpoint - Ensure all tests pass
  - Run `cargo test` in `backend/` directory to verify all module migrations pass tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Migrate assets module
  - [x] 14.1 Identify and migrate all error call sites in `backend/src/assets/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 14.2 Add/update tests for assets module in `backend/src/assets/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 14.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 15. Migrate production module
  - [x] 15.1 Identify and migrate all error call sites in `backend/src/production/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 15.2 Add/update tests for production module in `backend/src/production/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 15.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 16. Migrate publish module
  - [x] 16.1 Identify and migrate all error call sites in `backend/src/publish/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 16.2 Add/update tests for publish module in `backend/src/publish/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 16.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 17. Migrate jobs module
  - [x] 17.1 Identify and migrate all error call sites in `backend/src/jobs/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 17.2 Add/update tests for jobs module in `backend/src/jobs/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 17.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 18. Checkpoint - Ensure all tests pass
  - Run `cargo test` in `backend/` directory to verify all module migrations pass tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 19. Migrate harness module
  - [x] 19.1 Identify and migrate all error call sites in `backend/src/harness/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 19.2 Add/update tests for harness module in `backend/src/harness/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 19.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 20. Migrate billing module
  - [x] 20.1 Identify and migrate all error call sites in `backend/src/billing/`
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 20.2 Add/update tests for billing module in `backend/src/billing/` test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 20.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - _Requirements: 10.5_

- [x] 21. Migrate remaining modules
  - [x] 21.1 Identify and migrate all error call sites in remaining modules
    - Cover auth/, llm/, narrative/, scripting/, search/, short_video/, vendor/, metering/, middleware/, scope/, state/
    - Replace error constructors with bilingual helpers
    - _Requirements: 10.1, 10.2, 10.3, 10.4_
  
  - [x] 21.2 Add/update tests for remaining modules in respective test files
    - Verify both languages
    - _Requirements: 9.1_
  
  - [x] 21.3 Update migration progress tracker in MIGRATION_GUIDE.md
    - Mark all remaining modules as complete
    - _Requirements: 10.5_

- [x] 22. Final verification and cleanup
  - [x] 22.1 Run full test suite with `cargo test` in `backend/` directory
    - Verify all unit tests, property tests, and integration tests pass
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  
  - [x] 22.2 Verify migration completeness
    - Run `grep -r "ApiError::BadRequest(" backend/src/` to find any unmigrated BadRequest patterns
    - Run `grep -r "ApiError::Conflict(" backend/src/` to find any unmigrated Conflict patterns
    - Run `grep -r "ApiError::Forbidden(" backend/src/` to find any unmigrated Forbidden patterns (excluding `forbidden_i18n` calls)
    - Run `grep -r "ApiError::NotImplemented(" backend/src/` to find any unmigrated NotImplemented patterns
    - Review migration progress tracker in MIGRATION_GUIDE.md to ensure all modules are checked off
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [x] 22.3 Update module documentation
    - Update doc comments in `backend/src/error/mod.rs` to document new bilingual variants
    - Update doc comments in `backend/src/error/helpers.rs` to document all new helper functions
    - Add module-level documentation explaining bilingual error handling patterns
    - _Requirements: 8.3_
  
  - [x] 22.4 Write property test for Accept-Language parsing in `backend/src/error/mod_test.rs`
    - **Property 14: Accept-Language Quality Value Parsing**
    - **Validates: Requirements 1.3, 9.2**
    - Note: Existing tests already cover language selection
  
  - [x] 22.5 Write property tests for language selection consistency in `backend/src/error/mod_test.rs`
    - **Property 1: Language Selection Consistency**
    - **Property 2: English Default Fallback**
    - **Validates: Requirements 1.1, 1.2, 1.3**
    - Note: Existing tests already cover these properties

- [x] 23. Final checkpoint - Ensure all tests pass
  - Run `cargo test` in `backend/` directory for final verification
  - Run `cargo clippy` in `backend/` directory to check for any warnings
  - Run `cargo fmt --check` in `backend/` directory to verify formatting
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation through `cargo test` in `backend/` directory
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Migration is done module-by-module to minimize risk
- Backward compatibility is maintained throughout
- All file paths are specified relative to workspace root for clarity
- Test files follow Rust convention: `mod_test.rs` or inline `#[cfg(test)]` modules

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3", "5.1", "5.2", "5.3"] },
    { "id": 2, "tasks": ["2.4", "3.5", "3.6", "4.4", "5.4"] },
    { "id": 3, "tasks": ["7.1", "7.3", "7.5", "7.7", "7.9", "7.11", "7.13"] },
    { "id": 4, "tasks": ["7.2", "7.4", "7.6", "7.8", "7.10", "7.12", "7.14", "7.15"] },
    { "id": 5, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "9.6"] },
    { "id": 6, "tasks": ["10.1", "11.1", "12.1"] },
    { "id": 7, "tasks": ["10.2", "10.3", "11.2", "11.3", "12.2", "12.3"] },
    { "id": 8, "tasks": ["14.1", "15.1", "16.1"] },
    { "id": 9, "tasks": ["14.2", "14.3", "15.2", "15.3", "16.2", "16.3"] },
    { "id": 10, "tasks": ["17.1", "19.1", "20.1"] },
    { "id": 11, "tasks": ["17.2", "17.3", "19.2", "19.3", "20.2", "20.3"] },
    { "id": 12, "tasks": ["21.1"] },
    { "id": 13, "tasks": ["21.2", "21.3"] },
    { "id": 14, "tasks": ["22.1", "22.2", "22.3", "22.4", "22.5"] }
  ]
}
```
