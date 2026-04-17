use serde_json::Value;

use crate::harness::HarnessContext;

use super::super::{
    map_api_error, project_numeric_from_ctx, require_pool, script_numeric_id_from_args_or_ctx,
    InvokeError,
};

pub(crate) async fn invoke_get_flow_data(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let key = arguments
        .get("key")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("key must be a non-empty string".into()))?;
    let mapped_key = if key == "stoaryTable" {
        "storyboardTable"
    } else {
        key
    };
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;

    let flow = crate::production::flow_data::load_owned_production_flow_json(
        pool,
        ctx.user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await
    .map_err(|e| map_api_error(e, "failed to read production flow data"))?;

    flow.get(mapped_key)
        .cloned()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("unsupported flow key: {key}")))
}
