//! OpenAPI / JSON types for model routing REST.

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use super::types::{ResolveSource, StepSlotMap};

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingDefaultsBody {
    pub text_model: Option<String>,
    pub multimodal_model: Option<String>,
    pub image_model: Option<String>,
    pub video_model: Option<String>,
    pub voice_model: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingDefaultsPatch {
    #[serde(default)]
    pub text_model: Option<Option<String>>,
    #[serde(default)]
    pub multimodal_model: Option<Option<String>>,
    #[serde(default)]
    pub image_model: Option<Option<String>>,
    #[serde(default)]
    pub video_model: Option<Option<String>>,
    #[serde(default)]
    pub voice_model: Option<Option<String>>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, ToSchema)]
pub struct ModelRoutingStepsPatch {
    /// Step slug → slot → model id (`null` value removes override).
    #[serde(default)]
    pub steps: Option<StepSlotMap>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, ToSchema)]
pub struct ModelRoutingPatchBody {
    #[serde(default)]
    pub defaults: Option<ModelRoutingDefaultsPatch>,
    #[serde(default)]
    pub steps: Option<StepSlotMap>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingEffectiveEntry {
    pub step: String,
    pub slot: String,
    pub model_id: String,
    pub source: ResolveSource,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingResponse {
    pub project_id: uuid::Uuid,
    pub defaults: ModelRoutingDefaultsBody,
    pub steps: StepSlotMap,
    pub effective: Vec<ModelRoutingEffectiveEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingResolveBody {
    pub step: String,
    pub slot: String,
    #[serde(default)]
    pub model_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ModelRoutingResolveResponse {
    pub model_id: String,
    pub step: String,
    pub slot: String,
    pub source: ResolveSource,
}
