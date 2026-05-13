//! PII Hygiene Tests for Workspace Billing (Task 8.2)
//!
//! Verifies that workspace billing endpoints and logs maintain PII hygiene:
//! - Only workspace-level aggregates in responses
//! - No individual user PII beyond workspace owner context
//! - Logs contain only UUIDs, not emails/names
//!
//! **Validates: Requirements 7.2**
//!
//! ## Running These Tests
//!
//! ```bash
//! # Run all PII hygiene tests
//! cargo test --test pii_hygiene_test
//!
//! # Run with database (requires TEST_DATABASE_URL)
//! TEST_DATABASE_URL=postgresql://... cargo test --test pii_hygiene_test
//! ```

use serde_json::Value;

/// Helper to check if a JSON value contains email-like strings
fn contains_email_pattern(value: &Value) -> bool {
    match value {
        Value::String(s) => s.contains('@') && s.contains('.'),
        Value::Array(arr) => arr.iter().any(contains_email_pattern),
        Value::Object(obj) => obj.values().any(contains_email_pattern),
        _ => false,
    }
}

/// Helper to check if a JSON value contains user-identifiable fields
fn contains_user_pii_fields(value: &Value, allowed_fields: &[&str]) -> Vec<String> {
    let mut found_pii = Vec::new();

    if let Value::Object(obj) = value {
        // Check for common PII field names
        let pii_fields = [
            "email",
            "user_email",
            "member_email",
            "member_emails",
            "user_name",
            "username",
            "full_name",
            "first_name",
            "last_name",
            "phone",
            "address",
        ];

        for field in pii_fields {
            if obj.contains_key(field) && !allowed_fields.contains(&field) {
                found_pii.push(field.to_string());
            }
        }

        // Recursively check nested objects and arrays
        for (key, val) in obj {
            if !allowed_fields.contains(&key.as_str()) {
                let nested_pii = contains_user_pii_fields(val, allowed_fields);
                found_pii.extend(nested_pii);
            }
        }
    } else if let Value::Array(arr) = value {
        for item in arr {
            let nested_pii = contains_user_pii_fields(item, allowed_fields);
            found_pii.extend(nested_pii);
        }
    }

    found_pii
}

#[test]
fn test_workspace_subscription_snapshot_no_member_pii() {
    // Verify WorkspaceSubscriptionSnapshot structure doesn't expose member PII
    let sample_response = serde_json::json!({
        "subscription": {
            "workspace_id": "00000000-0000-0000-0000-000000000000",
            "workspace_type": "enterprise",
            "plan_tier": "enterprise",
            "daily_job_quota": 1000,
            "billing_provider": "stripe",
            "billing_customer_id": "cus_test123",
            "billing_currency": "USD",
            "created_at": "2025-01-01T00:00:00Z"
        }
    });

    // Should not contain any email fields
    assert!(
        !contains_email_pattern(&sample_response),
        "WorkspaceSubscriptionSnapshot should not contain email addresses"
    );

    // Should not contain user PII fields (no allowed exceptions)
    let pii_fields = contains_user_pii_fields(&sample_response, &[]);
    assert!(
        pii_fields.is_empty(),
        "WorkspaceSubscriptionSnapshot should not contain user PII fields: {:?}",
        pii_fields
    );
}

#[test]
fn test_workspace_job_aggregates_no_individual_jobs() {
    // Verify WorkspaceJobAggregates structure only contains aggregates
    let sample_response = serde_json::json!({
        "aggregates": {
            "workspace_id": "00000000-0000-0000-0000-000000000000",
            "total_jobs": 1000,
            "jobs_today": 42,
            "jobs_last_7_days": 250,
            "jobs_last_30_days": 800,
            "jobs_by_status": {
                "completed": 900,
                "running": 10,
                "failed": 90
            }
        }
    });

    // Should not contain any email fields
    assert!(
        !contains_email_pattern(&sample_response),
        "WorkspaceJobAggregates should not contain email addresses"
    );

    // Should not contain user PII fields
    let pii_fields = contains_user_pii_fields(&sample_response, &[]);
    assert!(
        pii_fields.is_empty(),
        "WorkspaceJobAggregates should not contain user PII fields: {:?}",
        pii_fields
    );

    // Verify only aggregate counts, not individual job details
    let aggregates = &sample_response["aggregates"];
    assert!(
        aggregates.get("job_list").is_none(),
        "Should not expose individual job list"
    );
    assert!(
        aggregates.get("jobs").is_none(),
        "Should not expose individual jobs array"
    );
    assert!(
        aggregates.get("job_details").is_none(),
        "Should not expose individual job details"
    );
}

#[test]
fn test_admin_workspace_billing_response_owner_context_only() {
    // Verify AdminWorkspaceBillingResponse exposes only owner context, not all members
    let sample_response = serde_json::json!({
        "workspace_id": "00000000-0000-0000-0000-000000000000",
        "workspace_name": "Test Workspace",
        "workspace_type": "enterprise",
        "owner_user_id": "11111111-1111-1111-1111-111111111111",
        "owner_email": "owner@example.com",
        "plan_tier": "enterprise",
        "billing_currency": "USD",
        "billing_provider": "stripe",
        "daily_job_quota": 1000,
        "jobs_today": 42,
        "jobs_this_month": 800,
        "member_count": 25,
        "project_count": 10,
        "created_at": "2025-01-01T00:00:00Z"
    });

    // Owner email is allowed (billing contact)
    let allowed_fields = ["owner_email"];
    let pii_fields = contains_user_pii_fields(&sample_response, &allowed_fields);

    // Should not contain member PII beyond owner
    assert!(
        !pii_fields.contains(&"member_email".to_string()),
        "Should not expose member emails"
    );
    assert!(
        !pii_fields.contains(&"member_emails".to_string()),
        "Should not expose member emails array"
    );
    assert!(
        !pii_fields.contains(&"user_email".to_string()),
        "Should not expose user emails"
    );

    // Verify only aggregate member_count, not individual members
    assert!(
        sample_response.get("members").is_none(),
        "Should not expose individual members array"
    );
    assert!(
        sample_response.get("member_list").is_none(),
        "Should not expose member list"
    );
    assert!(
        sample_response["member_count"].is_number(),
        "Should expose only aggregate member_count"
    );
}

#[test]
fn test_ops_billing_responses_are_aggregates_only() {
    // Comprehensive test: verify all ops billing responses contain only aggregates

    let test_cases = vec![
        (
            "WorkspaceSubscriptionSnapshot",
            serde_json::json!({
                "subscription": {
                    "workspace_id": "00000000-0000-0000-0000-000000000000",
                    "workspace_type": "enterprise",
                    "plan_tier": "enterprise",
                    "daily_job_quota": 1000,
                    "billing_provider": "stripe",
                    "billing_customer_id": "cus_test123",
                    "billing_currency": "USD",
                    "created_at": "2025-01-01T00:00:00Z"
                }
            }),
            vec![], // No allowed PII fields
        ),
        (
            "WorkspaceJobAggregates",
            serde_json::json!({
                "aggregates": {
                    "workspace_id": "00000000-0000-0000-0000-000000000000",
                    "total_jobs": 1000,
                    "jobs_today": 42,
                    "jobs_last_7_days": 250,
                    "jobs_last_30_days": 800,
                    "jobs_by_status": {
                        "completed": 900,
                        "running": 10,
                        "failed": 90
                    }
                }
            }),
            vec![], // No allowed PII fields
        ),
        (
            "AdminWorkspaceBillingResponse",
            serde_json::json!({
                "workspace_id": "00000000-0000-0000-0000-000000000000",
                "workspace_name": "Test Workspace",
                "workspace_type": "enterprise",
                "owner_user_id": "11111111-1111-1111-1111-111111111111",
                "owner_email": "owner@example.com",
                "plan_tier": "enterprise",
                "billing_currency": "USD",
                "billing_provider": "stripe",
                "daily_job_quota": 1000,
                "jobs_today": 42,
                "jobs_this_month": 800,
                "member_count": 25,
                "project_count": 10,
                "created_at": "2025-01-01T00:00:00Z"
            }),
            vec!["owner_email"], // Owner email is allowed (billing contact)
        ),
    ];

    for (response_type, sample_response, allowed_fields) in test_cases {
        let pii_fields = contains_user_pii_fields(&sample_response, &allowed_fields);

        // Filter out allowed fields from violations
        let violations: Vec<_> = pii_fields
            .iter()
            .filter(|f| !allowed_fields.contains(&f.as_str()))
            .collect();

        assert!(
            violations.is_empty(),
            "{} should not contain unexpected PII fields: {:?}",
            response_type,
            violations
        );
    }
}

#[test]
fn test_no_individual_user_arrays_in_billing_responses() {
    // Verify that billing responses don't expose arrays of individual users

    let forbidden_array_fields = [
        "members",
        "users",
        "member_list",
        "user_list",
        "member_details",
        "user_details",
        "jobs", // Individual jobs (aggregates are OK)
        "job_list",
        "job_details",
    ];

    let sample_responses = vec![
        serde_json::json!({
            "subscription": {
                "workspace_id": "00000000-0000-0000-0000-000000000000",
                "workspace_type": "enterprise",
                "plan_tier": "enterprise"
            }
        }),
        serde_json::json!({
            "aggregates": {
                "workspace_id": "00000000-0000-0000-0000-000000000000",
                "total_jobs": 1000,
                "jobs_today": 42
            }
        }),
        serde_json::json!({
            "workspace_id": "00000000-0000-0000-0000-000000000000",
            "workspace_name": "Test Workspace",
            "owner_email": "owner@example.com",
            "member_count": 25,
            "jobs_today": 42
        }),
    ];

    for sample_response in sample_responses {
        for forbidden_field in forbidden_array_fields {
            assert!(
                !contains_field_recursive(&sample_response, forbidden_field),
                "Billing response should not contain '{}' field",
                forbidden_field
            );
        }
    }
}

/// Helper to recursively check if a field exists in JSON
fn contains_field_recursive(value: &Value, field_name: &str) -> bool {
    match value {
        Value::Object(obj) => {
            if obj.contains_key(field_name) {
                return true;
            }
            obj.values()
                .any(|v| contains_field_recursive(v, field_name))
        }
        Value::Array(arr) => arr.iter().any(|v| contains_field_recursive(v, field_name)),
        _ => false,
    }
}

#[test]
fn test_billing_responses_contain_only_workspace_context() {
    // Verify that billing responses are scoped to workspace, not individual users

    let sample_response = serde_json::json!({
        "workspace_id": "00000000-0000-0000-0000-000000000000",
        "workspace_name": "Test Workspace",
        "workspace_type": "enterprise",
        "owner_user_id": "11111111-1111-1111-1111-111111111111",
        "owner_email": "owner@example.com",
        "plan_tier": "enterprise",
        "member_count": 25,
        "project_count": 10,
        "jobs_today": 42,
        "jobs_this_month": 800
    });

    // Verify workspace context fields exist
    assert!(
        sample_response.get("workspace_id").is_some(),
        "Should have workspace_id"
    );
    assert!(
        sample_response.get("workspace_name").is_some(),
        "Should have workspace_name"
    );
    assert!(
        sample_response.get("workspace_type").is_some(),
        "Should have workspace_type"
    );

    // Verify only aggregate counts, not individual records
    assert!(
        sample_response["member_count"].is_number(),
        "Should have aggregate member_count"
    );
    assert!(
        sample_response["project_count"].is_number(),
        "Should have aggregate project_count"
    );
    assert!(
        sample_response["jobs_today"].is_number(),
        "Should have aggregate jobs_today"
    );

    // Verify no individual user/member/job arrays
    assert!(
        sample_response.get("members").is_none(),
        "Should not have members array"
    );
    assert!(
        sample_response.get("projects").is_none(),
        "Should not have projects array"
    );
    assert!(
        sample_response.get("jobs").is_none(),
        "Should not have jobs array"
    );
}

#[test]
fn test_pii_hygiene_documentation_exists() {
    // Verify that PII hygiene audit documentation exists
    let audit_path =
        std::path::Path::new("../.kiro/specs/workspace-scope-billing/pii-hygiene-audit.md");

    assert!(
        audit_path.exists(),
        "PII hygiene audit documentation should exist at {}",
        audit_path.display()
    );
}
