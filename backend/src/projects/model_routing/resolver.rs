//! Resolve effective model id for project + studio step + slot.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::harness::ws::channel::WsAgentChannel;
use crate::settings::agent_deploy::load_agent_deploy_config;
use crate::vendor::catalog::{first_catalog_model_for_kind, lookup_detail};

use super::store::{load_project_model_routing, modality_default, ProjectModelRoutingState};
use super::types::{ModelSlot, ResolveSource, ResolvedModel, StudioStepSlug};

/// Parse `OPENFLOW_MODEL_ROUTING_ENFORCE` (unset => enforced).
#[must_use]
pub(crate) fn parse_model_routing_enforce(raw: Option<&str>) -> bool {
    match raw {
        Some(v) => {
            let t = v.trim().to_ascii_lowercase();
            !matches!(t.as_str(), "0" | "false" | "no" | "off")
        }
        None => true,
    }
}

/// When false, runtime consumers should keep legacy model selection (API still resolves).
#[must_use]
pub fn is_model_routing_enforced() -> bool {
    parse_model_routing_enforce(
        std::env::var("OPENFLOW_MODEL_ROUTING_ENFORCE")
            .ok()
            .as_deref(),
    )
}

pub struct ResolveInput<'a> {
    pub state: &'a super::super::super::state::AppState,
    pub pool: &'a PgPool,
    pub actor_user_id: Uuid,
    pub project_id: Option<Uuid>,
    pub step: StudioStepSlug,
    pub slot: ModelSlot,
    pub request_override: Option<&'a str>,
}

pub fn harness_channel_to_step_slot(channel: WsAgentChannel) -> (StudioStepSlug, ModelSlot) {
    match channel {
        WsAgentChannel::Script => (StudioStepSlug::Script, ModelSlot::Text),
        WsAgentChannel::Production => (StudioStepSlug::Storyboard, ModelSlot::Text),
    }
}

pub async fn resolve_model_id(input: ResolveInput<'_>) -> Result<ResolvedModel, ApiError> {
    if let Some(override_id) = input
        .request_override
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        validate_model_id(override_id)?;
        return Ok(ResolvedModel {
            model_id: override_id.to_string(),
            step: input.step.as_str().to_string(),
            slot: input.slot.as_str().to_string(),
            source: ResolveSource::RequestOverride,
        });
    }

    let Some(project_id) = input.project_id else {
        return resolve_without_project(input.pool, input.actor_user_id, input.step, input.slot)
            .await;
    };

    let loaded = load_project_model_routing(input.pool, project_id).await?;
    resolve_from_state(
        input.pool,
        input.actor_user_id,
        input.step,
        input.slot,
        &loaded,
    )
    .await
}

async fn resolve_without_project(
    pool: &PgPool,
    actor_user_id: Uuid,
    step: StudioStepSlug,
    slot: ModelSlot,
) -> Result<ResolvedModel, ApiError> {
    if let Some(id) = agent_deploy_fallback(pool, actor_user_id, step, slot).await? {
        validate_model_id(&id)?;
        return Ok(ResolvedModel {
            model_id: id,
            step: step.as_str().to_string(),
            slot: slot.as_str().to_string(),
            source: ResolveSource::AgentDeploy,
        });
    }
    if slot == ModelSlot::Text {
        if let Some(id) = load_user_preferred_text(pool, actor_user_id).await? {
            validate_model_id(&id)?;
            return Ok(ResolvedModel {
                model_id: id,
                step: step.as_str().to_string(),
                slot: slot.as_str().to_string(),
                source: ResolveSource::UserPreferredText,
            });
        }
    }
    let id = catalog_default_for_slot(slot);
    Ok(ResolvedModel {
        model_id: id,
        step: step.as_str().to_string(),
        slot: slot.as_str().to_string(),
        source: ResolveSource::CatalogDefault,
    })
}

pub(crate) async fn resolve_from_state(
    pool: &PgPool,
    actor_user_id: Uuid,
    step: StudioStepSlug,
    slot: ModelSlot,
    loaded: &ProjectModelRoutingState,
) -> Result<ResolvedModel, ApiError> {
    if let Some(id) = loaded.routing.step_slot(step, slot) {
        validate_model_id(id)?;
        return Ok(ResolvedModel {
            model_id: id.to_string(),
            step: step.as_str().to_string(),
            slot: slot.as_str().to_string(),
            source: ResolveSource::StepOverride,
        });
    }

    if let Some(id) = modality_default(&loaded.defaults, slot) {
        validate_model_id(id)?;
        return Ok(ResolvedModel {
            model_id: id.to_string(),
            step: step.as_str().to_string(),
            slot: slot.as_str().to_string(),
            source: ResolveSource::ModalityDefault,
        });
    }

    if slot == ModelSlot::Text {
        if let Some(id) = load_user_preferred_text(pool, actor_user_id).await? {
            validate_model_id(&id)?;
            return Ok(ResolvedModel {
                model_id: id,
                step: step.as_str().to_string(),
                slot: slot.as_str().to_string(),
                source: ResolveSource::UserPreferredText,
            });
        }
    }

    if let Some(id) = agent_deploy_fallback(pool, actor_user_id, step, slot).await? {
        validate_model_id(&id)?;
        return Ok(ResolvedModel {
            model_id: id,
            step: step.as_str().to_string(),
            slot: slot.as_str().to_string(),
            source: ResolveSource::AgentDeploy,
        });
    }

    let id = catalog_default_for_slot(slot);
    Ok(ResolvedModel {
        model_id: id,
        step: step.as_str().to_string(),
        slot: slot.as_str().to_string(),
        source: ResolveSource::CatalogDefault,
    })
}

pub async fn resolve_all_effective(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_id: Uuid,
    _state: &crate::state::AppState,
) -> Result<Vec<ResolvedModel>, ApiError> {
    let loaded = load_project_model_routing(pool, project_id).await?;
    let mut entries = Vec::new();
    for step in StudioStepSlug::sop_steps() {
        let (resolve_step, slots) = effective_resolve_step_and_slots(*step);
        for slot in slots {
            let mut r =
                resolve_from_state(pool, actor_user_id, resolve_step, *slot, &loaded).await?;
            r.step = step.as_str().to_string();
            entries.push(r);
        }
    }
    for step in [StudioStepSlug::Quality] {
        for slot in step.editor_slots() {
            let r = resolve_from_state(pool, actor_user_id, step, *slot, &loaded).await?;
            entries.push(r);
        }
    }
    Ok(entries)
}

fn effective_resolve_step_and_slots(
    step: StudioStepSlug,
) -> (StudioStepSlug, &'static [ModelSlot]) {
    if step == StudioStepSlug::Deliver {
        (StudioStepSlug::Video, StudioStepSlug::Video.editor_slots())
    } else {
        (step, step.editor_slots())
    }
}

fn validate_model_id(model_id: &str) -> Result<(), ApiError> {
    if lookup_detail(model_id, false).is_none() {
        return Err(ApiError::BadRequest(format!(
            "unknown or invalid model_id: {model_id}"
        )));
    }
    Ok(())
}

fn catalog_default_for_slot(slot: ModelSlot) -> String {
    first_catalog_model_for_kind(slot.catalog_kind())
}

async fn load_user_preferred_text(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Option<String>, ApiError> {
    let row: Option<String> = sqlx::query_scalar(
        r#"SELECT preferred_text_model_id FROM app_user_profile WHERE user_id = $1"#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.filter(|s| !s.trim().is_empty()))
}

async fn agent_deploy_fallback(
    pool: &PgPool,
    user_id: Uuid,
    step: StudioStepSlug,
    slot: ModelSlot,
) -> Result<Option<String>, ApiError> {
    let key = match (step, slot) {
        (StudioStepSlug::Script, ModelSlot::Text) => Some("scriptAgent"),
        (StudioStepSlug::Storyboard | StudioStepSlug::Video, ModelSlot::Text)
        | (StudioStepSlug::Storyboard | StudioStepSlug::Video, ModelSlot::Multimodal) => {
            Some("productionAgent")
        }
        (_, ModelSlot::Voice) => Some("ttsDubbing"),
        (StudioStepSlug::Assets | StudioStepSlug::Art, ModelSlot::Text) => Some("universalAi"),
        _ => None,
    };
    let Some(agent_key) = key else {
        return Ok(None);
    };
    let cfg = load_agent_deploy_config(pool, user_id).await?;
    let Some(row) = cfg.rows.get(agent_key) else {
        return Ok(None);
    };
    let model = row.model.trim();
    if model.is_empty() {
        Ok(None)
    } else {
        Ok(Some(model.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn enforce_defaults_on_when_unset() {
        assert!(parse_model_routing_enforce(None));
    }

    #[test]
    fn enforce_off_for_falsey_env_values() {
        for v in ["0", "false", "no", "off", " FALSE "] {
            assert!(!parse_model_routing_enforce(Some(v)), "expected off for {v:?}");
        }
    }

    #[test]
    fn enforce_on_for_truthy_env_values() {
        assert!(parse_model_routing_enforce(Some("1")));
        assert!(parse_model_routing_enforce(Some("yes")));
    }

    #[test]
    fn slot_parse_roundtrip() {
        assert_eq!(ModelSlot::parse("text"), Some(ModelSlot::Text));
        assert_eq!(StudioStepSlug::parse("video"), Some(StudioStepSlug::Video));
    }
}
