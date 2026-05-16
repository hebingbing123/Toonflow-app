# L.1 Nine-Platform Matrix Acceptance Test Coverage

## Overview

This document describes the comprehensive acceptance test suite for the nine-platform publish workflow. The tests validate real capability detection, delivery modes, and platform-specific validation rules without using mocks.

**Test File**: `backend/src/publish/nine_platform_acceptance_tests.rs`

## Test Execution

```bash
cd backend
cargo test --package toonflow-server --lib publish::nine_platform_acceptance_tests -- --nocapture
```

## Platform Coverage

### Domestic Platforms (5)
1. **douyin** (抖音)
2. **bilibili** (哔哩哔哩)
3. **xiaohongshu** (小红书)
4. **weixin_channels** (视频号)
5. **kuaishou** (快手)

### Overseas Platforms (4)
6. **tiktok** (TikTok)
7. **youtube_shorts** (YouTube Shorts)
8. **instagram_reels** (Instagram Reels)
9. **facebook_reels** (Facebook Reels)

## Delivery Modes

Each platform supports three delivery modes:

1. **sandbox** - Semi-automatic mode for testing (automation_mode: `semi_auto`)
2. **live** - Full automatic mode with real API integration (automation_mode: `full_auto`)
3. **manual_bridge** - Manual-assisted mode with human intervention (automation_mode: `manual_assisted`)

## Test Coverage Matrix

The test suite validates **27 combinations** (9 platforms × 3 delivery modes):

| Platform | sandbox | live | manual_bridge |
|----------|---------|------|---------------|
| douyin | ✓ | ✓ | ✓ |
| bilibili | ✓ | ✓ | ✓ |
| xiaohongshu | ✓ | ✓ | ✓ |
| weixin_channels | ✓ | ✓ | ✓ |
| kuaishou | ✓ | ✓ | ✓ |
| tiktok | ✓ | ✓ | ✓ |
| youtube_shorts | ✓ | ✓ | ✓ |
| instagram_reels | ✓ | ✓ | ✓ |
| facebook_reels | ✓ | ✓ | ✓ |

## Test Categories

### 1. Platform Registry Tests (6 tests)
- `test_nine_platforms_registered` - Validates exactly 9 platforms exist
- `test_domestic_platforms_count` - Validates 5 domestic platforms
- `test_overseas_platforms_count` - Validates 4 overseas platforms
- `test_platform_capability_lookup` - Tests platform lookup by ID
- `test_platform_capability_matrix_api` - Validates API response format
- `test_platform_specific_constraints` - Validates platform-specific limits

### 2. Platform-Specific Validation Tests (2 tests)
- `test_domestic_platforms_require_cover` - Validates cover requirement for domestic platforms
- `test_overseas_platforms_cover_optional` - Validates cover is optional for overseas platforms

### 3. Adapter Routing Tests (2 tests)
- `test_all_platforms_have_adapters` - Validates all 9 platforms have working adapters
- `test_unsupported_platform_fails` - Validates error handling for unknown platforms

### 4. Delivery Mode Tests (3 tests)
- `test_semi_auto_maps_to_sandbox` - Validates semi_auto → sandbox mapping
- `test_full_auto_maps_to_live` - Validates full_auto → live mapping
- `test_manual_assisted_maps_to_manual_bridge` - Validates manual_assisted → manual_bridge mapping

### 5. Evidence and Audit Trail Tests (2 tests)
- `test_evidence_generation_for_all_modes` - Validates evidence structure for each mode
- `test_receipt_contains_required_fields` - Validates receipt completeness

### 6. Metrics Fetching Tests (4 tests)
- `test_sandbox_metrics_fetch_for_all_platforms` - Validates sandbox metrics for all platforms
- `test_live_metrics_fetch_capability` - Tests live metrics fetch capability
- `test_manual_bridge_metrics_fetch_capability` - Tests manual bridge metrics fetch
- `test_metrics_fetch_requires_valid_delivery_mode` - Validates delivery mode validation
- `test_metrics_fetch_requires_non_empty_video_id` - Validates video ID validation

### 7. Automation Mode Validation Tests (2 tests)
- `test_valid_automation_modes` - Validates accepted automation modes
- `test_invalid_automation_modes` - Validates rejection of invalid modes

### 8. Draft-to-Platform Mapping Tests (2 tests)
- `test_draft_maps_to_all_platforms` - Validates single draft can publish to all platforms
- `test_multiple_targets_per_draft` - Validates multi-platform publishing

### 9. Error Handling Tests (2 tests)
- `test_error_handling_for_unsupported_platform` - Validates error messages
- `test_delivery_mode_consistency` - Validates mode mapping consistency

### 10. Coverage Matrix Summary Test (1 test)
- `test_nine_platform_matrix_coverage` - Comprehensive validation of all 27 combinations

## Key Validations

### Platform Capability Detection
- ✓ All 9 platforms registered in platform_registry
- ✓ Each platform has unique ID
- ✓ Platform lookup by ID works correctly
- ✓ Platform specs contain required fields (title_max_chars, tags_max, etc.)

### Delivery Mode Mapping
- ✓ `semi_auto` → `sandbox` (sandbox_closure receipt)
- ✓ `full_auto` → `live` (live_api receipt)
- ✓ `manual_assisted` → `manual_bridge` (manual_bridge receipt)

### Evidence Generation
- ✓ Sandbox mode: generates `request_id`
- ✓ Live mode: generates `request_id` + `callback_id`
- ✓ Manual bridge mode: generates `manual_step_id`

### Platform-Specific Rules
- ✓ Domestic platforms require cover images
- ✓ Overseas platforms don't require cover images
- ✓ Each platform has appropriate character limits
- ✓ Each platform has appropriate tag limits

### Metrics Fetching
- ✓ Sandbox metrics work for all platforms
- ✓ Live metrics handle availability correctly
- ✓ Manual bridge metrics handle readiness correctly
- ✓ Invalid delivery modes are rejected
- ✓ Empty video IDs are rejected

### Job Creation and Queueing
- ✓ Jobs can be created for all platforms
- ✓ Draft-to-platform mapping works correctly
- ✓ Multiple targets per draft supported
- ✓ Receipt contains all required fields

### Error Handling
- ✓ Unsupported platforms return proper errors
- ✓ Invalid automation modes are rejected
- ✓ Error messages are descriptive

## Real Capability Checks (Not Mocks)

The test suite uses **real capability detection** from the production code:

1. **Platform Registry** (`platform_registry.rs`): Real platform definitions with actual constraints
2. **Adapter Routing** (`adapters.rs`): Real adapter logic for all 9 platforms
3. **Validation** (`validation.rs`): Real validation rules
4. **Metrics Fetching** (`adapters.rs`): Real metrics fetch logic (with simulated API responses for testing)

## Test Results

```
running 27 tests
test publish::nine_platform_acceptance_tests::tests::test_all_platforms_have_adapters ... ok
test publish::nine_platform_acceptance_tests::tests::test_delivery_mode_consistency ... ok
test publish::nine_platform_acceptance_tests::tests::test_domestic_platforms_count ... ok
test publish::nine_platform_acceptance_tests::tests::test_domestic_platforms_require_cover ... ok
test publish::nine_platform_acceptance_tests::tests::test_draft_maps_to_all_platforms ... ok
test publish::nine_platform_acceptance_tests::tests::test_error_handling_for_unsupported_platform ... ok
test publish::nine_platform_acceptance_tests::tests::test_evidence_generation_for_all_modes ... ok
test publish::nine_platform_acceptance_tests::tests::test_full_auto_maps_to_live ... ok
test publish::nine_platform_acceptance_tests::tests::test_invalid_automation_modes ... ok
test publish::nine_platform_acceptance_tests::tests::test_live_metrics_fetch_capability ... ok
test publish::nine_platform_acceptance_tests::tests::test_manual_assisted_maps_to_manual_bridge ... ok
test publish::nine_platform_acceptance_tests::tests::test_manual_bridge_metrics_fetch_capability ... ok
test publish::nine_platform_acceptance_tests::tests::test_metrics_fetch_requires_non_empty_video_id ... ok
test publish::nine_platform_acceptance_tests::tests::test_metrics_fetch_requires_valid_delivery_mode ... ok
test publish::nine_platform_acceptance_tests::tests::test_multiple_targets_per_draft ... ok
test publish::nine_platform_acceptance_tests::tests::test_nine_platform_matrix_coverage ... ok
test publish::nine_platform_acceptance_tests::tests::test_nine_platforms_registered ... ok
test publish::nine_platform_acceptance_tests::tests::test_overseas_platforms_count ... ok
test publish::nine_platform_acceptance_tests::tests::test_overseas_platforms_cover_optional ... ok
test publish::nine_platform_acceptance_tests::tests::test_platform_capability_lookup ... ok
test publish::nine_platform_acceptance_tests::tests::test_platform_capability_matrix_api ... ok
test publish::nine_platform_acceptance_tests::tests::test_platform_specific_constraints ... ok
test publish::nine_platform_acceptance_tests::tests::test_receipt_contains_required_fields ... ok
test publish::nine_platform_acceptance_tests::tests::test_sandbox_metrics_fetch_for_all_platforms ... ok
test publish::nine_platform_acceptance_tests::tests::test_semi_auto_maps_to_sandbox ... ok
test publish::nine_platform_acceptance_tests::tests::test_unsupported_platform_fails ... ok
test publish::nine_platform_acceptance_tests::tests::test_valid_automation_modes ... ok

test result: ok. 27 passed; 0 failed; 0 ignored; 0 measured
```

## Coverage Summary

- **Total Tests**: 27
- **Platform Coverage**: 9 platforms (5 domestic + 4 overseas)
- **Delivery Mode Coverage**: 3 modes (sandbox, live, manual_bridge)
- **Combination Coverage**: 27 (9 × 3)
- **Pass Rate**: 100%

## Integration Points

The acceptance tests validate integration with:

1. **Platform Registry** (`platform_registry.rs`) - Platform definitions and capabilities
2. **Adapters** (`adapters.rs`) - Platform-specific adapter routing
3. **Validation** (`validation.rs`) - Input validation rules
4. **Types** (`types.rs`) - Data structures for drafts, jobs, targets
5. **State Machine** (`state_machine.rs`) - Job status transitions (indirectly)

## Future Enhancements

Potential areas for expansion:

1. **Database Integration Tests**: Test with real database for job creation/queueing
2. **Worker Integration Tests**: Test worker claiming and processing jobs
3. **Callback Handling Tests**: Test platform callback processing
4. **Performance Tests**: Test high-volume multi-platform publishing
5. **Retry Logic Tests**: Test retry behavior for failed jobs
6. **Concurrency Tests**: Test concurrent publishing to same platform

## Maintenance

When adding a new platform:

1. Add platform definition to `platform_registry.rs`
2. Add adapter implementation to `adapters.rs`
3. Run the acceptance test suite - it will automatically validate the new platform
4. Update this documentation with the new platform count

The test suite is designed to automatically detect and validate new platforms without requiring test modifications.
