use std::collections::BTreeSet;

use serde_json::Value;
use sqlx::PgPool;

use crate::error::ApiError;
use crate::harness::HarnessContext;

use super::InvokeError;

pub(crate) fn require_pool(ctx: &HarnessContext) -> Result<&PgPool, InvokeError> {
    ctx.pool.as_ref().ok_or(InvokeError::DatabaseUnavailable)
}

pub(crate) fn map_api_error(err: ApiError, fallback: &'static str) -> InvokeError {
    match err {
        ApiError::NotFound => InvokeError::MissingContext("resource not found".into()),
        ApiError::BadRequest(msg) => InvokeError::InvalidArgs(msg),
        ApiError::DatabaseError(msg) => InvokeError::DatabaseError(msg),
        _ => InvokeError::DatabaseError(fallback.into()),
    }
}

pub(crate) fn project_numeric_from_ctx(ctx: &HarnessContext) -> Result<i32, InvokeError> {
    ctx.project_numeric_id
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::MissingContext("project context not attached".into()))
}

pub(crate) fn script_numeric_id_from_args_or_ctx(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<i32, InvokeError> {
    let from_args = arguments
        .get("scriptId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);
    from_args.or(ctx.script_numeric_id).ok_or_else(|| {
        InvokeError::MissingContext("scriptId is required (arg or attach context)".into())
    })
}

pub(crate) fn parse_i32_required(arguments: &Value, key: &str) -> Result<i32, InvokeError> {
    arguments
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a positive integer")))
}

pub(crate) fn parse_ids_required(arguments: &Value, key: &str) -> Result<Vec<i32>, InvokeError> {
    let values = arguments
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a non-empty array")))?;
    if values.is_empty() {
        return Err(InvokeError::InvalidArgs(format!(
            "{key} must be a non-empty array"
        )));
    }

    let mut uniq = BTreeSet::new();
    for value in values {
        let id = value
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|v| *v > 0)
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must contain positive integers"))
            })?;
        uniq.insert(id);
    }
    Ok(uniq.into_iter().collect())
}

pub(crate) fn parse_optional_i32(arguments: &Value, key: &str) -> Result<Option<i32>, InvokeError> {
    match arguments.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|v| *v > 0)
            .map(Some)
            .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a positive integer"))),
    }
}

pub(crate) fn parse_optional_usize(
    arguments: &Value,
    key: &str,
) -> Result<Option<usize>, InvokeError> {
    match arguments.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_u64()
            .and_then(|v| usize::try_from(v).ok())
            .filter(|v| *v > 0)
            .map(Some)
            .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a positive integer"))),
    }
}

pub(crate) fn parse_optional_zero_based_usize(
    arguments: &Value,
    key: &str,
) -> Result<Option<usize>, InvokeError> {
    match arguments.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_u64()
            .and_then(|v| usize::try_from(v).ok())
            .map(Some)
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must be a non-negative integer"))
            }),
    }
}

pub(crate) fn parse_optional_string_array(
    arguments: &Value,
    key: &str,
) -> Result<Option<Vec<String>>, InvokeError> {
    let Some(values) = arguments.get(key) else {
        return Ok(None);
    };
    let values = values
        .as_array()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be an array of strings")))?;
    if values.is_empty() {
        return Ok(Some(Vec::new()));
    }
    let mut out = Vec::with_capacity(values.len());
    for value in values {
        let item = value
            .as_str()
            .map(str::trim)
            .filter(|v| !v.is_empty())
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must be an array of strings"))
            })?;
        out.push(item.to_string());
    }
    Ok(Some(out))
}

pub(crate) fn parse_optional_i32_array(
    arguments: &Value,
    key: &str,
) -> Result<Option<Vec<i32>>, InvokeError> {
    let Some(values) = arguments.get(key) else {
        return Ok(None);
    };
    let values = values
        .as_array()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be an array")))?;
    let mut uniq = BTreeSet::new();
    for value in values {
        let id = value
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|v| *v > 0)
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must contain positive integers"))
            })?;
        uniq.insert(id);
    }
    Ok(Some(uniq.into_iter().collect()))
}

pub(crate) fn apply_text_window(
    text: &str,
    line_start: Option<usize>,
    line_end: Option<usize>,
    max_chars: Option<usize>,
) -> String {
    let mut sliced = if line_start.is_some() || line_end.is_some() {
        let lines: Vec<&str> = text.lines().collect();
        let start = line_start.unwrap_or(1).saturating_sub(1);
        let end = line_end.unwrap_or(lines.len());
        if start >= lines.len() || end == 0 || start >= end {
            String::new()
        } else {
            lines[start..end.min(lines.len())].join("\n")
        }
    } else {
        text.to_string()
    };

    if let Some(max) = max_chars.filter(|v| *v > 0) {
        if sliced.chars().count() > max {
            sliced = sliced.chars().take(max).collect();
        }
    }
    sliced
}

pub(crate) fn select_object_fields(value: &Value, fields: &[String]) -> Value {
    let Some(obj) = value.as_object() else {
        return value.clone();
    };
    let mut out = serde_json::Map::new();
    for field in fields {
        if let Some(entry) = obj.get(field) {
            out.insert(field.clone(), entry.clone());
        }
    }
    Value::Object(out)
}

#[cfg(test)]
mod tests {
    use super::apply_text_window;

    #[test]
    fn apply_text_window_slices_lines() {
        let text = "a\nb\nc\nd";
        assert_eq!(apply_text_window(text, Some(2), Some(4), None), "b\nc\nd");
    }

    #[test]
    fn apply_text_window_clamps_chars() {
        assert_eq!(apply_text_window("abcdef", None, None, Some(3)), "abc");
    }
}
