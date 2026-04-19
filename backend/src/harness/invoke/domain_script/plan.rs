use serde_json::Value;
use sqlx::types::Json;

use super::super::{project_numeric_from_ctx, require_pool, InvokeError};
use super::rows::HarnessScriptRow;
use crate::harness::HarnessContext;
use crate::scope::ScopeError;

pub(crate) async fn invoke_get_plan_data(ctx: &HarnessContext) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;

    let project_uuid =
        crate::scope::owned_project_id_by_numeric(pool, ctx.user_id, project_numeric_id)
            .await
            .map_err(|e| match e {
                ScopeError::NotFound => {
                    InvokeError::MissingContext("attached project is not owned or missing".into())
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
        WHERE p.owner_user_id = $1 AND p.numeric_id = $2
        ORDER BY s.numeric_id
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let mut data = plan_row
        .as_ref()
        .map(|(_, j)| j.0.clone())
        .unwrap_or_else(|| Value::Object(Default::default()));
    if let Some(obj) = data.as_object_mut() {
        obj.insert(
            "script".into(),
            serde_json::to_value(&scripts)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize scripts".into()))?,
        );
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
