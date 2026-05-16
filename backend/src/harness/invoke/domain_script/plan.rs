use serde_json::Value;
use sqlx::types::Json;

use super::super::{
    apply_text_window, parse_optional_i32, parse_optional_string_array, parse_optional_usize,
    parse_optional_zero_based_usize, project_numeric_from_ctx, require_pool, select_object_fields,
    InvokeError,
};
use super::rows::HarnessScriptRow;
use crate::harness::HarnessContext;
use crate::scope::ScopeError;

pub(crate) async fn invoke_get_plan_data(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let key = arguments
        .get("key")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|v| !v.is_empty());
    let line_start = parse_optional_usize(arguments, "lineStart")?;
    let line_end = parse_optional_usize(arguments, "lineEnd")?;
    let max_chars = parse_optional_usize(arguments, "maxChars")?;
    let fields = parse_optional_string_array(arguments, "fields")?;
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = parse_optional_usize(arguments, "limit")?;
    let script_id = parse_optional_i32(arguments, "scriptId")?;

    let project_uuid =
        crate::scope::owned_project_id_by_numeric(pool, ctx.user_id, project_numeric_id)
            .await
            .map_err(|e| match e {
                ScopeError::NotFound => {
                    InvokeError::MissingContext("attached project is not accessible".into())
                }
                ScopeError::Database(msg) => InvokeError::DatabaseError(msg),
            })?;

    let plan_row: Option<(i64, Json<Value>)> = sqlx::query_as(
        r#"
        SELECT id, plan_data
        FROM app_script_agent_plan
        WHERE project_id = $1 AND owner_user_id = $2 AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(project_uuid)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let scripts: Vec<HarnessScriptRow> = sqlx::query_as(
        r#"
        SELECT s.numeric_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.numeric_id = $2
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        ORDER BY s.numeric_id
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let script_values = scripts
        .into_iter()
        .filter(|row| script_id.is_none_or(|id| row.numeric_id == id))
        .skip(offset)
        .take(limit.unwrap_or(usize::MAX))
        .map(|row| {
            let mut value = serde_json::to_value(row)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize scripts".into()))?;
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
        })
        .collect::<Result<Vec<_>, InvokeError>>()?;

    let mut data = plan_row
        .as_ref()
        .map(|(_, j)| j.0.clone())
        .unwrap_or_else(|| Value::Object(Default::default()));
    if let Some(obj) = data.as_object_mut() {
        obj.insert("script".into(), Value::Array(script_values.clone()));
    }

    if let Some(key) = key {
        return match key {
            "storySkeleton" | "adaptationStrategy" => {
                let text = data
                    .get(key)
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string();
                Ok(Value::String(apply_text_window(
                    &text, line_start, line_end, max_chars,
                )))
            }
            "script" => Ok(Value::Array(script_values)),
            _ => Err(InvokeError::InvalidArgs(format!(
                "unsupported plan key: {key}"
            ))),
        };
    }

    let mut body = serde_json::json!({
        "projectId": project_numeric_id,
        "agentType": "scriptAgent",
        "data": data,
    });
    if let Some((plan_id, _)) = plan_row {
        body.as_object_mut()
            .expect("get_planData body must be an object")
            .insert("planId".to_string(), serde_json::json!(plan_id));
    }
    Ok(body)
}
