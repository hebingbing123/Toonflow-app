# Short Video Configuration Validation

## Overview

This document describes the validation logic implemented for the short video configuration fields in the project API endpoints (Task B2).

## Validated Fields

### 1. `mode` (动漫/真人)
- **Valid values**: `"动漫"`, `"真人"`
- **Validation**: Enum validation
- **Error message**: Includes valid options in Chinese

### 2. `target_market`
- **Valid values**: `"domestic"`, `"overseas"`, `"both"`
- **Validation**: Enum validation
- **Error message**: Lists all valid options

### 3. `duration_strategy`
- **Valid values**: `"short"`, `"medium"`, `"long"`
- **Validation**: Enum validation
- **Error message**: Lists all valid options

### 4. `target_platforms`
- **Type**: Array of strings
- **Validation**: 
  - Non-empty array check
  - Each platform identifier must be in the valid platform list
- **Valid platform identifiers**:
  - **Domestic**: `douyin`, `bilibili`, `xiaohongshu`, `weixin_channels`, `kuaishou`
  - **Overseas**: `tiktok`, `youtube_shorts`, `instagram_reels`, `facebook_reels`
- **Error messages**: 
  - Empty array: "target_platforms must not be empty"
  - Invalid identifier: Lists the invalid identifier and all valid options

## Implementation

### Module Structure

```
backend/src/projects/routes/
├── validation.rs                      # Core validation functions
├── validation_integration_test.rs     # Integration tests
├── handlers/
│   ├── create_list/create.rs         # CREATE endpoint with validation
│   └── detail/patch.rs                # PATCH endpoint with validation
```

### Validation Functions

All validation functions are in `validation.rs`:

```rust
pub(crate) fn validate_mode(mode: &str) -> Result<(), ApiError>
pub(crate) fn validate_target_market(market: &str) -> Result<(), ApiError>
pub(crate) fn validate_duration_strategy(strategy: &str) -> Result<(), ApiError>
pub(crate) fn validate_target_platforms(platforms: &[String]) -> Result<(), ApiError>
```

### API Endpoints

#### POST /api/v1/projects
- Validates all short video configuration fields if provided
- Validation occurs before database insertion
- Returns 400 Bad Request with descriptive error message on validation failure

#### PATCH /api/v1/projects/{id}
- Validates fields only when they are being updated (not `null` or absent)
- Validation occurs after parsing but before database update
- Returns 400 Bad Request with descriptive error message on validation failure

#### GET /api/v1/projects/{id}
- No validation needed (read-only)
- Returns data as stored in database

## Error Responses

All validation errors return HTTP 400 Bad Request with a JSON error body:

```json
{
  "error": "mode must be '动漫' or '真人', got 'anime'"
}
```

```json
{
  "error": "target_platforms must not be empty"
}
```

```json
{
  "error": "invalid platform identifier 'invalid_platform', must be one of: douyin, bilibili, xiaohongshu, weixin_channels, kuaishou, tiktok, youtube_shorts, instagram_reels, facebook_reels"
}
```

## Testing

### Unit Tests
- Located in `validation.rs` (7 tests)
- Test each validation function with valid and invalid inputs
- Verify error messages are actionable

### Integration Tests
- Located in `validation_integration_test.rs` (5 tests)
- Test validation in API context
- Verify error messages contain helpful information
- Test comprehensive platform validation scenarios

### Running Tests

```bash
# Run validation tests only
cargo test projects::routes::validation

# Run all project route tests
cargo test projects::routes

# Run full refactor check (includes all tests)
bash scripts/refactor-check.sh
```

## Design Decisions

1. **Validation Location**: Validation occurs in the handler functions after parsing but before database operations. This ensures:
   - Early failure with clear error messages
   - No invalid data reaches the database
   - Consistent validation across CREATE and PATCH endpoints

2. **Error Messages**: All error messages include:
   - What field failed validation
   - What value was provided
   - What values are valid
   - This makes errors actionable for API consumers

3. **Platform List**: The valid platform list is hardcoded in the validation module to match the requirements (需求 7, 12):
   - 5 domestic platforms
   - 4 overseas platforms
   - This list can be extended in the future without changing the validation logic

4. **Empty Array Handling**: `target_platforms` must not be empty when provided. This ensures:
   - Projects always have at least one target platform when configured
   - Aligns with the requirement that platforms are a key part of the short video configuration

5. **Null vs Absent**: The PATCH endpoint distinguishes between:
   - `null`: Clear the field (set to NULL in database)
   - Absent: Don't change the field
   - Validation only applies when setting a non-null value

## Future Enhancements

1. **Dynamic Platform Registry**: Move platform list to database or configuration file for easier updates
2. **Platform Capability Validation**: Validate that selected platforms support the configured video ratio, duration, etc.
3. **Cross-Field Validation**: Validate combinations of fields (e.g., certain platforms may require specific markets)
4. **Localized Error Messages**: Support multiple languages for error messages based on Accept-Language header

## Related Files

- Database schema: `supabase/migrations/20260503120000_app_project_short_video_config.sql`
- Type definitions: `backend/src/projects/routes/types.rs`
- Requirements: `.kiro/specs/short-video-space/requirements.md` (需求 2)
- Design: `.kiro/specs/short-video-space/design.md`
- Tasks: `.kiro/specs/short-video-space/tasks.md` (Task B2)
