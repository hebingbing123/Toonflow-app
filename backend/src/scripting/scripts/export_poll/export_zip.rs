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

use super::super::types::{ExportScriptsBody, MAX_SCRIPT_EXPORT};
use super::helpers::{build_scripts_zip, normalize_numeric_id_list};

pub(in crate::scripting::scripts) async fn export_scripts_zip(
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
        WHERE EXISTS (
          SELECT 1
          FROM app_workspace_member wm
          WHERE wm.workspace_id = p.workspace_id
            AND wm.user_id = "#,
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
