//! Property-based tests for bilingual error handling.
//!
//! These tests verify that bilingual error constructors correctly select
//! the appropriate language based on the REQUEST_LOCALE task-local variable.

use super::api_error::ApiError;
use super::locale::{ApiLocale, REQUEST_LOCALE};
use axum::body::to_bytes;
use axum::response::IntoResponse;
use proptest::prelude::*;

/// Helper function to extract the message field from an error response
async fn extract_message_from_response(resp: axum::response::Response) -> String {
    let bytes = to_bytes(resp.into_body(), 16 * 1024)
        .await
        .expect("body bytes");
    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
    json.get("message")
        .and_then(serde_json::Value::as_str)
        .expect("message field")
        .to_string()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(10))]

    /// **Property 4: Bilingual Constructor Correctness**
    /// **Validates: Requirements 2.1, 3.1, 4.1, 5.1**
    ///
    /// For any bilingual error constructor (BadRequestI18n, ConflictI18n, ForbiddenI18n,
    /// NotImplementedI18n) and any pair of English/Chinese messages, when constructed in
    /// English locale the message SHALL be the English variant, and when constructed in
    /// Chinese locale the message SHALL be the Chinese variant.
    #[test]
    fn prop_bad_request_i18n_selects_correct_language(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::BadRequestI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&en_result, &en_msg);

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::BadRequestI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&zh_result, &zh_msg);
    }

    #[test]
    fn prop_conflict_i18n_selects_correct_language(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::ConflictI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&en_result, &en_msg);

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::ConflictI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&zh_result, &zh_msg);
    }

    #[test]
    fn prop_forbidden_i18n_selects_correct_language(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::ForbiddenI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&en_result, &en_msg);

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::ForbiddenI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&zh_result, &zh_msg);
    }

    #[test]
    fn prop_not_implemented_i18n_selects_correct_language(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::NotImplementedI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&en_result, &en_msg);

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::NotImplementedI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&zh_result, &zh_msg);
    }

    #[test]
    fn prop_conflict_with_details_i18n_selects_correct_language(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        let details = serde_json::json!({
            "expected_version": "v1",
            "current_version": "v2"
        });

        // Test English locale
        let en_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::ConflictWithDetailsI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                        details: details.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&en_result, &en_msg);

        // Test Chinese locale
        let zh_result = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::ConflictWithDetailsI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                        details: details.clone(),
                    };
                    let resp = error.into_response();
                    extract_message_from_response(resp).await
                })
                .await
        });
        prop_assert_eq!(&zh_result, &zh_msg);
    }

    /// **Property 5: Details Preservation Across Languages**
    /// **Validates: Requirements 3.2**
    ///
    /// For any ConflictWithDetailsI18n error and any details JSON object, the details field
    /// in the response SHALL be identical regardless of the selected language.
    #[test]
    fn prop_details_preservation_across_languages(
        en_msg in "[a-zA-Z0-9 ]{1,50}",
        zh_msg in "[\u{4e00}-\u{9fff}]{1,20}",
        expected_version in "[a-zA-Z0-9]{1,10}",
        current_version in "[a-zA-Z0-9]{1,10}",
        conflict_type in "[a-zA-Z_]{1,20}",
    ) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime");

        // Create a details object with various field types
        let details = serde_json::json!({
            "expected_version": expected_version,
            "current_version": current_version,
            "conflict_type": conflict_type,
            "timestamp": 1234567890,
            "retry_allowed": true,
            "nested": {
                "field1": "value1",
                "field2": 42
            }
        });

        // Extract details from English locale response
        let en_details = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::En, async {
                    let error = ApiError::ConflictWithDetailsI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                        details: details.clone(),
                    };
                    let resp = error.into_response();
                    let bytes = to_bytes(resp.into_body(), 16 * 1024)
                        .await
                        .expect("body bytes");
                    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
                    json.get("details").cloned().expect("details field")
                })
                .await
        });

        // Extract details from Chinese locale response
        let zh_details = runtime.block_on(async {
            REQUEST_LOCALE
                .scope(ApiLocale::Zh, async {
                    let error = ApiError::ConflictWithDetailsI18n {
                        en: en_msg.clone(),
                        zh: zh_msg.clone(),
                        details: details.clone(),
                    };
                    let resp = error.into_response();
                    let bytes = to_bytes(resp.into_body(), 16 * 1024)
                        .await
                        .expect("body bytes");
                    let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");
                    json.get("details").cloned().expect("details field")
                })
                .await
        });

        // Verify that details are identical across both languages
        prop_assert_eq!(&en_details, &zh_details, "details must be identical across languages");

        // Verify that the details match the original input
        prop_assert_eq!(&en_details, &details, "details must match the original input");

        // Verify specific fields are preserved correctly
        prop_assert_eq!(
            en_details.get("expected_version").and_then(serde_json::Value::as_str),
            Some(expected_version.as_str()),
            "expected_version must be preserved"
        );
        prop_assert_eq!(
            en_details.get("current_version").and_then(serde_json::Value::as_str),
            Some(current_version.as_str()),
            "current_version must be preserved"
        );
        prop_assert_eq!(
            en_details.get("conflict_type").and_then(serde_json::Value::as_str),
            Some(conflict_type.as_str()),
            "conflict_type must be preserved"
        );
        prop_assert_eq!(
            en_details.get("timestamp").and_then(serde_json::Value::as_u64),
            Some(1234567890),
            "timestamp must be preserved"
        );
        prop_assert_eq!(
            en_details.get("retry_allowed").and_then(serde_json::Value::as_bool),
            Some(true),
            "retry_allowed must be preserved"
        );

        // Verify nested object is preserved
        let nested = en_details.get("nested").expect("nested object must exist");
        prop_assert_eq!(
            nested.get("field1").and_then(serde_json::Value::as_str),
            Some("value1"),
            "nested.field1 must be preserved"
        );
        prop_assert_eq!(
            nested.get("field2").and_then(serde_json::Value::as_u64),
            Some(42),
            "nested.field2 must be preserved"
        );
    }
}
