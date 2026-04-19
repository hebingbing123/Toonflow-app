use serde_json::{json, Value};

use crate::harness::invoke::domain_script::require_owned_script_scope;
use crate::harness::invoke::{
    parse_i32_required, project_numeric_from_ctx, require_pool, script_numeric_id_from_args_or_ctx,
    InvokeError,
};
use crate::harness::HarnessContext;

pub(crate) async fn invoke_del_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
    let assets_id = parse_i32_required(arguments, "assetsId")?;
    let derive_id = parse_i32_required(arguments, "id")?;

    let derive_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
          AND a.numeric_id = $3
          AND COALESCE((a.metadata ->> 'assetsId')::int, 0) = $4
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .bind(derive_id)
    .bind(assets_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext("derived asset not found under the specified parent".into())
    })?;

    sqlx::query(r#"DELETE FROM app_asset WHERE id = $1"#)
        .bind(derive_uuid)
        .execute(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": derive_id,
        "assetsId": assets_id,
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "deleted": true,
    }))
}
