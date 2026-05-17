//! Project character CRUD with structured `voice_config` (F.2).

use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, conflict_i18n, validate_non_empty_string, ApiError};
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::short_video::voice::parse_voice_json_value;
use crate::state::AppState;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ProjectCharacterRow {
    pub id: Uuid,
    pub project_id: Uuid,
    pub name: String,
    pub asset_id: Option<Uuid>,
    pub voice_config: Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreateProjectCharacterBody {
    pub name: String,
    #[serde(default)]
    pub asset_id: Option<Uuid>,
    #[serde(default)]
    pub voice_config: Value,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct PatchProjectCharacterBody {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub asset_id: Option<Option<Uuid>>,
    #[serde(default)]
    pub voice_config: Option<Value>,
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/characters",
    tag = "projects",
    responses((status = 200, description = "OK", body = Vec<ProjectCharacterRow>)),
    security(("bearerAuth" = []))
)]
pub async fn list_project_characters(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Vec<ProjectCharacterRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let pool = state.require_pool()?;
    let rows = sqlx::query_as::<_, ProjectCharacterRow>(
        r#"
        SELECT id, project_id, name, asset_id, voice_config, created_at, updated_at
        FROM app_project_character
        WHERE project_id = $1
        ORDER BY name ASC
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/characters",
    tag = "projects",
    request_body = CreateProjectCharacterBody,
    responses((status = 201, description = "Created", body = ProjectCharacterRow)),
    security(("bearerAuth" = []))
)]
pub async fn create_project_character(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateProjectCharacterBody>,
) -> Result<(StatusCode, Json<ProjectCharacterRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let pool = state.require_pool()?;
    let name = body.name.trim();
    validate_non_empty_string(name, "name")?;
    if let Some(asset_id) = body.asset_id {
        ensure_asset_in_project(pool, project_id, asset_id).await?;
    }
    let _ = parse_voice_json_value(&body.voice_config);
    let row = sqlx::query_as::<_, ProjectCharacterRow>(
        r#"
        INSERT INTO app_project_character (project_id, name, asset_id, voice_config)
        VALUES ($1, $2, $3, $4)
        RETURNING id, project_id, name, asset_id, voice_config, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(name)
    .bind(body.asset_id)
    .bind(body.voice_config)
    .fetch_one(pool)
    .await
    .map_err(map_character_db_error)?;
    Ok((StatusCode::CREATED, Json(row)))
}

#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/characters/{character_id}",
    tag = "projects",
    request_body = PatchProjectCharacterBody,
    responses((status = 200, description = "OK", body = ProjectCharacterRow)),
    security(("bearerAuth" = []))
)]
pub async fn patch_project_character(
    State(state): State<AppState>,
    Path((project_id, character_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchProjectCharacterBody>,
) -> Result<Json<ProjectCharacterRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let pool = state.require_pool()?;
    let current = fetch_character(pool, project_id, character_id).await?;
    let name = body
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .unwrap_or(current.name);
    let asset_id = match body.asset_id {
        None => current.asset_id,
        Some(None) => None,
        Some(Some(id)) => {
            ensure_asset_in_project(pool, project_id, id).await?;
            Some(id)
        }
    };
    let voice_config = body.voice_config.unwrap_or(current.voice_config);
    let _ = parse_voice_json_value(&voice_config);
    let row = sqlx::query_as::<_, ProjectCharacterRow>(
        r#"
        UPDATE app_project_character
        SET name = $3, asset_id = $4, voice_config = $5, updated_at = NOW()
        WHERE project_id = $1 AND id = $2
        RETURNING id, project_id, name, asset_id, voice_config, created_at, updated_at
        "#,
    )
    .bind(project_id)
    .bind(character_id)
    .bind(name)
    .bind(asset_id)
    .bind(voice_config)
    .fetch_one(pool)
    .await
    .map_err(map_character_db_error)?;
    Ok(Json(row))
}

#[utoipa::path(
    delete,
    path = "/api/v1/projects/{project_id}/characters/{character_id}",
    tag = "projects",
    responses((status = 204, description = "Deleted")),
    security(("bearerAuth" = []))
)]
pub async fn delete_project_character(
    State(state): State<AppState>,
    Path((project_id, character_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;
    let pool = state.require_pool()?;
    let res = sqlx::query("DELETE FROM app_project_character WHERE project_id = $1 AND id = $2")
        .bind(project_id)
        .bind(character_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn fetch_character(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    character_id: Uuid,
) -> Result<ProjectCharacterRow, ApiError> {
    sqlx::query_as::<_, ProjectCharacterRow>(
        r#"
        SELECT id, project_id, name, asset_id, voice_config, created_at, updated_at
        FROM app_project_character
        WHERE project_id = $1 AND id = $2
        "#,
    )
    .bind(project_id)
    .bind(character_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

async fn ensure_asset_in_project(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    asset_id: Uuid,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_asset WHERE id = $1 AND project_id = $2)",
    )
    .bind(asset_id)
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ok {
        return Err(bad_request_i18n(
            "asset_id does not belong to project",
            "asset_id 不属于该 project",
        ));
    }
    Ok(())
}

fn map_character_db_error(err: sqlx::Error) -> ApiError {
    if let sqlx::Error::Database(db) = &err {
        if db.code().as_deref() == Some("23505") {
            return conflict_i18n(
                "character name already exists in project",
                "项目内角色名称已存在",
            );
        }
    }
    ApiError::DatabaseError(err.to_string())
}
