use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::audit::{append_project_audit, AppendProjectAudit};
use crate::settings::agent_memory::ensure_project_style_bible_template;
use crate::state::AppState;
use crate::workspaces::ensure_personal_workspace;

use super::super::super::common::{trim_opt, ADV_LOCK_PROJECT_NUMERIC_ID};
use super::super::super::types::{CreateProjectBody, ProjectRow};
use super::super::super::validation::{
    validate_duration_strategy, validate_mode, validate_quality_gate_strategy,
    validate_target_market, validate_target_platforms,
};

#[utoipa::path(
    post,
    path = "/api/v1/projects",
    operation_id = "createProjectV1",
    tag = "projects",
    request_body = CreateProjectBody,
    responses(
        (status = 201, description = "Created", body = ProjectRow),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateProjectBody>,
) -> Result<(StatusCode, Json<ProjectRow>), ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let personal = ensure_personal_workspace(pool, uid).await?;

    let scope_workspace_id = if let Some(requested_workspace_id) = body.workspace_id {
        let row: Option<(uuid::Uuid, Option<chrono::DateTime<chrono::Utc>>)> = sqlx::query_as(
            r#"
            SELECT w.id, w.archived_at
            FROM public.app_workspace w
            INNER JOIN public.app_workspace_member m ON m.workspace_id = w.id
            WHERE w.id = $1 AND m.user_id = $2
            LIMIT 1
            "#,
        )
        .bind(requested_workspace_id)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        let Some((workspace_id, archived_at)) = row else {
            return Err(ApiError::Forbidden(
                "not a member of the target workspace".into(),
            ));
        };
        if archived_at.is_some() {
            return Err(ApiError::BadRequest(
                "cannot create project in archived workspace".into(),
            ));
        }
        workspace_id
    } else {
        sqlx::query_scalar(
            r#"
            SELECT COALESCE(
              (
                SELECT p.current_workspace_id
                FROM public.app_user_profile p
                INNER JOIN public.app_workspace w ON w.id = p.current_workspace_id
                WHERE p.user_id = $1
                  AND p.current_workspace_id IS NOT NULL
                  AND w.archived_at IS NULL
                  AND EXISTS (
                    SELECT 1
                    FROM public.app_workspace_member m
                    WHERE m.workspace_id = p.current_workspace_id
                      AND m.user_id = $1
                  )
                LIMIT 1
              ),
              $2
            ) AS workspace_id
            "#,
        )
        .bind(uid)
        .bind(personal.workspace_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    let target_platforms = body.target_platforms.as_ref().map(|platforms| {
        platforms
            .iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
    });

    // Validate enum fields if provided
    if let Some(ref mode_val) = body.mode {
        validate_mode(mode_val)?;
    }
    if let Some(ref market_val) = body.target_market {
        validate_target_market(market_val)?;
    }
    if let Some(ref strategy_val) = body.duration_strategy {
        validate_duration_strategy(strategy_val)?;
    }
    if let Some(ref platforms) = target_platforms {
        validate_target_platforms(platforms)?;
    }
    let quality_gate_strategy = trim_opt(body.quality_gate_strategy);
    if let Some(ref strategy_val) = quality_gate_strategy {
        validate_quality_gate_strategy(strategy_val)?;
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_PROJECT_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_project
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        INSERT INTO app_project (
          owner_user_id, workspace_id, numeric_id, name, intro, project_type,
          image_model, image_quality, video_model, art_style,
          director_manual, mode, video_ratio, create_time_ms, metadata,
          project_brief, brand_bible,
          art_style_pack, story_style_pack,
          target_market, target_platforms, duration_strategy,
          voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, '{}'::jsonb, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25)
        RETURNING id, workspace_id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack,
                  target_market, target_platforms, duration_strategy,
                  voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
                  'inherited' AS project_access_mode,
                  'project_owner' AS project_access_role
        "#,
    )
    .bind(uid)
    .bind(scope_workspace_id)
    .bind(next_numeric_id)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.intro))
    .bind(trim_opt(body.project_type))
    .bind(trim_opt(body.image_model))
    .bind(trim_opt(body.image_quality))
    .bind(trim_opt(body.video_model))
    .bind(trim_opt(body.art_style))
    .bind(trim_opt(body.director_manual))
    .bind(trim_opt(body.mode))
    .bind(trim_opt(body.video_ratio))
    .bind(now_ms)
    .bind(
        body.project_brief
            .as_ref()
            .map(serde_json::to_value)
            .transpose()
            .map_err(|e| ApiError::BadRequest(format!("invalid projectBrief: {e}")))?,
    )
    .bind(
        body.brand_bible
            .as_ref()
            .map(serde_json::to_value)
            .transpose()
            .map_err(|e| ApiError::BadRequest(format!("invalid brandBible: {e}")))?,
    )
    .bind(trim_opt(body.art_style_pack))
    .bind(trim_opt(body.story_style_pack))
    .bind(trim_opt(body.target_market))
    .bind(target_platforms)
    .bind(trim_opt(body.duration_strategy))
    .bind(trim_opt(body.voice_profile))
    .bind(trim_opt(body.subtitle_style))
    .bind(trim_opt(body.bgm_strategy))
    .bind(&quality_gate_strategy)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_project_audit(
        &mut *tx,
        AppendProjectAudit {
            project_id: row.id,
            workspace_id: scope_workspace_id,
            project_numeric_id: Some(row.numeric_id),
            actor_user_id: uid,
            action: "project_created",
            target_user_id: None,
            details: serde_json::json!({
                "project_name": row.name.clone(),
                "project_numeric_id": row.numeric_id,
                "workspace_id": scope_workspace_id,
            }),
        },
    )
    .await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let pool_hook = pool.clone();
    let http_hook = state.http_client.clone();
    let hook_owner = uid;
    let hook_workspace = scope_workspace_id;
    let hook_project = row.clone();
    tokio::spawn(async move {
        match serde_json::to_value(&hook_project) {
            Ok(project_json) => {
                if let Err(e) =
                    crate::settings::outbound_webhooks::fire_project_created_outbound_webhooks(
                        &pool_hook,
                        &http_hook,
                        hook_owner,
                        hook_workspace,
                        project_json,
                    )
                    .await
                {
                    tracing::warn!(
                        error = %e,
                        user_id = %hook_owner,
                        "project.created outbound webhooks failed"
                    );
                }
            }
            Err(e) => tracing::warn!(
                error = %e,
                user_id = %hook_owner,
                "serialize project row for outbound webhooks failed"
            ),
        }
    });

    let pool = pool.clone();
    tokio::spawn(async move {
        if let Err(error) = ensure_project_style_bible_template(&pool, uid, row.numeric_id).await {
            tracing::warn!(
                project_id = row.numeric_id,
                user_id = %uid,
                error = ?error,
                "style bible template auto-init failed"
            );
        }
    });

    Ok((StatusCode::CREATED, Json(row)))
}
