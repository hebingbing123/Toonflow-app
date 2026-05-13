//! Unit tests for error helper functions.
//!
//! This module contains comprehensive unit tests for all error helper functions,
//! with a focus on Conflict and Forbidden error helpers. Tests verify both English
//! and Chinese message generation, as well as proper response structure.

use super::helpers::*;
use super::locale::{ApiLocale, REQUEST_LOCALE};
use super::ApiError;
use axum::body::to_bytes;
use axum::response::IntoResponse;
use proptest::prelude::*;

// ============================================================================
// Conflict Helper Tests
// ============================================================================

#[test]
fn conflict_i18n_creates_correct_variant() {
    let err = conflict_i18n("resource already exists", "资源已存在");
    match err {
        ApiError::ConflictI18n { en, zh } => {
            assert_eq!(en, "resource already exists");
            assert_eq!(zh, "资源已存在");
        }
        _ => panic!("expected ConflictI18n variant"),
    }
}

#[test]
fn conflict_i18n_with_various_messages() {
    let test_cases = vec![
        ("resource locked", "资源已锁定"),
        ("operation in progress", "操作进行中"),
        ("state conflict", "状态冲突"),
    ];

    for (en_msg, zh_msg) in test_cases {
        let err = conflict_i18n(en_msg, zh_msg);
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, en_msg);
                assert_eq!(zh, zh_msg);
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }
}

#[tokio::test]
async fn conflict_i18n_response_en() {
    let err = conflict_i18n("resource already exists", "资源已存在");
    let resp = err.into_response();

    let bytes = to_bytes(resp.into_body(), 16 * 1024)
        .await
        .expect("body bytes");
    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

    assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
    assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
    assert_eq!(
        json.get("message").and_then(|v| v.as_str()),
        Some("resource already exists")
    );
}

#[tokio::test]
async fn conflict_i18n_response_zh() {
    let resp = REQUEST_LOCALE
        .scope(ApiLocale::Zh, async {
            let err = conflict_i18n("resource already exists", "资源已存在");
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
        Some("资源已存在")
    );
}

#[test]
fn version_conflict_i18n_creates_correct_messages() {
    let err = version_conflict_i18n("Timeline");
    match err {
        ApiError::ConflictI18n { en, zh } => {
            assert_eq!(en, "Timeline has been modified by another user");
            assert_eq!(zh, "Timeline 已被其他用户修改");
        }
        _ => panic!("expected ConflictI18n variant"),
    }
}

#[test]
fn version_conflict_i18n_with_various_resources() {
    let test_cases = vec![
        (
            "Timeline",
            "Timeline has been modified by another user",
            "Timeline 已被其他用户修改",
        ),
        (
            "Project",
            "Project has been modified by another user",
            "Project 已被其他用户修改",
        ),
        (
            "Workspace",
            "Workspace has been modified by another user",
            "Workspace 已被其他用户修改",
        ),
        (
            "Asset",
            "Asset has been modified by another user",
            "Asset 已被其他用户修改",
        ),
    ];

    for (resource, expected_en, expected_zh) in test_cases {
        let err = version_conflict_i18n(resource);
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, expected_en);
                assert_eq!(zh, expected_zh);
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }
}

#[tokio::test]
async fn version_conflict_i18n_response_en() {
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
    let resp = REQUEST_LOCALE
        .scope(ApiLocale::Zh, async {
            let err = version_conflict_i18n("Project");
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
        Some("Project 已被其他用户修改")
    );
}

#[test]
fn duplicate_resource_i18n_creates_correct_messages() {
    let err = duplicate_resource_i18n("workspace", "my-workspace");
    match err {
        ApiError::ConflictI18n { en, zh } => {
            assert_eq!(en, "workspace 'my-workspace' already exists");
            assert_eq!(zh, "workspace 'my-workspace' 已存在");
        }
        _ => panic!("expected ConflictI18n variant"),
    }
}

#[test]
fn duplicate_resource_i18n_with_various_resource_types() {
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
        (
            "asset",
            "video-001",
            "asset 'video-001' already exists",
            "asset 'video-001' 已存在",
        ),
    ];

    for (resource_type, identifier, expected_en, expected_zh) in test_cases {
        let err = duplicate_resource_i18n(resource_type, identifier);
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, expected_en);
                assert_eq!(zh, expected_zh);
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }
}

#[tokio::test]
async fn duplicate_resource_i18n_response_en() {
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
fn concurrent_modification_i18n_creates_correct_messages() {
    let err = concurrent_modification_i18n("Timeline");
    match err {
        ApiError::ConflictI18n { en, zh } => {
            assert_eq!(en, "Timeline is being modified by another operation");
            assert_eq!(zh, "Timeline 正在被其他操作修改");
        }
        _ => panic!("expected ConflictI18n variant"),
    }
}

#[test]
fn concurrent_modification_i18n_with_various_resources() {
    let test_cases = vec![
        (
            "Timeline",
            "Timeline is being modified by another operation",
            "Timeline 正在被其他操作修改",
        ),
        (
            "Project",
            "Project is being modified by another operation",
            "Project 正在被其他操作修改",
        ),
        (
            "Workspace",
            "Workspace is being modified by another operation",
            "Workspace 正在被其他操作修改",
        ),
        (
            "Asset",
            "Asset is being modified by another operation",
            "Asset 正在被其他操作修改",
        ),
    ];

    for (resource, expected_en, expected_zh) in test_cases {
        let err = concurrent_modification_i18n(resource);
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert_eq!(en, expected_en);
                assert_eq!(zh, expected_zh);
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }
}

#[tokio::test]
async fn concurrent_modification_i18n_response_en() {
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

// ============================================================================
// Forbidden Helper Tests
// ============================================================================

#[test]
fn insufficient_permissions_i18n_creates_correct_variant() {
    let err = insufficient_permissions_i18n("delete workspace");
    match err {
        ApiError::ForbiddenI18n { en, zh } => {
            assert_eq!(en, "Insufficient permissions to delete workspace");
            assert_eq!(zh, "权限不足，无法delete workspace");
        }
        _ => panic!("expected ForbiddenI18n variant"),
    }
}

#[test]
fn insufficient_permissions_i18n_with_various_actions() {
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
            "invite users",
            "Insufficient permissions to invite users",
            "权限不足，无法invite users",
        ),
    ];

    for (action, expected_en, expected_zh) in test_cases {
        let err = insufficient_permissions_i18n(action);
        match err {
            ApiError::ForbiddenI18n { en, zh } => {
                assert_eq!(en, expected_en);
                assert_eq!(zh, expected_zh);
            }
            _ => panic!("expected ForbiddenI18n variant"),
        }
    }
}

#[tokio::test]
async fn insufficient_permissions_i18n_response_en() {
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
fn feature_not_enabled_i18n_creates_correct_variant() {
    let err = feature_not_enabled_i18n("billing");
    match err {
        ApiError::ForbiddenI18n { en, zh } => {
            assert_eq!(en, "Feature 'billing' is not enabled");
            assert_eq!(zh, "功能 'billing' 未启用");
        }
        _ => panic!("expected ForbiddenI18n variant"),
    }
}

#[test]
fn feature_not_enabled_i18n_with_various_features() {
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
            "ai_generation",
            "Feature 'ai_generation' is not enabled",
            "功能 'ai_generation' 未启用",
        ),
        (
            "team_collaboration",
            "Feature 'team_collaboration' is not enabled",
            "功能 'team_collaboration' 未启用",
        ),
    ];

    for (feature, expected_en, expected_zh) in test_cases {
        let err = feature_not_enabled_i18n(feature);
        match err {
            ApiError::ForbiddenI18n { en, zh } => {
                assert_eq!(en, expected_en);
                assert_eq!(zh, expected_zh);
            }
            _ => panic!("expected ForbiddenI18n variant"),
        }
    }
}

#[tokio::test]
async fn feature_not_enabled_i18n_response_en() {
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
fn workspace_access_denied_i18n_creates_correct_variant() {
    let err = workspace_access_denied_i18n();
    match err {
        ApiError::ForbiddenI18n { en, zh } => {
            assert_eq!(en, "Access to workspace denied");
            assert_eq!(zh, "工作区访问被拒绝");
        }
        _ => panic!("expected ForbiddenI18n variant"),
    }
}

#[tokio::test]
async fn workspace_access_denied_i18n_response_en() {
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

#[tokio::test]
async fn forbidden_helpers_preserve_response_structure() {
    // Test that all forbidden helpers produce responses with the correct structure
    let helpers = vec![
        insufficient_permissions_i18n("test action"),
        feature_not_enabled_i18n("test_feature"),
        workspace_access_denied_i18n(),
    ];

    for err in helpers {
        let resp = err.into_response();
        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        // Verify response structure
        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(403));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("forbidden"));
        assert!(json.get("message").is_some());
        assert!(json.get("message").and_then(|v| v.as_str()).is_some());
    }
}

#[tokio::test]
async fn forbidden_helpers_respect_locale_switching() {
    // Test that helpers correctly switch between locales
    let err_en = REQUEST_LOCALE
        .scope(ApiLocale::En, async {
            let err = feature_not_enabled_i18n("billing");
            let resp = err.into_response();
            let bytes = to_bytes(resp.into_body(), 16 * 1024)
                .await
                .expect("body bytes");
            let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
            json.get("message")
                .and_then(|v| v.as_str())
                .expect("message")
                .to_string()
        })
        .await;

    let err_zh = REQUEST_LOCALE
        .scope(ApiLocale::Zh, async {
            let err = feature_not_enabled_i18n("billing");
            let resp = err.into_response();
            let bytes = to_bytes(resp.into_body(), 16 * 1024)
                .await
                .expect("body bytes");
            let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
            json.get("message")
                .and_then(|v| v.as_str())
                .expect("message")
                .to_string()
        })
        .await;

    assert_eq!(err_en, "Feature 'billing' is not enabled");
    assert_eq!(err_zh, "功能 'billing' 未启用");
    assert_ne!(err_en, err_zh);
}

// ============================================================================
// Edge Cases and Integration Tests
// ============================================================================

#[test]
fn conflict_helpers_with_empty_strings() {
    // Test that helpers handle empty strings gracefully
    let err = duplicate_resource_i18n("", "");
    match err {
        ApiError::ConflictI18n { en, zh } => {
            assert_eq!(en, " '' already exists");
            assert_eq!(zh, " '' 已存在");
        }
        _ => panic!("expected ConflictI18n variant"),
    }
}

#[test]
fn conflict_helpers_with_special_characters() {
    let test_cases = vec![
        ("user", "test@example.com"),
        ("project", "my-project-123"),
        ("workspace", "workspace_with_underscores"),
        ("asset", "file.mp4"),
    ];

    for (resource_type, identifier) in test_cases {
        let err = duplicate_resource_i18n(resource_type, identifier);
        match err {
            ApiError::ConflictI18n { en, zh } => {
                assert!(en.contains(resource_type));
                assert!(en.contains(identifier));
                assert!(zh.contains(resource_type));
                assert!(zh.contains(identifier));
            }
            _ => panic!("expected ConflictI18n variant"),
        }
    }
}

#[tokio::test]
async fn conflict_helpers_preserve_response_structure() {
    // Test that all conflict helpers produce responses with the correct structure
    let helpers = vec![
        conflict_i18n("test", "测试"),
        version_conflict_i18n("Resource"),
        duplicate_resource_i18n("type", "id"),
        concurrent_modification_i18n("Resource"),
    ];

    for err in helpers {
        let resp = err.into_response();
        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        // Verify response structure
        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(409));
        assert_eq!(json.get("code").and_then(|v| v.as_str()), Some("conflict"));
        assert!(json.get("message").is_some());
        assert!(json.get("message").and_then(|v| v.as_str()).is_some());
    }
}

#[tokio::test]
async fn conflict_helpers_respect_locale_switching() {
    // Test that helpers correctly switch between locales
    let err_en = REQUEST_LOCALE
        .scope(ApiLocale::En, async {
            let err = version_conflict_i18n("Timeline");
            let resp = err.into_response();
            let bytes = to_bytes(resp.into_body(), 16 * 1024)
                .await
                .expect("body bytes");
            let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
            json.get("message")
                .and_then(|v| v.as_str())
                .expect("message")
                .to_string()
        })
        .await;

    let err_zh = REQUEST_LOCALE
        .scope(ApiLocale::Zh, async {
            let err = version_conflict_i18n("Timeline");
            let resp = err.into_response();
            let bytes = to_bytes(resp.into_body(), 16 * 1024)
                .await
                .expect("body bytes");
            let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
            json.get("message")
                .and_then(|v| v.as_str())
                .expect("message")
                .to_string()
        })
        .await;

    assert_eq!(err_en, "Timeline has been modified by another user");
    assert_eq!(err_zh, "Timeline 已被其他用户修改");
    assert_ne!(err_en, err_zh);
}

// ============================================================================
// Property-Based Tests for Validation Helpers
// ============================================================================

proptest! {
    #![proptest_config(ProptestConfig::with_cases(10))]

    /// **Property 7: UUID Validation Correctness**
    /// **Validates: Requirements 6.1**
    ///
    /// For any string that is a valid UUID (format: 8-4-4-4-12 hexadecimal),
    /// validate_uuid SHALL return Ok, and for any string that is not a valid UUID,
    /// validate_uuid SHALL return an ApiError with appropriate bilingual message.
    #[test]
    fn prop_uuid_validation_correctness(
        // Generate valid UUIDs using proptest's uuid strategy
        valid_uuid in prop::string::string_regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}").unwrap(),
        // Generate invalid strings that are definitely not UUIDs
        invalid_uuid in prop::string::string_regex("[^0-9a-f-]{1,50}|[0-9a-f]{1,10}").unwrap(),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Test that valid UUIDs are accepted
        let valid_result = validate_uuid(&valid_uuid, &field_name);
        prop_assert!(valid_result.is_ok(), "valid UUID should be accepted: {}", valid_uuid);

        // Test that invalid UUIDs are rejected
        let invalid_result = validate_uuid(&invalid_uuid, &field_name);
        prop_assert!(invalid_result.is_err(), "invalid UUID should be rejected: {}", invalid_uuid);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = invalid_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(en.contains("UUID"), "English error should mention UUID");
            prop_assert!(zh.contains("UUID"), "Chinese error should mention UUID");
        } else {
            return Err(proptest::test_runner::TestCaseError::fail("expected BadRequestI18n error"));
        }
    }

    /// Test UUID validation with bilingual error messages
    #[test]
    fn prop_uuid_validation_bilingual_messages(
        invalid_uuid in "[a-zA-Z]{1,20}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_uuid(&invalid_uuid, &field_name)
                })
                .await
        });

        prop_assert!(en_result.is_err(), "invalid UUID should be rejected");
        if let Err(ApiError::BadRequestI18n { en, .. }) = en_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(en.contains("Invalid format"), "English error should contain 'Invalid format'");
            prop_assert!(en.contains("UUID"), "English error should mention UUID");
        }

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_uuid(&invalid_uuid, &field_name)
                })
                .await
        });

        prop_assert!(zh_result.is_err(), "invalid UUID should be rejected");
        if let Err(ApiError::BadRequestI18n { zh, .. }) = zh_result {
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(zh.contains("格式无效"), "Chinese error should contain '格式无效'");
            prop_assert!(zh.contains("UUID"), "Chinese error should mention UUID");
        }
    }

    /// Test that validate_uuid accepts various valid UUID formats
    #[test]
    fn prop_uuid_validation_accepts_all_valid_formats(
        // Generate random bytes for UUID v4
        bytes in prop::collection::vec(any::<u8>(), 16..=16),
    ) {
        // Create a valid UUID from random bytes
        let uuid = uuid::Uuid::from_bytes(bytes.as_slice().try_into().unwrap());
        let uuid_str = uuid.to_string();

        let result = validate_uuid(&uuid_str, "test_field");
        prop_assert!(result.is_ok(), "valid UUID should be accepted: {}", uuid_str);
    }

    /// Test that validate_uuid rejects strings with wrong format
    #[test]
    fn prop_uuid_validation_rejects_wrong_format(
        // Generate strings that look like UUIDs but have wrong segment lengths
        seg1 in "[0-9a-f]{1,7}|[0-9a-f]{9,12}",
        seg2 in "[0-9a-f]{1,3}|[0-9a-f]{5,8}",
        seg3 in "[0-9a-f]{1,3}|[0-9a-f]{5,8}",
        seg4 in "[0-9a-f]{1,3}|[0-9a-f]{5,8}",
        seg5 in "[0-9a-f]{1,11}|[0-9a-f]{13,20}",
    ) {
        let malformed_uuid = format!("{}-{}-{}-{}-{}", seg1, seg2, seg3, seg4, seg5);

        let result = validate_uuid(&malformed_uuid, "test_field");
        prop_assert!(result.is_err(), "malformed UUID should be rejected: {}", malformed_uuid);
    }

    /// **Property 8: URL Validation Correctness**
    /// **Validates: Requirements 6.2**
    ///
    /// For any string that is a valid HTTP/HTTPS URL, validate_url SHALL return Ok,
    /// and for any string that is not a valid URL, validate_url SHALL return an
    /// ApiError with appropriate bilingual message.
    #[test]
    fn prop_url_validation_correctness(
        // Generate valid HTTP/HTTPS URLs
        scheme in prop::sample::select(vec!["http", "https"]),
        domain in "[a-z0-9-]{1,20}\\.[a-z]{2,6}",
        path in prop::option::of(prop::string::string_regex("/[a-z0-9/_-]{0,30}").unwrap()),
        // Generate invalid URLs (strings that are definitely not URLs)
        invalid_url in prop::string::string_regex("[^:/]{1,20}|[a-z]{1,10}").unwrap(),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Test that valid HTTP/HTTPS URLs are accepted
        let valid_url = match path {
            Some(p) => format!("{}://{}{}", scheme, domain, p),
            None => format!("{}://{}", scheme, domain),
        };

        let valid_result = validate_url(&valid_url, &field_name);
        prop_assert!(valid_result.is_ok(), "valid URL should be accepted: {}", valid_url);

        // Test that invalid URLs are rejected
        let invalid_result = validate_url(&invalid_url, &field_name);
        prop_assert!(invalid_result.is_err(), "invalid URL should be rejected: {}", invalid_url);

        // Verify the error contains the field name and mentions HTTP/HTTPS
        if let Err(ApiError::BadRequestI18n { en, zh }) = invalid_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(en.contains("HTTP/HTTPS"), "English error should mention HTTP/HTTPS");
            prop_assert!(zh.contains("HTTP/HTTPS"), "Chinese error should mention HTTP/HTTPS");
        } else {
            return Err(proptest::test_runner::TestCaseError::fail("expected BadRequestI18n error"));
        }
    }

    /// Test URL validation with bilingual error messages
    #[test]
    fn prop_url_validation_bilingual_messages(
        invalid_url in "[a-zA-Z]{1,20}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_url(&invalid_url, &field_name)
                })
                .await
        });

        prop_assert!(en_result.is_err(), "invalid URL should be rejected");
        if let Err(ApiError::BadRequestI18n { en, .. }) = en_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(en.contains("Invalid format"), "English error should contain 'Invalid format'");
            prop_assert!(en.contains("HTTP/HTTPS"), "English error should mention HTTP/HTTPS");
        }

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_url(&invalid_url, &field_name)
                })
                .await
        });

        prop_assert!(zh_result.is_err(), "invalid URL should be rejected");
        if let Err(ApiError::BadRequestI18n { zh, .. }) = zh_result {
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(zh.contains("格式无效"), "Chinese error should contain '格式无效'");
            prop_assert!(zh.contains("HTTP/HTTPS"), "Chinese error should mention HTTP/HTTPS");
        }
    }

    /// Test that validate_url accepts various valid HTTP/HTTPS URL formats
    #[test]
    fn prop_url_validation_accepts_all_valid_formats(
        scheme in prop::sample::select(vec!["http", "https"]),
        domain in "[a-z0-9-]{1,15}\\.[a-z]{2,6}",
        port in prop::option::of(1u16..65535u16),
        path in prop::option::of(prop::string::string_regex("/[a-z0-9/_-]{0,20}").unwrap()),
        query in prop::option::of(prop::string::string_regex("\\?[a-z0-9=&_-]{1,20}").unwrap()),
    ) {
        let mut url = format!("{}://{}", scheme, domain);

        if let Some(p) = port {
            url.push_str(&format!(":{}", p));
        }

        if let Some(path_str) = path {
            url.push_str(&path_str);
        }

        if let Some(query_str) = query {
            url.push_str(&query_str);
        }

        let result = validate_url(&url, "test_field");
        prop_assert!(result.is_ok(), "valid URL should be accepted: {}", url);
    }

    /// Test that validate_url rejects non-HTTP/HTTPS schemes
    #[test]
    fn prop_url_validation_rejects_non_http_schemes(
        scheme in prop::sample::select(vec!["ftp", "file", "ws", "wss", "mailto", "data"]),
        domain in "[a-z0-9-]{1,15}\\.[a-z]{2,6}",
    ) {
        let url = format!("{}://{}", scheme, domain);

        let result = validate_url(&url, "test_field");
        prop_assert!(result.is_err(), "non-HTTP/HTTPS URL should be rejected: {}", url);

        // Verify the error mentions HTTP/HTTPS requirement
        if let Err(ApiError::BadRequestI18n { en, .. }) = result {
            prop_assert!(en.contains("HTTP/HTTPS"), "error should mention HTTP/HTTPS requirement");
        }
    }

    /// Test that validate_url rejects malformed URLs
    #[test]
    fn prop_url_validation_rejects_malformed(
        // Generate strings that are clearly not URLs
        malformed in prop::sample::select(vec![
            "not a url",
            "://example.com",
            "http//example.com",
            "example.com",
            "www.example.com",
            "",
            " ",
            "just text",
            "no-scheme.com",
        ]),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let result = validate_url(malformed, &field_name);
        prop_assert!(result.is_err(), "malformed URL should be rejected: {}", malformed);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
        }
    }

    /// **Property 9: Email Validation Correctness**
    /// **Validates: Requirements 6.3**
    ///
    /// For any string that matches standard email format (local@domain), validate_email
    /// SHALL return Ok, and for any string that does not match email format, validate_email
    /// SHALL return an ApiError with appropriate bilingual message.
    #[test]
    fn prop_email_validation_correctness(
        // Generate valid email addresses
        local_part in "[a-z0-9._+-]{1,20}",
        domain in "[a-z0-9-]{1,15}",
        tld in "[a-z]{2,6}",
        // Generate invalid emails (strings that are definitely not emails)
        invalid_email in prop::sample::select(vec![
            "notanemail",
            "missing@domain",
            "@nodomain.com",
            "no-at-sign.com",
            "user@",
            "@domain.com",
            "user @domain.com",
            "user@ domain.com",
            "",
            " ",
            "just text",
        ]),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Test that valid emails are accepted
        let valid_email = format!("{}@{}.{}", local_part, domain, tld);
        let valid_result = validate_email(&valid_email, &field_name);
        prop_assert!(valid_result.is_ok(), "valid email should be accepted: {}", valid_email);

        // Test that invalid emails are rejected
        let invalid_result = validate_email(invalid_email, &field_name);
        prop_assert!(invalid_result.is_err(), "invalid email should be rejected: {}", invalid_email);

        // Verify the error contains the field name and mentions email
        if let Err(ApiError::BadRequestI18n { en, zh }) = invalid_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(en.contains("email"), "English error should mention email");
            prop_assert!(zh.contains("电子邮件"), "Chinese error should mention email");
        } else {
            return Err(proptest::test_runner::TestCaseError::fail("expected BadRequestI18n error"));
        }
    }

    /// Test email validation with bilingual error messages
    #[test]
    fn prop_email_validation_bilingual_messages(
        invalid_email in prop::sample::select(vec![
            "notanemail",
            "missing-at",
            "@nodomain",
            "no-domain@",
        ]),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_email(invalid_email, &field_name)
                })
                .await
        });

        prop_assert!(en_result.is_err(), "invalid email should be rejected");
        if let Err(ApiError::BadRequestI18n { en, .. }) = en_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(en.contains("Invalid format"), "English error should contain 'Invalid format'");
            prop_assert!(en.contains("email"), "English error should mention email");
        }

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_email(invalid_email, &field_name)
                })
                .await
        });

        prop_assert!(zh_result.is_err(), "invalid email should be rejected");
        if let Err(ApiError::BadRequestI18n { zh, .. }) = zh_result {
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(zh.contains("格式无效"), "Chinese error should contain '格式无效'");
            prop_assert!(zh.contains("电子邮件"), "Chinese error should mention email");
        }
    }

    /// Test that validate_email accepts various valid email formats
    #[test]
    fn prop_email_validation_accepts_all_valid_formats(
        local_part in "[a-z0-9._+-]{1,20}",
        domain_parts in prop::collection::vec("[a-z0-9-]{1,10}", 1..=3),
        tld in "[a-z]{2,6}",
    ) {
        // Build domain with multiple parts (e.g., sub.example.com)
        let domain = domain_parts.join(".");
        let email = format!("{}@{}.{}", local_part, domain, tld);

        let result = validate_email(&email, "test_field");
        prop_assert!(result.is_ok(), "valid email should be accepted: {}", email);
    }

    /// Test that validate_email rejects emails without @ symbol
    #[test]
    fn prop_email_validation_rejects_no_at_symbol(
        text in "[a-z0-9.]{1,30}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Ensure the text doesn't accidentally contain @
        let text_without_at = text.replace('@', "");

        let result = validate_email(&text_without_at, &field_name);
        prop_assert!(result.is_err(), "email without @ should be rejected: {}", text_without_at);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
        }
    }

    /// Test that validate_email rejects emails without domain
    #[test]
    fn prop_email_validation_rejects_no_domain(
        local_part in "[a-z0-9._+-]{1,20}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let email_no_domain = format!("{}@", local_part);

        let result = validate_email(&email_no_domain, &field_name);
        prop_assert!(result.is_err(), "email without domain should be rejected: {}", email_no_domain);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
        }
    }

    /// Test that validate_email rejects emails without local part
    #[test]
    fn prop_email_validation_rejects_no_local_part(
        domain in "[a-z0-9-]{1,15}",
        tld in "[a-z]{2,6}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let email_no_local = format!("@{}.{}", domain, tld);

        let result = validate_email(&email_no_local, &field_name);
        prop_assert!(result.is_err(), "email without local part should be rejected: {}", email_no_local);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
        }
    }

    /// Test that validate_email rejects emails without TLD
    #[test]
    fn prop_email_validation_rejects_no_tld(
        local_part in "[a-z0-9._+-]{1,20}",
        domain in "[a-z0-9-]{1,15}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let email_no_tld = format!("{}@{}", local_part, domain);

        let result = validate_email(&email_no_tld, &field_name);
        prop_assert!(result.is_err(), "email without TLD should be rejected: {}", email_no_tld);

        // Verify the error contains the field name
        if let Err(ApiError::BadRequestI18n { en, zh }) = result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
        }
    }

    /// Test that validate_email rejects emails with whitespace
    #[test]
    fn prop_email_validation_rejects_whitespace(
        local_part in "[a-z0-9._+-]{1,10}",
        domain in "[a-z0-9-]{1,10}",
        tld in "[a-z]{2,6}",
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Test various whitespace positions
        let emails_with_whitespace = vec![
            format!("{} @{}.{}", local_part, domain, tld),
            format!("{}@ {}.{}", local_part, domain, tld),
            format!("{}@{} .{}", local_part, domain, tld),
            format!("{}@{}. {}", local_part, domain, tld),
        ];

        for email in emails_with_whitespace {
            let result = validate_email(&email, &field_name);
            prop_assert!(result.is_err(), "email with whitespace should be rejected: {}", email);

            // Verify the error contains the field name
            if let Err(ApiError::BadRequestI18n { en, zh }) = result {
                prop_assert!(en.contains(&field_name), "English error should contain field name");
                prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            }
        }
    }

    /// **Property 10: JSON Validation Correctness**
    /// **Validates: Requirements 6.4**
    ///
    /// For any string that is valid JSON, validate_json SHALL return Ok, and for any
    /// string that is not valid JSON, validate_json SHALL return an ApiError with
    /// appropriate bilingual message.
    #[test]
    fn prop_json_validation_correctness(
        // Generate valid JSON values
        json_type in prop::sample::select(vec!["object", "array", "string", "number", "boolean", "null"]),
        // Generate invalid JSON strings
        invalid_json in prop::sample::select(vec![
            "{unclosed",
            "[1, 2, 3",
            "{'single': 'quotes'}",
            "{key: 'no quotes'}",
            "not json at all",
            "",
            "{,}",
            "[,]",
            "undefined",
            "NaN",
        ]),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Generate valid JSON based on type
        let valid_json = match json_type {
            "object" => r#"{"key": "value", "nested": {"inner": 123}}"#.to_string(),
            "array" => r#"[1, 2, 3, "string", true, null]"#.to_string(),
            "string" => r#""valid string""#.to_string(),
            "number" => "42".to_string(),
            "boolean" => "true".to_string(),
            "null" => "null".to_string(),
            _ => "{}".to_string(),
        };

        // Test that valid JSON is accepted
        let valid_result = validate_json(&valid_json, &field_name);
        prop_assert!(valid_result.is_ok(), "valid JSON should be accepted: {}", valid_json);

        // Test that invalid JSON is rejected
        let invalid_result = validate_json(invalid_json, &field_name);
        prop_assert!(invalid_result.is_err(), "invalid JSON should be rejected: {}", invalid_json);

        // Verify the error contains the field name and mentions JSON
        if let Err(ApiError::BadRequestI18n { en, zh }) = invalid_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(en.contains("JSON"), "English error should mention JSON");
            prop_assert!(zh.contains("JSON"), "Chinese error should mention JSON");
        } else {
            return Err(proptest::test_runner::TestCaseError::fail("expected BadRequestI18n error"));
        }
    }

    /// Test JSON validation with bilingual error messages
    #[test]
    fn prop_json_validation_bilingual_messages(
        invalid_json in prop::sample::select(vec![
            "not json",
            "{unclosed",
            "[1, 2,",
            "undefined",
        ]),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_json(invalid_json, &field_name)
                })
                .await
        });

        prop_assert!(en_result.is_err(), "invalid JSON should be rejected");
        if let Err(ApiError::BadRequestI18n { en, .. }) = en_result {
            prop_assert!(en.contains(&field_name), "English error should contain field name");
            prop_assert!(en.contains("Invalid format"), "English error should contain 'Invalid format'");
            prop_assert!(en.contains("JSON"), "English error should mention JSON");
        }

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_json(invalid_json, &field_name)
                })
                .await
        });

        prop_assert!(zh_result.is_err(), "invalid JSON should be rejected");
        if let Err(ApiError::BadRequestI18n { zh, .. }) = zh_result {
            prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            prop_assert!(zh.contains("格式无效"), "Chinese error should contain '格式无效'");
            prop_assert!(zh.contains("JSON"), "Chinese error should mention JSON");
        }
    }

    /// Test that validate_json accepts various valid JSON formats
    #[test]
    fn prop_json_validation_accepts_all_valid_formats(
        // Generate random JSON-compatible values
        string_val in "[a-zA-Z0-9 ]{0,20}",
        number_val in -1000i32..1000i32,
        bool_val in any::<bool>(),
    ) {
        // Test various valid JSON structures
        let valid_jsons = vec![
            format!(r#"{{"key": "{}"}}"#, string_val),
            format!(r#"[1, 2, 3, {}]"#, number_val),
            format!(r#"{}"#, bool_val),
            "null".to_string(),
            format!(r#"{{"nested": {{"value": {}}}}}"#, number_val),
            format!(r#"[{{"key": "{}"}}]"#, string_val),
        ];

        for json in valid_jsons {
            let result = validate_json(&json, "test_field");
            prop_assert!(result.is_ok(), "valid JSON should be accepted: {}", json);
        }
    }

    /// Test that validate_json rejects unclosed structures
    #[test]
    fn prop_json_validation_rejects_unclosed_structures(
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let unclosed_jsons = vec![
            "{",
            "[",
            r#"{"key": "value""#,
            r#"["item1", "item2""#,
            r#"{"nested": {"inner": "value"}"#,
            r#"[{"key": "value"]"#,
        ];

        for json in unclosed_jsons {
            let result = validate_json(json, &field_name);
            prop_assert!(result.is_err(), "unclosed JSON should be rejected: {}", json);

            // Verify the error contains the field name
            if let Err(ApiError::BadRequestI18n { en, zh }) = result {
                prop_assert!(en.contains(&field_name), "English error should contain field name");
                prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            }
        }
    }

    /// Test that validate_json rejects invalid JSON syntax
    #[test]
    fn prop_json_validation_rejects_invalid_syntax(
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let invalid_jsons = vec![
            "{'single': 'quotes'}",
            "{key: 'no quotes'}",
            "{,}",
            "[,]",
            "undefined",
            "NaN",
            "Infinity",
            "{\"trailing\": \"comma\",}",
            "[\"trailing\", \"comma\",]",
        ];

        for json in invalid_jsons {
            let result = validate_json(json, &field_name);
            prop_assert!(result.is_err(), "invalid JSON syntax should be rejected: {}", json);

            // Verify the error contains the field name
            if let Err(ApiError::BadRequestI18n { en, zh }) = result {
                prop_assert!(en.contains(&field_name), "English error should contain field name");
                prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            }
        }
    }

    /// Test that validate_json rejects empty and whitespace-only strings
    #[test]
    fn prop_json_validation_rejects_empty_and_whitespace(
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let invalid_jsons = vec![
            "",
            " ",
            "  ",
            "\t",
            "\n",
            "   \t\n   ",
        ];

        for json in invalid_jsons {
            let result = validate_json(json, &field_name);
            prop_assert!(result.is_err(), "empty/whitespace JSON should be rejected: {:?}", json);

            // Verify the error contains the field name
            if let Err(ApiError::BadRequestI18n { en, zh }) = result {
                prop_assert!(en.contains(&field_name), "English error should contain field name");
                prop_assert!(zh.contains(&field_name), "Chinese error should contain field name");
            }
        }
    }

    /// Test that validate_json accepts complex nested structures
    #[test]
    fn prop_json_validation_accepts_complex_nested(
        depth in 1usize..5usize,
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        // Build a nested JSON object with the specified depth
        let mut json = String::from(r#"{"value": 1"#);
        for i in 0..depth {
            json.push_str(&format!(r#", "nested{}": {{"inner": {}}}"#, i, i));
        }
        json.push('}');

        let result = validate_json(&json, &field_name);
        prop_assert!(result.is_ok(), "complex nested JSON should be accepted: {}", json);
    }

    /// Test that validate_json accepts arrays with mixed types
    #[test]
    fn prop_json_validation_accepts_mixed_arrays(
        string_val in "[a-zA-Z0-9]{1,10}",
        number_val in -100i32..100i32,
        bool_val in any::<bool>(),
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let json = format!(
            r#"["{}", {}, {}, null, {{"key": "value"}}]"#,
            string_val, number_val, bool_val
        );

        let result = validate_json(&json, &field_name);
        prop_assert!(result.is_ok(), "mixed-type array JSON should be accepted: {}", json);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(10))]

    /// **Property 11: Minimum Length Validation Correctness**
    /// **Validates: Requirements 6.5**
    ///
    /// For any string with length >= min_length, validate_min_length SHALL return Ok,
    /// and for any string with length < min_length, validate_min_length SHALL return
    /// an ApiError with appropriate bilingual message.
    #[test]
    fn prop_min_length_validation_correctness(
        // Generate strings of various lengths
        value in ".*",
        // Generate minimum length requirements (1-50)
        min_len in 1usize..50,
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let result = validate_min_length(&value, min_len, &field_name);

        if value.len() >= min_len {
            // String meets minimum length requirement - should pass
            prop_assert!(result.is_ok(),
                "string of length {} should pass min_len {} validation",
                value.len(), min_len);
        } else {
            // String is too short - should fail
            prop_assert!(result.is_err(),
                "string of length {} should fail min_len {} validation",
                value.len(), min_len);

            // Verify the error contains the field name and min_len
            if let Err(ApiError::BadRequestI18n { en, zh }) = result {
                prop_assert!(en.contains(&field_name),
                    "English error should contain field name");
                prop_assert!(zh.contains(&field_name),
                    "Chinese error should contain field name");
                prop_assert!(en.contains(&min_len.to_string()),
                    "English error should contain min_len");
                prop_assert!(zh.contains(&min_len.to_string()),
                    "Chinese error should contain min_len");
            } else {
                return Err(proptest::test_runner::TestCaseError::fail(
                    "expected BadRequestI18n error"));
            }
        }
    }

    /// Test minimum length validation with bilingual error messages
    #[test]
    fn prop_min_length_validation_bilingual_messages(
        // Generate strings that are too short (0-5 chars)
        short_value in "[a-zA-Z0-9]{0,5}",
        // Require longer length (10-20 chars)
        min_len in 10usize..20,
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_min_length(&short_value, min_len, &field_name)
                })
                .await
        });

        prop_assert!(en_result.is_err(), "short string should be rejected");
        if let Err(ApiError::BadRequestI18n { en, .. }) = en_result {
            prop_assert!(en.contains(&field_name),
                "English error should contain field name");
            prop_assert!(en.contains("Invalid value"),
                "English error should contain 'Invalid value'");
            prop_assert!(en.contains(&min_len.to_string()),
                "English error should contain min_len");
            prop_assert!(en.contains("characters"),
                "English error should mention 'characters'");
        }

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_min_length(&short_value, min_len, &field_name)
                })
                .await
        });

        prop_assert!(zh_result.is_err(), "short string should be rejected");
        if let Err(ApiError::BadRequestI18n { zh, .. }) = zh_result {
            prop_assert!(zh.contains(&field_name),
                "Chinese error should contain field name");
            prop_assert!(zh.contains("字段"),
                "Chinese error should contain '字段'");
            prop_assert!(zh.contains(&min_len.to_string()),
                "Chinese error should contain min_len");
            prop_assert!(zh.contains("字符"),
                "Chinese error should mention '字符'");
        }
    }

    /// Test that validate_min_length accepts strings at exact minimum length
    #[test]
    fn prop_min_length_validation_accepts_exact_length(
        min_len in 1usize..50,
    ) {
        // Generate a string of exactly min_len characters
        let exact_value = "a".repeat(min_len);

        let result = validate_min_length(&exact_value, min_len, "test_field");
        prop_assert!(result.is_ok(),
            "string of exact length {} should be accepted", min_len);
    }

    /// Test that validate_min_length accepts strings longer than minimum
    #[test]
    fn prop_min_length_validation_accepts_longer(
        min_len in 1usize..30,
        extra_len in 1usize..20,
    ) {
        // Generate a string longer than min_len
        let longer_value = "a".repeat(min_len + extra_len);

        let result = validate_min_length(&longer_value, min_len, "test_field");
        prop_assert!(result.is_ok(),
            "string of length {} should be accepted for min_len {}",
            min_len + extra_len, min_len);
    }

    /// Test that validate_min_length rejects strings shorter than minimum
    #[test]
    fn prop_min_length_validation_rejects_shorter(
        min_len in 2usize..50,
    ) {
        // Generate a string shorter than min_len (at least 1 char shorter)
        let short_len = if min_len > 1 { min_len - 1 } else { 0 };
        let short_value = "a".repeat(short_len);

        let result = validate_min_length(&short_value, min_len, "test_field");
        prop_assert!(result.is_err(),
            "string of length {} should be rejected for min_len {}",
            short_len, min_len);
    }

    /// Test that validate_min_length handles empty strings correctly
    #[test]
    fn prop_min_length_validation_empty_string(
        min_len in 1usize..50,
    ) {
        let result = validate_min_length("", min_len, "test_field");

        if min_len > 0 {
            prop_assert!(result.is_err(),
                "empty string should be rejected for min_len {}", min_len);
        } else {
            prop_assert!(result.is_ok(),
                "empty string should be accepted for min_len 0");
        }
    }

    /// Test that validate_min_length handles Unicode characters correctly
    #[test]
    fn prop_min_length_validation_unicode(
        // Generate strings with various Unicode characters
        unicode_str in "[\\u{4E00}-\\u{9FFF}]{0,20}", // Chinese characters
        min_len in 1usize..15,
    ) {
        let result = validate_min_length(&unicode_str, min_len, "test_field");

        // Note: len() counts bytes, not characters, but the implementation uses len()
        // so we test against that behavior
        if unicode_str.len() >= min_len {
            prop_assert!(result.is_ok(),
                "unicode string of byte length {} should pass min_len {} validation",
                unicode_str.len(), min_len);
        } else {
            prop_assert!(result.is_err(),
                "unicode string of byte length {} should fail min_len {} validation",
                unicode_str.len(), min_len);
        }
    }

    /// Test that validate_min_length error messages are consistent across locales
    #[test]
    fn prop_min_length_validation_error_consistency(
        short_value in "[a-zA-Z]{0,3}",
        min_len in 5usize..15,
        field_name in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Get error in both locales
        let en_err = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    validate_min_length(&short_value, min_len, &field_name).unwrap_err()
                })
                .await
        });

        let zh_err = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    validate_min_length(&short_value, min_len, &field_name).unwrap_err()
                })
                .await
        });

        // Both should be BadRequestI18n variants
        match (en_err, zh_err) {
            (ApiError::BadRequestI18n { en, .. }, ApiError::BadRequestI18n { zh, .. }) => {
                // Both should contain the same field name and min_len
                prop_assert!(en.contains(&field_name) && zh.contains(&field_name),
                    "both errors should contain field name");
                prop_assert!(en.contains(&min_len.to_string()) && zh.contains(&min_len.to_string()),
                    "both errors should contain min_len");
                // Messages should be different (different languages)
                prop_assert!(en != zh, "English and Chinese messages should differ");
            }
            _ => return Err(proptest::test_runner::TestCaseError::fail(
                "both errors should be BadRequestI18n variants")),
        }
    }
}
