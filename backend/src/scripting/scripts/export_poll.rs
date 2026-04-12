//! Top-level script export (zip) and extract-state polling (`/api/v1/scripts/*`).

use axum::{
    body::Body,
    extract::State,
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::Response,
    Json,
};
use sqlx::{Postgres, QueryBuilder};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{
    ExportScriptsBody, ScriptExtractPollBody, ScriptExtractPollRow, MAX_SCRIPT_EXPORT,
    MAX_SCRIPT_EXTRACT_POLL,
};

pub(super) fn normalize_numeric_id_list(
    mut ids: Vec<i32>,
    max_len: usize,
) -> Result<Vec<i32>, ApiError> {
    ids.retain(|id| *id > 0);
    ids.sort_unstable();
    ids.dedup();
    if ids.is_empty() {
        return Err(ApiError::BadRequest(
            "numeric_ids must be non-empty (positive integers)".into(),
        ));
    }
    if ids.len() > max_len {
        return Err(ApiError::BadRequest(format!(
            "at most {max_len} numeric_ids per request"
        )));
    }
    Ok(ids)
}

pub(super) fn zip_entry_name(numeric_id: i32, name: Option<&str>) -> String {
    let base_raw = name
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("script");
    let safe: String = base_raw
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '\0' | '\r' | '\n' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .take(180)
        .collect();
    let base = if safe.is_empty() {
        "script"
    } else {
        safe.as_str()
    };
    format!("{numeric_id}_{base}.txt")
}

pub(super) fn build_scripts_zip(
    rows: Vec<(i32, Option<String>, Option<String>)>,
) -> Result<Vec<u8>, zip::result::ZipError> {
    use std::io::Write;
    use zip::write::FileOptions;
    use zip::{CompressionMethod, ZipWriter};

    let mut cursor = std::io::Cursor::new(Vec::new());
    {
        let mut zip = ZipWriter::new(&mut cursor);
        let options = FileOptions::default().compression_method(CompressionMethod::Deflated);
        for (numeric_id, name, content) in rows {
            let path = zip_entry_name(numeric_id, name.as_deref());
            zip.start_file(path, options)?;
            zip.write_all(content.unwrap_or_default().as_bytes())?;
        }
        zip.finish()?;
    }
    Ok(cursor.into_inner())
}

pub(super) async fn export_scripts_zip(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExportScriptsBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let numeric_ids = normalize_numeric_id_list(body.numeric_ids, MAX_SCRIPT_EXPORT)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT s.numeric_id, s.name, s.content
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(" AND s.numeric_id IN (");
    {
        let mut separated = qb.separated(", ");
        for id in &numeric_ids {
            separated.push_bind(*id);
        }
    }
    qb.push(") ORDER BY s.numeric_id");

    let rows: Vec<(i32, Option<String>, Option<String>)> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let bytes = tokio::task::spawn_blocking(move || build_scripts_zip(rows))
        .await
        .map_err(|e| {
            tracing::error!(error = %e, "scripts export zip task join");
            ApiError::Internal
        })?
        .map_err(|e: zip::result::ZipError| {
            tracing::error!(error = %e, "scripts export zip build");
            ApiError::Internal
        })?;

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, "application/zip")
        .header(
            header::CONTENT_DISPOSITION,
            HeaderValue::from_static("attachment; filename=\"scripts.zip\""),
        )
        .body(Body::from(bytes))
        .map_err(|e| {
            tracing::error!(error = %e, "scripts export response headers");
            ApiError::Internal
        })
}

pub(super) async fn poll_script_extract_state(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ScriptExtractPollBody>,
) -> Result<Json<Vec<ScriptExtractPollRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let numeric_ids = normalize_numeric_id_list(body.numeric_ids, MAX_SCRIPT_EXTRACT_POLL)?;

    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT s.numeric_id, s.extract_state, s.error_reason
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = "#,
    );
    qb.push_bind(uid);
    qb.push(" AND s.numeric_id IN (");
    {
        let mut separated = qb.separated(", ");
        for id in &numeric_ids {
            separated.push_bind(*id);
        }
    }
    qb.push(") AND (s.extract_state IS DISTINCT FROM 0) ORDER BY s.numeric_id");

    let rows: Vec<ScriptExtractPollRow> = qb
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
