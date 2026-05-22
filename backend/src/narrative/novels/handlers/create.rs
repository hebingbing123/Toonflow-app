use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use serde_json::{Map, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{validate_enum, ApiError};
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::dto::{CreateNovelBody, NovelRow};
use super::super::ADV_LOCK_NOVEL_NUMERIC;

use super::list::{normalize_intake_source, trim_opt};

fn validate_intake_status(value: &str) -> Result<(), ApiError> {
    validate_enum(
        value,
        &["draft", "pending_review", "admitted", "rejected"],
        "intake_status",
    )
}

pub(super) fn build_novel_intake_metadata(
    intake_source: Option<String>,
    intake_source_url: Option<String>,
    intake_status: Option<String>,
    intake_note: Option<String>,
) -> Value {
    let mut metadata = Map::new();
    if let Some(value) = intake_source {
        metadata.insert("intakeSource".into(), Value::String(value));
    }
    if let Some(value) = intake_source_url {
        metadata.insert("intakeSourceUrl".into(), Value::String(value));
    }
    if let Some(value) = intake_status {
        metadata.insert("intakeStatus".into(), Value::String(value));
    }
    if let Some(value) = intake_note {
        metadata.insert("intakeNote".into(), Value::String(value));
    }
    Value::Object(metadata)
}

async fn create_novel_inner(
    pool: &PgPool,
    project_uuid: Uuid,
    body: CreateNovelBody,
) -> Result<(StatusCode, Json<NovelRow>), ApiError> {
    let chapter_index = body.chapter_index.unwrap_or(0);
    let reel = trim_opt(body.reel);
    let chapter = body.chapter.unwrap_or_default();
    let chapter_data = body.chapter_data.unwrap_or_default();
    let intake_source = trim_opt(body.intake_source);
    let intake_source_url = trim_opt(body.intake_source_url);
    let intake_status = trim_opt(body.intake_status);
    let intake_note = trim_opt(body.intake_note);

    if let Some(ref status) = intake_status {
        validate_intake_status(status)?;
    }

    let intake_source = if let Some(source) = intake_source {
        Some(normalize_intake_source(&source)?)
    } else {
        None
    };
    let metadata =
        build_novel_intake_metadata(intake_source, intake_source_url, intake_status, intake_note);

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_NOVEL_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_novel
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, NovelRow>(
        r#"
        INSERT INTO app_novel (
          project_id, numeric_id, chapter_index, reel, chapter, chapter_data,
          event, event_state, error_reason, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, NULL, 0, NULL, $7, $8)
        RETURNING id, numeric_id, chapter_index, reel, chapter, chapter_data,
                  event, event_state, error_reason, create_time_ms,
                  metadata->>'intakeSource' AS intake_source,
                  metadata->>'intakeSourceUrl' AS intake_source_url,
                  metadata->>'intakeStatus' AS intake_status,
                  metadata->>'intakeNote' AS intake_note
        "#,
    )
    .bind(project_uuid)
    .bind(next_numeric_id)
    .bind(chapter_index)
    .bind(reel.as_ref())
    .bind(&chapter)
    .bind(&chapter_data)
    .bind(now_ms)
    .bind(metadata)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
}

pub(crate) async fn create_novel_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateNovelBody>,
) -> Result<(StatusCode, Json<NovelRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    require_project_write_scope(&state, uid, project_id).await?;
    create_novel_inner(pool, project_id, body).await
}
