//! Shared JSON merge helpers for PATCH bodies (`Option<Value>` per field).

use serde_json::Value;

use crate::error::ApiError;

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum FieldPatch<T> {
    Absent,
    Set(Option<T>),
}

pub(crate) fn parse_optional_text_field(
    v: Option<Value>,
    field: &str,
) -> Result<FieldPatch<String>, ApiError> {
    match v {
        None => Ok(FieldPatch::Absent),
        Some(Value::Null) => Ok(FieldPatch::Set(None)),
        Some(Value::String(s)) => {
            if s.is_empty() {
                Ok(FieldPatch::Set(None))
            } else {
                Ok(FieldPatch::Set(Some(s)))
            }
        }
        _ => Err(ApiError::BadRequest(format!(
            "{field} must be a string, null, or omitted",
        ))),
    }
}

pub(crate) fn parse_optional_i32_field(
    v: Option<Value>,
    field: &str,
) -> Result<FieldPatch<i32>, ApiError> {
    match v {
        None => Ok(FieldPatch::Absent),
        Some(Value::Null) => Ok(FieldPatch::Set(None)),
        Some(Value::Number(n)) => {
            let i = n
                .as_i64()
                .ok_or_else(|| ApiError::BadRequest(format!("{field} must fit in i64")))?;
            let v = i32::try_from(i)
                .map_err(|_| ApiError::BadRequest(format!("{field} must fit in i32")))?;
            Ok(FieldPatch::Set(Some(v)))
        }
        _ => Err(ApiError::BadRequest(format!(
            "{field} must be a number, null, or omitted",
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn optional_text_absent_null_and_empty_clear() {
        assert_eq!(
            parse_optional_text_field(None, "x").unwrap(),
            FieldPatch::Absent
        );
        assert_eq!(
            parse_optional_text_field(Some(Value::Null), "x").unwrap(),
            FieldPatch::Set(None)
        );
        assert_eq!(
            parse_optional_text_field(Some(Value::String(String::new())), "x").unwrap(),
            FieldPatch::Set(None)
        );
        assert_eq!(
            parse_optional_text_field(Some(Value::String("hi".into())), "f").unwrap(),
            FieldPatch::Set(Some("hi".into()))
        );
    }

    #[test]
    fn optional_text_rejects_non_string() {
        assert!(parse_optional_text_field(Some(json!(true)), "n").is_err());
        assert!(parse_optional_text_field(Some(json!([])), "n").is_err());
    }

    #[test]
    fn optional_i32_absent_null_and_number() {
        assert_eq!(
            parse_optional_i32_field(None, "x").unwrap(),
            FieldPatch::Absent
        );
        assert_eq!(
            parse_optional_i32_field(Some(Value::Null), "x").unwrap(),
            FieldPatch::Set(None)
        );
        assert_eq!(
            parse_optional_i32_field(Some(json!(-7)), "x").unwrap(),
            FieldPatch::Set(Some(-7))
        );
        assert_eq!(
            parse_optional_i32_field(Some(json!(i32::MAX)), "x").unwrap(),
            FieldPatch::Set(Some(i32::MAX))
        );
    }

    #[test]
    fn optional_i32_rejects_non_number() {
        assert!(parse_optional_i32_field(Some(json!("1")), "x").is_err());
    }

    #[test]
    fn optional_i32_rejects_out_of_range() {
        let too_large = (i32::MAX as i64) + 1;
        assert!(parse_optional_i32_field(Some(json!(too_large)), "x").is_err());
    }
}
