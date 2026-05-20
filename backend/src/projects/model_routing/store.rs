//! Load / persist project model routing from Postgres.

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::types::{ModelRoutingDocument, ModelSlot, StepSlotMap};

#[derive(Debug, Clone)]
pub(crate) struct ProjectModelDefaults {
    pub text_model: Option<String>,
    pub multimodal_model: Option<String>,
    pub image_model: Option<String>,
    pub video_model: Option<String>,
    pub voice_model: Option<String>,
}

#[derive(Debug, Clone)]
pub(crate) struct ProjectModelRoutingState {
    pub defaults: ProjectModelDefaults,
    pub routing: ModelRoutingDocument,
    pub metadata_raw: Value,
}

type ProjectModelRoutingRow = (
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
    Option<String>,
    Value,
);

pub(crate) async fn load_project_model_routing(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<ProjectModelRoutingState, ApiError> {
    let row: Option<ProjectModelRoutingRow> = sqlx::query_as(
        r#"
            SELECT text_model, multimodal_model, image_model, video_model, voice_model,
                   COALESCE(metadata, '{}'::jsonb)
            FROM app_project
            WHERE id = $1
            "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((text, multi, image, video, voice, metadata)) = row else {
        return Err(ApiError::NotFound);
    };

    let routing = parse_routing_from_metadata(&metadata);
    Ok(ProjectModelRoutingState {
        defaults: ProjectModelDefaults {
            text_model: text,
            multimodal_model: multi,
            image_model: image,
            video_model: video,
            voice_model: voice,
        },
        routing,
        metadata_raw: metadata,
    })
}

pub(crate) fn parse_routing_from_metadata(metadata: &Value) -> ModelRoutingDocument {
    metadata
        .get("modelRouting")
        .and_then(|v| serde_json::from_value::<ModelRoutingDocument>(v.clone()).ok())
        .unwrap_or_default()
}

pub(crate) fn modality_default(defaults: &ProjectModelDefaults, slot: ModelSlot) -> Option<&str> {
    let opt = match slot {
        ModelSlot::Text => defaults.text_model.as_deref(),
        ModelSlot::Multimodal => defaults.multimodal_model.as_deref(),
        ModelSlot::Image => defaults.image_model.as_deref(),
        ModelSlot::Video => defaults.video_model.as_deref(),
        ModelSlot::Voice => defaults.voice_model.as_deref(),
    };
    opt.filter(|s| !s.trim().is_empty())
}

pub(crate) async fn persist_model_routing(
    pool: &PgPool,
    project_id: Uuid,
    metadata: &Value,
    defaults: &ProjectModelDefaults,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_project
        SET metadata = $1::jsonb,
            text_model = $2,
            multimodal_model = $3,
            image_model = $4,
            video_model = $5,
            voice_model = $6,
            updated_at = NOW()
        WHERE id = $7
        "#,
    )
    .bind(metadata)
    .bind(&defaults.text_model)
    .bind(&defaults.multimodal_model)
    .bind(&defaults.image_model)
    .bind(&defaults.video_model)
    .bind(&defaults.voice_model)
    .bind(project_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

/// Merge PATCH steps into metadata and mirror primary slots into modality columns.
pub(crate) fn merge_routing_patch(
    mut metadata: Value,
    defaults_patch: Option<ProjectModelDefaults>,
    steps_patch: Option<StepSlotMap>,
    current_defaults: &ProjectModelDefaults,
    current_routing: &ModelRoutingDocument,
) -> (Value, ProjectModelDefaults, ModelRoutingDocument) {
    let mut defaults = current_defaults.clone();
    if let Some(patch) = defaults_patch {
        if patch.text_model.is_some() {
            defaults.text_model = patch.text_model;
        }
        if patch.multimodal_model.is_some() {
            defaults.multimodal_model = patch.multimodal_model;
        }
        if patch.image_model.is_some() {
            defaults.image_model = patch.image_model;
        }
        if patch.video_model.is_some() {
            defaults.video_model = patch.video_model;
        }
        if patch.voice_model.is_some() {
            defaults.voice_model = patch.voice_model;
        }
    }

    let mut routing = current_routing.clone();
    if let Some(steps) = steps_patch {
        for (step, slots) in steps {
            let step_key = step.clone();
            let entry = routing.steps.entry(step).or_default();
            for (slot, model_id) in slots {
                let trimmed = model_id.trim();
                if trimmed.is_empty() {
                    entry.remove(&slot);
                } else {
                    entry.insert(slot, trimmed.to_string());
                }
            }
            if entry.is_empty() {
                routing.steps.remove(&step_key);
            }
        }
    }

    mirror_steps_to_defaults(&mut defaults, &routing);

    let doc = serde_json::to_value(&routing).unwrap_or_else(|_| Value::Object(Default::default()));
    if let Value::Object(ref mut root) = metadata {
        root.insert("modelRouting".to_string(), doc);
    } else {
        metadata = serde_json::json!({ "modelRouting": routing });
    }

    (metadata, defaults, routing)
}

fn mirror_steps_to_defaults(defaults: &mut ProjectModelDefaults, routing: &ModelRoutingDocument) {
    if let Some(m) = routing
        .steps
        .get("script")
        .and_then(|s| s.get("text"))
        .filter(|s| !s.trim().is_empty())
    {
        defaults.text_model = Some(m.clone());
    }
    if let Some(m) = routing
        .steps
        .get("video")
        .and_then(|s| s.get("video"))
        .filter(|s| !s.trim().is_empty())
    {
        defaults.video_model = Some(m.clone());
    }
    if let Some(m) = routing
        .steps
        .get("video")
        .and_then(|s| s.get("multimodal"))
        .filter(|s| !s.trim().is_empty())
    {
        defaults.multimodal_model = Some(m.clone());
    }
}
