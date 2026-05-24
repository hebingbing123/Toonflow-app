//! Checkout catalog and Alipay form parsing tests.

#[cfg(test)]
mod catalog_tests {
    use crate::billing::checkout::catalog::{catalog, find_plan, plan_tier_for_stripe_price};

    #[test]
    fn catalog_has_creator_pro_studio() {
        assert_eq!(catalog().plans.len(), 3);
        assert!(find_plan("creator").is_some());
    }

    #[test]
    fn stripe_price_lookup_empty_when_unconfigured() {
        assert!(plan_tier_for_stripe_price("price_unknown").is_none());
    }
}

#[cfg(test)]
mod alipay_tests {
    use crate::billing::checkout::alipay;

    #[test]
    fn parse_notify_form() {
        let m = alipay::parse_form_body("out_trade_no=abc&trade_status=TRADE_SUCCESS");
        assert_eq!(m.get("out_trade_no").map(String::as_str), Some("abc"));
    }
}

#[cfg(test)]
mod bitpay_tests {
    use crate::billing::checkout::bitpay;

    #[test]
    fn verify_webhook_signature_accepts_valid_hmac() {
        use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
        use hmac::{Hmac, Mac};
        use sha2::Sha256;

        let token = "test-bitpay-token";
        let body = br#"{"event":{"name":"invoice_completed"},"data":{"id":"inv1"}}"#;
        let mut mac = Hmac::<Sha256>::new_from_slice(token.as_bytes()).unwrap();
        mac.update(body);
        let sig = BASE64.encode(mac.finalize().into_bytes());
        assert!(bitpay::verify_webhook_signature(token, body, &sig).is_ok());
    }

    #[test]
    fn verify_webhook_signature_rejects_wrong_hmac() {
        let body = br#"{"event":{"name":"invoice_completed"}}"#;
        assert!(bitpay::verify_webhook_signature("token", body, "not-valid-base64==").is_err());
    }
}
