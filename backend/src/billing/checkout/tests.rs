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
