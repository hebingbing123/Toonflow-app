//! Job / production helpers for enforced model routing.

use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::JobRunError;
use crate::llm::LlmConfig;
use crate::state::AppState;

use super::credentials::build_llm_config_for_model;
use super::resolver::{is_model_routing_enforced, resolve_model_id, ResolveInput};
use super::types::{ModelSlot, StudioStepSlug};

pub(crate) async fn load_project_uuid_for_actor(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
) -> Result<Option<Uuid>, JobRunError> {
    let row: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id
        FROM app_project
        WHERE numeric_id = $2
          AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = app_project.workspace_id
                  AND wm.user_id = $1
          )
        "#,
    )
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;
    Ok(row)
}

/// When routing is enforced, resolve project step model and build `LlmConfig`; otherwise `None`.
pub(crate) async fn try_build_routed_llm_config(
    state: &AppState,
    pool: &PgPool,
    owner_user_id: Uuid,
    project_id: Uuid,
    step: StudioStepSlug,
    slot: ModelSlot,
    request_override: Option<&str>,
) -> Result<Option<LlmConfig>, JobRunError> {
    if !is_model_routing_enforced() {
        return Ok(None);
    }
    let resolved = resolve_model_id(ResolveInput {
        state,
        pool,
        actor_user_id: owner_user_id,
        project_id: Some(project_id),
        step,
        slot,
        request_override,
    })
    .await
    .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    let cfg = build_llm_config_for_model(state, pool, owner_user_id, &resolved.model_id)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    Ok(Some(cfg))
}

/// Resolved catalog composite id when routing is enforced.
pub(crate) async fn try_resolve_enforced_model_id(
    state: &AppState,
    pool: &PgPool,
    owner_user_id: Uuid,
    project_id: Uuid,
    step: StudioStepSlug,
    slot: ModelSlot,
    request_override: Option<&str>,
) -> Result<Option<String>, JobRunError> {
    if !is_model_routing_enforced() {
        return Ok(None);
    }
    let resolved = resolve_model_id(ResolveInput {
        state,
        pool,
        actor_user_id: owner_user_id,
        project_id: Some(project_id),
        step,
        slot,
        request_override,
    })
    .await
    .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    Ok(Some(resolved.model_id))
}

/// Image job model: project routing when enforced, else payload `model`.
pub(crate) async fn resolve_job_image_model_id(
    state: &AppState,
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    step: StudioStepSlug,
    payload_model: &str,
) -> Result<String, JobRunError> {
    let Some(project_uuid) =
        load_project_uuid_for_actor(pool, owner_user_id, project_numeric_id).await?
    else {
        return Ok(payload_model.to_string());
    };
    if let Some(id) = try_resolve_enforced_model_id(
        state,
        pool,
        owner_user_id,
        project_uuid,
        step,
        ModelSlot::Image,
        Some(payload_model),
    )
    .await?
    {
        return Ok(id);
    }
    Ok(payload_model.to_string())
}

/// `LlmConfig` for image jobs: Studio routing → catalog composite in payload → server env.
pub(crate) async fn resolve_asset_image_llm_config(
    state: &AppState,
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    step: StudioStepSlug,
    payload_model: &str,
) -> Result<LlmConfig, JobRunError> {
    if let Some(project_uuid) =
        load_project_uuid_for_actor(pool, owner_user_id, project_numeric_id).await?
    {
        if let Some(cfg) = try_build_routed_llm_config(
            state,
            pool,
            owner_user_id,
            project_uuid,
            step,
            ModelSlot::Image,
            Some(payload_model),
        )
        .await?
        {
            return Ok(cfg);
        }
    }

    let trimmed = payload_model.trim();
    if trimmed.contains(':') {
        if let Ok(cfg) = build_llm_config_for_model(state, pool, owner_user_id, trimmed).await {
            return Ok(cfg);
        }
    }

    state.llm.clone().ok_or_else(|| {
        JobRunError::Failed(
            "LLM not configured — add an API key under Settings → Model providers or set OPENAI_API_KEY"
                .into(),
        )
    })
}
