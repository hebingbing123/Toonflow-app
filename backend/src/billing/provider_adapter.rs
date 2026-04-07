use serde_json::Value;

use super::provider_rules::normalize_provider_name;

const BILLING_CURRENCY_PROVIDER_MAP_ENV: &str = "BILLING_CURRENCY_PROVIDER_MAP";
const DEFAULT_CURRENCY_PROVIDER_MAP: &[(&str, &str)] = &[("CNY", "alipay"), ("USD", "stripe")];

#[derive(Debug, Clone, Default)]
pub(crate) struct BillingAdapterSelection {
    /// Provider value used for audit persistence / dedupe namespace.
    /// This only reflects explicit payload provider, never inferred.
    pub(crate) audit_provider: Option<String>,
    /// Provider used by parser routing. Falls back to currency defaults.
    pub(crate) mapping_provider: Option<String>,
    /// Uppercased 3-letter currency code when present.
    pub(crate) currency: Option<String>,
}

fn normalize_currency(raw: &str) -> Option<String> {
    let cur = raw.trim().to_ascii_uppercase();
    if cur.is_empty() {
        None
    } else {
        Some(cur.chars().take(16).collect())
    }
}

fn parse_currency_provider_map(raw: &str) -> Vec<(String, String)> {
    raw.split(',')
        .filter_map(|entry| {
            let (currency_raw, provider_raw) = entry.split_once('=')?;
            let currency = normalize_currency(currency_raw)?;
            let provider = normalize_provider_name(provider_raw)?;
            Some((currency, provider))
        })
        .collect()
}

fn currency_provider_map_from_env() -> Vec<(String, String)> {
    match std::env::var(BILLING_CURRENCY_PROVIDER_MAP_ENV) {
        Ok(raw) => {
            let parsed = parse_currency_provider_map(&raw);
            if parsed.is_empty() {
                DEFAULT_CURRENCY_PROVIDER_MAP
                    .iter()
                    .map(|(c, p)| ((*c).to_string(), (*p).to_string()))
                    .collect()
            } else {
                parsed
            }
        }
        Err(_) => DEFAULT_CURRENCY_PROVIDER_MAP
            .iter()
            .map(|(c, p)| ((*c).to_string(), (*p).to_string()))
            .collect(),
    }
}

fn mapping_provider_from_currency(
    currency: Option<&str>,
    mapping_table: &[(String, String)],
) -> Option<String> {
    let currency = currency?;
    mapping_table
        .iter()
        .find(|(c, _)| c == currency)
        .map(|(_, p)| p.clone())
}

/// CNY/USD lightweight adapter:
/// - explicit `billing_provider` always wins;
/// - otherwise infer parser route by currency mapping table.
///   Default table: `CNY=alipay,USD=stripe`, configurable via `BILLING_CURRENCY_PROVIDER_MAP`.
///   Format: `CNY=alipay,USD=stripe,EUR=stripe` (invalid entries are ignored).
pub(crate) fn select_billing_adapter(v: &Value) -> BillingAdapterSelection {
    let explicit_provider = v
        .get("billing_provider")
        .and_then(Value::as_str)
        .and_then(normalize_provider_name);
    let currency = v
        .get("billing_currency")
        .and_then(Value::as_str)
        .and_then(normalize_currency);
    let mapping_table = currency_provider_map_from_env();

    let mapping_provider = explicit_provider
        .clone()
        .or_else(|| mapping_provider_from_currency(currency.as_deref(), &mapping_table));

    BillingAdapterSelection {
        audit_provider: explicit_provider,
        mapping_provider,
        currency,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn explicit_provider_wins_over_currency_default() {
        let v = json!({
            "billing_provider": " paddle ",
            "billing_currency": "CNY"
        });
        let s = select_billing_adapter(&v);
        assert_eq!(s.audit_provider.as_deref(), Some("paddle"));
        assert_eq!(s.mapping_provider.as_deref(), Some("paddle"));
        assert_eq!(s.currency.as_deref(), Some("CNY"));
    }

    #[test]
    fn infers_alipay_from_cny_without_provider() {
        let v = json!({ "billing_currency": " cny " });
        let s = select_billing_adapter(&v);
        assert!(s.audit_provider.is_none());
        assert_eq!(s.mapping_provider.as_deref(), Some("alipay"));
        assert_eq!(s.currency.as_deref(), Some("CNY"));
    }

    #[test]
    fn infers_stripe_from_usd_without_provider() {
        let v = json!({ "billing_currency": "usd" });
        let s = select_billing_adapter(&v);
        assert!(s.audit_provider.is_none());
        assert_eq!(s.mapping_provider.as_deref(), Some("stripe"));
    }

    #[test]
    fn parse_currency_provider_map_ignores_invalid_entries() {
        let parsed = parse_currency_provider_map("CNY=alipay, bad, USD=stripe, EUR=");
        assert_eq!(
            parsed,
            vec![
                ("CNY".to_string(), "alipay".to_string()),
                ("USD".to_string(), "stripe".to_string())
            ]
        );
    }

    #[test]
    fn mapping_provider_from_currency_returns_expected_provider() {
        let map = vec![
            ("CNY".to_string(), "alipay".to_string()),
            ("USD".to_string(), "stripe".to_string()),
        ];
        assert_eq!(
            mapping_provider_from_currency(Some("USD"), &map).as_deref(),
            Some("stripe")
        );
        assert!(mapping_provider_from_currency(Some("JPY"), &map).is_none());
    }
}
