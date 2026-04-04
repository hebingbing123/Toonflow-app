//! Shared JSON merge helpers for PATCH bodies (`Option<Value>` per field).

use serde_json::Value;

use crate::error::ApiError;

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
