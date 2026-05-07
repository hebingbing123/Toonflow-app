use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::dto::{ListNovelsQuery, ListNovelsResponse, NovelRow};
use super::super::MAX_NOVEL_LIST_LIMIT;

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

fn search_ilike(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(format!("%{t}%"))
        }
    })
}

fn exact_filter(raw: Option<String>) -> Option<String> {
    raw.and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

fn validate_intake_status(value: &str) -> Result<(), ApiError> {
    match value {
        "draft" | "pending_review" | "admitted" | "rejected" => Ok(()),
        _ => Err(ApiError::BadRequest(
            "intake_status must be one of draft, pending_review, admitted, rejected".into(),
        )),
    }
}

async fn count_novels_filtered(
    pool: &PgPool,
    project_id: Uuid,
    uid: Uuid,
    search_pat: Option<&str>,
    intake_status: Option<&str>,
    intake_source: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT COUNT(*)::BIGINT
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = "#,
    );
    qb.push_bind(project_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND n.chapter ILIKE ");
        qb.push_bind(pat);
    }
    if let Some(status) = intake_status {
        qb.push(" AND n.metadata->>'intakeStatus' = ");
        qb.push_bind(status);
    }
    if let Some(source) = intake_source {
        qb.push(" AND n.metadata->>'intakeSource' = ");
        qb.push_bind(source);
    }
    let total: i64 = qb
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(total)
}

async fn select_novels_filtered(
    pool: &PgPool,
    project_id: Uuid,
    uid: Uuid,
    search_pat: Option<&str>,
    intake_status: Option<&str>,
    intake_source: Option<&str>,
    limit_offset: Option<(i64, i64)>,
) -> Result<Vec<NovelRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = QueryBuilder::new(
        r#"
        SELECT n.id, n.numeric_id, n.chapter_index, n.reel, n.chapter, n.chapter_data,
               n.event, n.event_state, n.error_reason, n.create_time_ms,
               n.metadata->>'intakeSource' AS intake_source,
               n.metadata->>'intakeSourceUrl' AS intake_source_url,
               n.metadata->>'intakeStatus' AS intake_status,
               n.metadata->>'intakeNote' AS intake_note
        FROM app_novel n
        INNER JOIN app_project p ON p.id = n.project_id
        WHERE p.id = "#,
    );
    qb.push_bind(project_id);
    qb.push(" AND p.owner_user_id = ");
    qb.push_bind(uid);
    if let Some(pat) = search_pat {
        qb.push(" AND n.chapter ILIKE ");
        qb.push_bind(pat);
    }
    if let Some(status) = intake_status {
        qb.push(" AND n.metadata->>'intakeStatus' = ");
        qb.push_bind(status);
    }
    if let Some(source) = intake_source {
        qb.push(" AND n.metadata->>'intakeSource' = ");
        qb.push_bind(source);
    }
    qb.push(" ORDER BY n.chapter_index ASC, n.numeric_id ASC ");
    if let Some((lim, off)) = limit_offset {
        qb.push(" LIMIT ");
        qb.push_bind(lim);
        qb.push(" OFFSET ");
        qb.push_bind(off);
    }
    qb.build_query_as::<NovelRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn list_novels_inner(
    pool: &PgPool,
    uid: Uuid,
    project_id: Uuid,
    query: ListNovelsQuery,
) -> Result<Json<ListNovelsResponse>, ApiError> {
    let search_pat = search_ilike(query.search);
    let search_ref = search_pat.as_deref();
    let intake_status = exact_filter(query.intake_status);
    let intake_status_ref = intake_status.as_deref();
    let intake_source = exact_filter(query.intake_source);
    let intake_source_ref = intake_source.as_deref();

    if let Some(status) = intake_status_ref {
        validate_intake_status(status)?;
    }

    let limit_clamped = match query.limit {
        None => None,
        Some(0) => {
            return Err(ApiError::BadRequest(
                "limit must be positive or omitted".into(),
            ));
        }
        Some(l) => Some(i64::from(l).min(MAX_NOVEL_LIST_LIMIT)),
    };

    if query.page.is_some() && limit_clamped.is_none() {
        let p = query.page.unwrap_or(1);
        if p != 1 {
            return Err(ApiError::BadRequest(
                "page is only valid together with limit".into(),
            ));
        }
    }

    let page = query.page.unwrap_or(1);
    if page == 0 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }

    let limit_offset = limit_clamped.map(|lim| {
        let off = i64::from(page.saturating_sub(1)) * lim;
        (lim, off)
    });

    let (items, total) = if limit_offset.is_some() {
        let total = count_novels_filtered(
            pool,
            project_id,
            uid,
            search_ref,
            intake_status_ref,
            intake_source_ref,
        )
        .await?;
        let items = select_novels_filtered(
            pool,
            project_id,
            uid,
            search_ref,
            intake_status_ref,
            intake_source_ref,
            limit_offset,
        )
        .await?;
        (items, total)
    } else {
        let items = select_novels_filtered(
            pool,
            project_id,
            uid,
            search_ref,
            intake_status_ref,
            intake_source_ref,
            None,
        )
        .await?;
        let total = items.len() as i64;
        (items, total)
    };

    Ok(Json(ListNovelsResponse { items, total }))
}

pub(crate) async fn list_novels_for_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListNovelsQuery>,
    headers: HeaderMap,
) -> Result<Json<ListNovelsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    ensure_owned_project_pk(pool, uid, project_id).await?;
    list_novels_inner(pool, uid, project_id, query).await
}
