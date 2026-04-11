//! `PATCH` / `DELETE` project asset by stable numeric ids.

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, PgPool};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};
use crate::state::AppState;

use super::super::models::*;
use super::resolve::ensure_owned_project_pk;

fn parse_asset_type_patch(v: Option<Value>) -> Result<FieldPatch<String>, ApiError> {
    let p = parse_optional_text_field(v, "asset_type")?;
    match &p {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Err(ApiError::BadRequest(
            "asset_type cannot be null; omit or set role|tool|scene".into(),
        )),
        FieldPatch::Set(Some(s)) => {
            let t = s.trim().to_lowercase();
            if t != "role" && t != "tool" && t != "scene" {
                return Err(ApiError::BadRequest(
                    "asset_type must be role, tool, or scene".into(),
                ));
            }
            Ok(FieldPatch::Set(Some(t)))
        }
    }
}

fn merge_metadata_image_id(mut meta: Value, patch: &FieldPatch<i32>) -> Value {
    if !meta.is_object() {
        meta = Value::Object(Default::default());
    }
    if let Some(obj) = meta.as_object_mut() {
        match patch {
            FieldPatch::Absent => {}
            FieldPatch::Set(None) => {
                obj.remove("imageId");
            }
            FieldPatch::Set(Some(n)) => {
                obj.insert("imageId".into(), serde_json::json!(n));
            }
        }
    }
    meta
}

async fn cover_numeric_image_exists_for_asset(
    pool: &PgPool,
    asset_id: Uuid,
    numeric_image_id: i32,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
          SELECT 1 FROM app_asset_image
          WHERE asset_id = $1 AND numeric_image_id = $2
        )
        "#,
    )
    .bind(asset_id)
    .bind(numeric_image_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}

async fn patch_project_asset_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    asset_numeric_id: i32,
    body: PatchAssetBody,
) -> Result<Json<AssetRow>, ApiError> {
    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let desc_patch = parse_optional_text_field(body.description, "description")?;
    let type_patch = parse_asset_type_patch(body.asset_type)?;
    let cover_patch =
        parse_optional_i32_field(body.cover_numeric_image_id, "cover_numeric_image_id")?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(desc_patch, FieldPatch::Absent)
        && matches!(type_patch, FieldPatch::Absent)
        && matches!(cover_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, description, asset_type, cover_numeric_image_id"
                .into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetPatchCurrent>(
        r#"
        SELECT a.id, a.name, a.asset_type, a.description, a.metadata
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if let FieldPatch::Set(Some(leg)) = &cover_patch {
        if !cover_numeric_image_exists_for_asset(pool, current.id, *leg).await? {
            return Err(ApiError::BadRequest(
                "cover_numeric_image_id must match an app_asset_image row for this asset".into(),
            ));
        }
    }

    let new_metadata = merge_metadata_image_id(current.metadata.0.clone(), &cover_patch);

    let new_name = match &name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v.clone().unwrap_or_default(),
    };
    if new_name.trim().is_empty() {
        return Err(ApiError::BadRequest("name cannot be empty".into()));
    }

    let new_desc = match &desc_patch {
        FieldPatch::Absent => current.description.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    let new_type = match &type_patch {
        FieldPatch::Absent => current.asset_type.clone(),
        FieldPatch::Set(Some(t)) => t.clone(),
        FieldPatch::Set(None) => {
            return Err(ApiError::BadRequest(
                "asset_type cannot be null; omit or set role|tool|scene".into(),
            ));
        }
    };

    if matches!(&name_patch, FieldPatch::Set(_)) && new_name != current.name {
        let clash: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_asset a
              INNER JOIN app_project p ON p.id = a.project_id
              WHERE p.id = $1
                AND p.owner_user_id = $2
                AND a.name = $3
                AND a.numeric_id <> $4
            )
            "#,
        )
        .bind(project_id)
        .bind(uid)
        .bind(&new_name)
        .bind(asset_numeric_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if clash {
            return Err(ApiError::Conflict(
                "another asset in this project already uses that name".into(),
            ));
        }
    }

    let row = sqlx::query_as::<_, AssetRow>(
        r#"
        UPDATE app_asset a
        SET name = $1,
            description = $2,
            asset_type = $3,
            metadata = $4,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.id = $5
          AND p.owner_user_id = $6
          AND a.numeric_id = $7
        RETURNING a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_desc)
    .bind(&new_type)
    .bind(SqlxJson(new_metadata))
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

pub(crate) async fn patch_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
    Json(body): Json<PatchAssetBody>,
) -> Result<Json<AssetRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    patch_project_asset_inner(pool, uid, project_id, asset_numeric_id, body).await
}

async fn delete_project_asset_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    asset_numeric_id: i32,
) -> Result<StatusCode, ApiError> {
    if asset_numeric_id <= 0 {
        return Err(ApiError::BadRequest("numeric ids must be positive".into()));
    }

    let res = sqlx::query(
        r#"
        DELETE FROM app_asset a
        USING app_project p
        WHERE a.project_id = p.id
          AND p.id = $1
          AND p.owner_user_id = $2
          AND a.numeric_id = $3
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(asset_numeric_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}

pub(crate) async fn delete_project_asset_for_project(
    State(state): State<AppState>,
    Path((project_id, asset_numeric_id)): Path<(Uuid, i32)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    ensure_owned_project_pk(pool, uid, project_id).await?;
    delete_project_asset_inner(pool, uid, project_id, asset_numeric_id).await
}
