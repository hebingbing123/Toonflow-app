use serde_json::Value;

use super::super::{
    apply_text_window, parse_optional_string_array, parse_optional_usize, project_numeric_from_ctx,
    require_pool, script_numeric_id_from_args_or_ctx, select_object_fields, InvokeError,
};
use super::rows::HarnessScriptRow;
use crate::harness::HarnessContext;
use crate::scope::ScopeError;

fn resolve_script_numeric_id(ctx: &HarnessContext, arguments: &Value) -> Result<i32, InvokeError> {
    let base_script_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let Some(relative_offset) = arguments.get("relativeOffset") else {
        return Ok(base_script_id);
    };
    let relative_offset = relative_offset
        .as_i64()
        .and_then(|value| i32::try_from(value).ok())
        .filter(|value| *value != 0)
        .ok_or_else(|| {
            InvokeError::InvalidArgs("relativeOffset must be a non-zero integer".into())
        })?;
    let resolved_script_id = base_script_id
        .checked_add(relative_offset)
        .filter(|value| *value > 0)
        .ok_or_else(|| {
            InvokeError::InvalidArgs(
                "relativeOffset resolves outside the valid script id range".into(),
            )
        })?;
    Ok(resolved_script_id)
}

pub(crate) async fn invoke_get_script_content(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let script_numeric_id = resolve_script_numeric_id(ctx, arguments)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let line_start = parse_optional_usize(arguments, "lineStart")?;
    let line_end = parse_optional_usize(arguments, "lineEnd")?;
    let max_chars = parse_optional_usize(arguments, "maxChars")?;
    let fields = parse_optional_string_array(arguments, "fields")?;

    let scope =
        crate::scope::owned_script_scope(pool, ctx.user_id, project_numeric_id, script_numeric_id)
            .await
            .map_err(|e| match e {
                ScopeError::NotFound => {
                    InvokeError::MissingContext("script not found in attached project".into())
                }
                ScopeError::Database(msg) => InvokeError::DatabaseError(msg),
            })?;

    let row: HarnessScriptRow = sqlx::query_as(
        r#"
        SELECT numeric_id, name, content, extract_state
        FROM app_script
        WHERE id = $1
        "#,
    )
    .bind(scope.script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let mut value = serde_json::to_value(row)
        .map_err(|_| InvokeError::DatabaseError("failed to serialize script".into()))?;
    if let Some(content) = value.get("content").and_then(Value::as_str) {
        let windowed = apply_text_window(content, line_start, line_end, max_chars);
        if let Some(obj) = value.as_object_mut() {
            obj.insert("content".into(), Value::String(windowed));
        }
    }
    if let Some(fields) = fields.as_ref() {
        value = select_object_fields(&value, fields);
    }
    Ok(value)
}

#[cfg(test)]
mod tests {
    use super::resolve_script_numeric_id;
    use crate::harness::HarnessContext;
    use serde_json::json;
    use uuid::Uuid;

    fn ctx(script_numeric_id: Option<i32>) -> HarnessContext {
        HarnessContext::with_runtime_scope(
            Uuid::nil(),
            None,
            None,
            script_numeric_id,
            None,
            None,
            None,
        )
    }

    #[test]
    fn resolve_script_numeric_id_uses_relative_offset_from_context() {
        let resolved =
            resolve_script_numeric_id(&ctx(Some(8)), &json!({"relativeOffset": -1})).unwrap();
        assert_eq!(resolved, 7);
    }

    #[test]
    fn resolve_script_numeric_id_prefers_explicit_script_id_as_base() {
        let resolved = resolve_script_numeric_id(
            &ctx(Some(8)),
            &json!({"scriptId": 12, "relativeOffset": -1}),
        )
        .unwrap();
        assert_eq!(resolved, 11);
    }

    #[test]
    fn resolve_script_numeric_id_rejects_zero_relative_offset() {
        let err =
            resolve_script_numeric_id(&ctx(Some(8)), &json!({"relativeOffset": 0})).unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }
}
