use serde_json::Value;

use super::super::{
    project_numeric_from_ctx, require_pool, script_numeric_id_from_args_or_ctx, InvokeError,
};
use super::rows::HarnessScriptRow;
use crate::harness::HarnessContext;
use crate::scope::ScopeError;

pub(crate) async fn invoke_get_script_content(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;

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

    serde_json::to_value(row)
        .map_err(|_| InvokeError::DatabaseError("failed to serialize script".into()))
}
