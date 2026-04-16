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
