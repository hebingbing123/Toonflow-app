use chrono::{DateTime, Utc};

use crate::billing::provider_rules::normalize_provider_name;
use crate::error::{bad_request_i18n, validate_non_empty_string, ApiError};

pub(super) fn parse_query_ts(raw: &str, field: &str) -> Result<DateTime<Utc>, ApiError> {
    DateTime::parse_from_rfc3339(raw.trim())
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|_| {
            bad_request_i18n(
                &format!("{field} must be RFC3339 timestamp"),
                &format!("{field} 必须是 RFC3339 时间戳"),
            )
        })
}

pub(super) fn parse_query_text_non_empty(
    raw: &str,
    field: &str,
    max_len: usize,
) -> Result<String, ApiError> {
    let v = raw.trim();
    validate_non_empty_string(v, field)?;
    Ok(v.chars().take(max_len).collect())
}

pub(super) fn parse_sort(raw: Option<&str>) -> Result<&'static str, ApiError> {
    let Some(raw) = raw else {
        return Ok("id DESC");
    };
    match raw.trim().to_ascii_lowercase().as_str() {
        "id_desc" => Ok("id DESC"),
        "id_asc" => Ok("id ASC"),
        _ => Err(bad_request_i18n(
            "sort must be one of: id_desc, id_asc",
            "sort 必须是以下之一：id_desc、id_asc",
        )),
    }
}

pub(super) fn parse_provider_filter(raw: Option<&str>) -> Result<Option<String>, ApiError> {
    let Some(raw) = raw else {
        return Ok(None);
    };
    let normalized = normalize_provider_name(raw)
        .ok_or_else(|| bad_request_i18n("provider must be non-empty", "provider 不能为空"))?;
    match normalized.as_str() {
        "stripe" | "alipay" | "paddle" => Ok(Some(normalized)),
        _ => Err(bad_request_i18n(
            "provider must be one of: stripe, alipay, paddle",
            "provider 必须是以下之一：stripe、alipay、paddle",
        )),
    }
}

pub(super) fn validate_time_range(
    from: Option<DateTime<Utc>>,
    to: Option<DateTime<Utc>>,
    from_field: &str,
    to_field: &str,
) -> Result<(), ApiError> {
    if let (Some(from), Some(to)) = (from, to) {
        if from > to {
            return Err(bad_request_i18n(
                &format!("{from_field} must be less than or equal to {to_field}"),
                &format!("{from_field} 必须小于或等于 {to_field}"),
            ));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        parse_provider_filter, parse_query_text_non_empty, parse_query_ts, parse_sort,
        validate_time_range,
    };

    #[test]
    fn parse_sort_defaults_and_accepts_known_values() {
        assert_eq!(parse_sort(None).unwrap(), "id DESC");
        assert_eq!(parse_sort(Some("id_asc")).unwrap(), "id ASC");
        assert_eq!(parse_sort(Some(" ID_DESC ")).unwrap(), "id DESC");
    }

    #[test]
    fn parse_provider_filter_normalizes_and_rejects_unknown_values() {
        assert_eq!(
            parse_provider_filter(Some(" Stripe ")).unwrap(),
            Some("stripe".to_string())
        );
        assert!(parse_provider_filter(Some("unknown")).is_err());
        assert!(parse_provider_filter(Some("   ")).is_err());
    }

    #[test]
    fn parse_query_text_non_empty_trims_and_caps_length() {
        assert_eq!(
            parse_query_text_non_empty("  abcdef  ", "field", 4).unwrap(),
            "abcd"
        );
        assert!(parse_query_text_non_empty("   ", "field", 4).is_err());
    }

    #[test]
    fn parse_query_ts_and_validate_time_range_enforce_rfc3339_ordering() {
        let from = parse_query_ts("2026-04-17T10:00:00Z", "from").unwrap();
        let to = parse_query_ts("2026-04-17T11:00:00Z", "to").unwrap();
        validate_time_range(Some(from), Some(to), "from", "to").unwrap();
        assert!(validate_time_range(Some(to), Some(from), "from", "to").is_err());
        assert!(parse_query_ts("not-a-time", "from").is_err());
    }
}
