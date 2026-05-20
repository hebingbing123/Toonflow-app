//! `GET` / `PATCH` / `POST resolve` for project Studio step model routing.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::model_routing::store::{
    load_project_model_routing, merge_routing_patch, persist_model_routing, ProjectModelDefaults,
};
use crate::projects::model_routing::{resolve_all_effective, resolve_model_id};
use crate::projects::model_routing::{
    ModelRoutingDefaultsBody, ModelRoutingEffectiveEntry, ModelRoutingPatchBody,
    ModelRoutingResolveBody, ModelRoutingResolveResponse, ModelRoutingResponse, ModelSlot,
    ResolveInput, StudioStepSlug,
};
use crate::state::AppState;

use super::super::super::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};

fn defaults_body(d: &ProjectModelDefaults) -> ModelRoutingDefaultsBody {
    ModelRoutingDefaultsBody {
        text_model: d.text_model.clone(),
        multimodal_model: d.multimodal_model.clone(),
        image_model: d.image_model.clone(),
        video_model: d.video_model.clone(),
        voice_model: d.voice_model.clone(),
    }
}

fn normalize_optional_string(v: &Option<String>) -> Option<String> {
    v.as_ref().and_then(|s| {
        let t = s.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_string())
        }
    })
}

fn apply_defaults_patch(
    base: &ProjectModelDefaults,
    patch: &crate::projects::model_routing::ModelRoutingDefaultsPatch,
) -> ProjectModelDefaults {
    let mut row = base.clone();
    if let Some(v) = &patch.text_model {
        row.text_model = normalize_optional_string(v);
    }
    if let Some(v) = &patch.multimodal_model {
        row.multimodal_model = normalize_optional_string(v);
    }
    if let Some(v) = &patch.image_model {
        row.image_model = normalize_optional_string(v);
    }
    if let Some(v) = &patch.video_model {
        row.video_model = normalize_optional_string(v);
    }
    if let Some(v) = &patch.voice_model {
        row.voice_model = normalize_optional_string(v);
    }
    row
}

/// `GET /api/v1/projects/{project_id}/model-routing`
#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/model-routing",
    operation_id = "getProjectModelRoutingV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ModelRoutingResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_project_model_routing(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ModelRoutingResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let loaded = load_project_model_routing(pool, project_id).await?;
    let effective = resolve_all_effective(pool, uid, project_id, &state).await?;
    Ok(Json(ModelRoutingResponse {
        project_id,
        defaults: defaults_body(&loaded.defaults),
        steps: loaded.routing.steps.clone(),
        effective: effective
            .into_iter()
            .map(|r| ModelRoutingEffectiveEntry {
                step: r.step,
                slot: r.slot,
                model_id: r.model_id,
                source: r.source,
            })
            .collect(),
    }))
}

/// `PATCH /api/v1/projects/{project_id}/model-routing`
#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/model-routing",
    operation_id = "patchProjectModelRoutingV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = ModelRoutingPatchBody,
    responses(
        (status = 200, description = "OK", body = ModelRoutingResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_project_model_routing(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ModelRoutingPatchBody>,
) -> Result<Json<ModelRoutingResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    if body.defaults.is_none() && body.steps.is_none() {
        return Err(ApiError::BadRequest(
            "expected at least one of defaults or steps".into(),
        ));
    }

    let loaded = load_project_model_routing(pool, project_id).await?;

    if let Some(ref steps) = body.steps {
        for (step, slots) in steps {
            StudioStepSlug::parse(step)
                .ok_or_else(|| ApiError::BadRequest(format!("unknown studio step: {step}")))?;
            for (slot, model_id) in slots {
                ModelSlot::parse(slot)
                    .ok_or_else(|| ApiError::BadRequest(format!("unknown model slot: {slot}")))?;
                if !model_id.trim().is_empty() {
                    crate::vendor::catalog::lookup_detail(model_id.trim(), false).ok_or_else(
                        || ApiError::BadRequest(format!("unknown model_id: {model_id}")),
                    )?;
                }
            }
        }
    }

    let defaults_patch_merged = body
        .defaults
        .as_ref()
        .map(|p| apply_defaults_patch(&loaded.defaults, p));

    let (metadata, defaults, _routing) = merge_routing_patch(
        loaded.metadata_raw.clone(),
        defaults_patch_merged,
        body.steps.clone(),
        &loaded.defaults,
        &loaded.routing,
    );

    persist_model_routing(pool, project_id, &metadata, &defaults).await?;

    get_project_model_routing(State(state), Path(project_id), headers).await
}

/// `POST /api/v1/projects/{project_id}/model-routing/resolve`
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/model-routing/resolve",
    operation_id = "resolveProjectModelRoutingV1",
    tag = "projects",
    request_body = ModelRoutingResolveBody,
    responses(
        (status = 200, description = "OK", body = ModelRoutingResolveResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn resolve_project_model_routing(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ModelRoutingResolveBody>,
) -> Result<Json<ModelRoutingResolveResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let step = StudioStepSlug::parse(&body.step)
        .ok_or_else(|| ApiError::BadRequest(format!("unknown studio step: {}", body.step)))?;
    let slot = ModelSlot::parse(&body.slot)
        .ok_or_else(|| ApiError::BadRequest(format!("unknown model slot: {}", body.slot)))?;

    let resolved = resolve_model_id(ResolveInput {
        state: &state,
        pool,
        actor_user_id: uid,
        project_id: Some(project_id),
        step,
        slot,
        request_override: body.model_id.as_deref(),
    })
    .await?;

    Ok(Json(ModelRoutingResolveResponse {
        model_id: resolved.model_id,
        step: resolved.step,
        slot: resolved.slot,
        source: resolved.source,
    }))
}
