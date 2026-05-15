//! Billing-path API error helpers with bilingual `message` payloads.

use crate::error::ApiError;

pub fn quota_exceeded_billing_i18n(limit: u64, plan_tier: &str) -> ApiError {
    ApiError::QuotaExceededI18n {
        en: format!("You have reached the daily quota limit of {limit} for the {plan_tier} plan."),
        zh: format!("您已达到 {plan_tier} 套餐的每日配额上限（{limit}）。"),
    }
}

pub fn subscription_expired_i18n() -> ApiError {
    ApiError::SubscriptionExpiredI18n {
        en: "Your subscription has expired. Please renew to continue.".to_string(),
        zh: "您的订阅已过期，请续订以继续使用。".to_string(),
    }
}

pub fn payment_failed_i18n() -> ApiError {
    ApiError::PaymentFailedI18n {
        en: "Payment failed. Please update your payment method to continue.".to_string(),
        zh: "付款失败，请更新支付方式以继续使用。".to_string(),
    }
}

pub fn subscription_past_due_i18n() -> ApiError {
    ApiError::SubscriptionPastDueI18n {
        en: "Your subscription payment is past due. Please update your payment method.".to_string(),
        zh: "您的订阅付款已逾期，请更新支付方式。".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::locale::{
        preferred_locale_from_accept_language_str, ApiLocale, REQUEST_LOCALE,
    };
    use axum::body::to_bytes;
    use axum::http::header;
    use axum::response::IntoResponse;

    async fn body_json(resp: axum::response::Response) -> serde_json::Value {
        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        serde_json::from_slice(&bytes).expect("json body")
    }

    #[tokio::test]
    async fn quota_exceeded_en_zh_messages_differ() {
        let en = REQUEST_LOCALE
            .scope(ApiLocale::En, async {
                let body =
                    body_json(quota_exceeded_billing_i18n(100, "free").into_response()).await;
                body["message"].as_str().unwrap().to_string()
            })
            .await;
        let zh = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let body =
                    body_json(quota_exceeded_billing_i18n(100, "free").into_response()).await;
                body["message"].as_str().unwrap().to_string()
            })
            .await;
        assert_ne!(en, zh);
        assert!(en.contains("You have reached"));
        assert!(zh.contains("您已达到"));
    }

    #[tokio::test]
    async fn quota_exceeded_code_and_retry_invariant() {
        let err = quota_exceeded_billing_i18n(50, "pro");
        let resp = err.into_response();
        let secs: u64 = resp
            .headers()
            .get(header::RETRY_AFTER)
            .unwrap()
            .to_str()
            .unwrap()
            .parse()
            .unwrap();
        let body = body_json(resp).await;
        assert_eq!(body["code"].as_str(), Some("quota_exceeded"));
        let retry_ms = body["retry_after_ms"].as_u64().expect("retry_after_ms");
        assert_eq!(retry_ms, secs * 1_000);
    }

    #[tokio::test]
    async fn subscription_errors_no_retry_after() {
        for make in [
            subscription_expired_i18n as fn() -> ApiError,
            payment_failed_i18n as fn() -> ApiError,
            subscription_past_due_i18n as fn() -> ApiError,
        ] {
            let resp = make().into_response();
            assert!(resp.headers().get(header::RETRY_AFTER).is_none());
            let body = body_json(resp).await;
            assert!(body.get("retry_after_ms").is_none());
        }
    }

    // Feature: billing-i18n-production, Property 2: Accept-Language 未知语言标签回落英文
    mod proptest_accept_language {
        use super::*;
        use proptest::prelude::*;

        fn has_en_or_zh_primary(s: &str) -> bool {
            for part in s.split(',') {
                let lang_tag = part.trim().split(';').next().unwrap_or("").trim();
                if lang_tag.is_empty() {
                    continue;
                }
                let primary = lang_tag
                    .split('-')
                    .next()
                    .unwrap_or("")
                    .to_ascii_lowercase();
                if primary == "en" || primary == "zh" {
                    return true;
                }
            }
            false
        }

        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]
            #[test]
            fn prop_unknown_accept_language_defaults_to_en(raw in "[^\r\n]{0,80}") {
                let s = raw.trim();
                prop_assume!(!has_en_or_zh_primary(s));
                prop_assert_eq!(
                    preferred_locale_from_accept_language_str(s),
                    ApiLocale::En
                );
            }
        }
    }

    // Feature: billing-i18n-production, Property 1: 计费错误双语响应不变量
    mod proptest_billing_i18n {
        use super::*;
        use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
        use axum::http::header;
        use proptest::prelude::*;

        fn response_body(err: ApiError, locale: ApiLocale) -> (serde_json::Value, Option<u64>) {
            tokio::runtime::Runtime::new()
                .expect("runtime")
                .block_on(async {
                    REQUEST_LOCALE
                        .scope(locale, async {
                            let resp = err.into_response();
                            let retry_secs = resp
                                .headers()
                                .get(header::RETRY_AFTER)
                                .and_then(|h| h.to_str().ok())
                                .and_then(|s| s.parse::<u64>().ok());
                            let body = body_json(resp).await;
                            (body, retry_secs)
                        })
                        .await
                })
        }

        proptest! {
            #![proptest_config(ProptestConfig::with_cases(100))]
            #[test]
            fn prop_quota_exceeded_code_and_retry_invariant(limit in 1u64..10_000u64, plan in "[a-z]{1,12}") {
                let err = quota_exceeded_billing_i18n(limit, &plan);
                let ApiError::QuotaExceededI18n { en, zh } = &err else {
                    return Err(TestCaseError::fail("expected QuotaExceededI18n"));
                };
                prop_assert_ne!(en, zh);
                for locale in [ApiLocale::En, ApiLocale::Zh] {
                    let err = quota_exceeded_billing_i18n(limit, &plan);
                    let (body, retry_secs) = response_body(err, locale);
                    prop_assert_eq!(body["code"].as_str(), Some("quota_exceeded"));
                    let retry_ms = body["retry_after_ms"].as_u64().expect("retry_after_ms");
                    prop_assert_eq!(retry_ms, retry_secs.expect("Retry-After") * 1_000);
                }
            }
        }

        proptest! {
            #![proptest_config(ProptestConfig::with_cases(32))]
            #[test]
            fn prop_subscription_billing_codes_invariant(case in 0u8..3u8) {
                let make_err = match case {
                    0 => subscription_expired_i18n as fn() -> ApiError,
                    1 => payment_failed_i18n as fn() -> ApiError,
                    _ => subscription_past_due_i18n as fn() -> ApiError,
                };
                let code = match case {
                    0 => "subscription_expired",
                    1 => "payment_failed",
                    _ => "subscription_past_due",
                };
                let (en_body, _) = response_body(make_err(), ApiLocale::En);
                let (zh_body, _) = response_body(make_err(), ApiLocale::Zh);
                prop_assert_ne!(en_body["message"].as_str(), zh_body["message"].as_str());
                for locale in [ApiLocale::En, ApiLocale::Zh] {
                    let (body, retry_secs) = response_body(make_err(), locale);
                    prop_assert_eq!(body["code"].as_str(), Some(code));
                    prop_assert!(body.get("retry_after_ms").is_none());
                    prop_assert!(retry_secs.is_none());
                }
            }
        }
    }
}
