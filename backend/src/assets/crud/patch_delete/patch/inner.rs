//! `PATCH` project asset by stable numeric ids — domain logic.

use axum::Json;
use serde_json::Value;
use sqlx::{types::Json as SqlxJson, PgPool};
use uuid::Uuid;

use crate::assets::models::{AssetPatchCurrent, AssetRow, PatchAssetBody};
use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};

use super::super::helpers::{
    cover_numeric_image_exists_for_asset, merge_metadata_image_id, parse_asset_type_patch,
};

fn parse_candidate_status_patch(v: Option<Value>) -> Result<FieldPatch<String>, ApiError> {
    match v {
        None => Ok(FieldPatch::Absent),
        Some(Value::Null) => Ok(FieldPatch::Set(None)),
        Some(Value::String(s)) => {
            let t = s.trim().to_lowercase();
            if t.is_empty() {
                return Ok(FieldPatch::Set(None));
            }
            match t.as_str() {
                "pending" | "linked" | "ignored" => Ok(FieldPatch::Set(Some(t))),
                _ => Err(ApiError::BadRequest(
                    "candidate_status must be pending, linked, or ignored (or null to clear)"
                        .into(),
                )),
            }
        }
        _ => Err(ApiError::BadRequest(
            "candidate_status must be a string or null".into(),
        )),
    }
}

pub(super) async fn patch_project_asset_inner(
    pool: &PgPool,
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
    let candidate_patch = parse_candidate_status_patch(body.candidate_status)?;

    if matches!(name_patch, FieldPatch::Absent)
        && matches!(desc_patch, FieldPatch::Absent)
        && matches!(type_patch, FieldPatch::Absent)
        && matches!(cover_patch, FieldPatch::Absent)
        && matches!(candidate_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, description, asset_type, cover_numeric_image_id, candidate_status"
                .into(),
        ));
    }

    let current = sqlx::query_as::<_, AssetPatchCurrent>(
        r#"
        SELECT a.id, a.name, a.asset_type, a.description, a.metadata, a.candidate_status
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(project_id)
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

    let new_candidate_status = match &candidate_patch {
        FieldPatch::Absent => current.candidate_status.clone(),
        FieldPatch::Set(v) => v.clone(),
    };

    if matches!(&name_patch, FieldPatch::Set(_)) && new_name != current.name {
        let clash: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS (
              SELECT 1
              FROM app_asset a
              INNER JOIN app_project p ON p.id = a.project_id
              WHERE p.id = $1
                AND a.name = $2
                AND a.numeric_id <> $3
            )
            "#,
        )
        .bind(project_id)
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
            candidate_status = $5,
            updated_at = NOW()
        FROM app_project p
        WHERE a.project_id = p.id
          AND p.id = $6
          AND a.numeric_id = $7
        RETURNING a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms, a.candidate_status
        "#,
    )
    .bind(&new_name)
    .bind(&new_desc)
    .bind(&new_type)
    .bind(SqlxJson(new_metadata))
    .bind(&new_candidate_status)
    .bind(project_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}
