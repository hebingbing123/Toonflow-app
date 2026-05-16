use serde_json::{json, Value};

use crate::assets::ADV_LOCK_ASSET_NUMERIC;
use crate::harness::invoke::domain_script::require_owned_script_scope;
use crate::harness::invoke::{
    parse_i32_required, project_numeric_from_ctx, require_pool, script_numeric_id_from_args_or_ctx,
    InvokeError,
};
use crate::harness::HarnessContext;

#[derive(sqlx::FromRow)]
struct ParentAssetRow {
    asset_type: String,
}

pub(crate) async fn invoke_add_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
    let assets_id = parse_i32_required(arguments, "assetsId")?;
    let name = arguments
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("name must be a non-empty string".into()))?;
    let desc = arguments
        .get("desc")
        .and_then(Value::as_str)
        .map(str::trim)
        .ok_or_else(|| InvokeError::InvalidArgs("desc must be a string".into()))?;
    let maybe_numeric_id = arguments
        .get("id")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let parent = sqlx::query_as::<_, ParentAssetRow>(
        r#"
        SELECT a.asset_type
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE a.project_id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(scope.project_id)
    .bind(assets_id)
    .bind(scope.script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext(
            "parent asset not found or not linked to this script (app_script_asset)".into(),
        )
    })?;

    if let Some(numeric_id) = maybe_numeric_id {
        let updated = sqlx::query(
            r#"
            UPDATE app_asset a
            SET name = $4,
                description = $5,
                updated_at = NOW()
            FROM app_script_asset sa
            WHERE a.id = sa.asset_id
              AND sa.script_id = $6
              AND a.project_id = $1
              AND a.numeric_id = $2
              AND COALESCE((a.metadata ->> 'assetsId')::int, 0) = $3
            "#,
        )
        .bind(scope.project_id)
        .bind(numeric_id)
        .bind(assets_id)
        .bind(name)
        .bind(desc)
        .bind(scope.script_id)
        .execute(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

        if updated.rows_affected() == 0 {
            return Err(InvokeError::MissingContext(
                "derived asset not found under the specified parent".into(),
            ));
        }

        return Ok(json!({
            "id": numeric_id,
            "assetsId": assets_id,
            "name": name,
            "desc": desc,
            "projectId": project_numeric_id,
            "scriptId": script_numeric_id,
            "operation": "updated",
        }));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let new_id = uuid::Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO app_asset (
            id, project_id, numeric_id, name, asset_type, description, metadata
        )
        VALUES (
            $1, $2, $3, $4, $5, $6,
            jsonb_build_object('assetsId', $7, 'state', '未生成')
        )
        "#,
    )
    .bind(new_id)
    .bind(scope.project_id)
    .bind(next_numeric_id)
    .bind(name)
    .bind(parent.asset_type)
    .bind(desc)
    .bind(assets_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_script_asset (script_id, asset_id)
        VALUES ($1, $2)
        ON CONFLICT DO NOTHING
        "#,
    )
    .bind(scope.script_id)
    .bind(new_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": next_numeric_id,
        "assetsId": assets_id,
        "name": name,
        "desc": desc,
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "operation": "created",
    }))
}
