//! Core types for project model routing.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use utoipa::ToSchema;

/// Catalog / column slot for a model pick.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize, ToSchema,
)]
#[serde(rename_all = "snake_case")]
pub enum ModelSlot {
    Text,
    Multimodal,
    Image,
    Video,
    Voice,
}

impl ModelSlot {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Text => "text",
            Self::Multimodal => "multimodal",
            Self::Image => "image",
            Self::Video => "video",
            Self::Voice => "voice",
        }
    }

    #[must_use]
    pub fn parse(raw: &str) -> Option<Self> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "text" => Some(Self::Text),
            "multimodal" => Some(Self::Multimodal),
            "image" => Some(Self::Image),
            "video" => Some(Self::Video),
            "voice" => Some(Self::Voice),
            _ => None,
        }
    }

    #[must_use]
    pub fn catalog_kind(self) -> &'static str {
        match self {
            Self::Text => "text",
            Self::Multimodal => "multimodal",
            Self::Image => "image",
            Self::Video => "video",
            Self::Voice => "text",
        }
    }

    #[must_use]
    pub fn all() -> &'static [Self] {
        &[
            Self::Text,
            Self::Multimodal,
            Self::Image,
            Self::Video,
            Self::Voice,
        ]
    }
}

/// Studio SOP step slug (matches Flutter `StudioStep.slug`).
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize, ToSchema,
)]
#[serde(rename_all = "snake_case")]
pub enum StudioStepSlug {
    Script,
    Art,
    Assets,
    Storyboard,
    Video,
    Deliver,
    Quality,
}

impl StudioStepSlug {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Script => "script",
            Self::Art => "art",
            Self::Assets => "assets",
            Self::Storyboard => "storyboard",
            Self::Video => "video",
            Self::Deliver => "deliver",
            Self::Quality => "quality",
        }
    }

    #[must_use]
    pub fn parse(raw: &str) -> Option<Self> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "script" => Some(Self::Script),
            "art" => Some(Self::Art),
            "assets" => Some(Self::Assets),
            "storyboard" => Some(Self::Storyboard),
            "video" => Some(Self::Video),
            "deliver" => Some(Self::Deliver),
            "quality" => Some(Self::Quality),
            _ => None,
        }
    }

    #[must_use]
    pub fn sop_steps() -> &'static [Self] {
        &[
            Self::Script,
            Self::Art,
            Self::Assets,
            Self::Storyboard,
            Self::Video,
            Self::Deliver,
        ]
    }

    /// Primary slots exposed in the project editor matrix for this step.
    #[must_use]
    pub fn editor_slots(self) -> &'static [ModelSlot] {
        match self {
            Self::Script => &[ModelSlot::Text],
            Self::Art => &[ModelSlot::Image],
            Self::Assets => &[ModelSlot::Image, ModelSlot::Text],
            Self::Storyboard => &[ModelSlot::Image, ModelSlot::Multimodal],
            Self::Video => &[ModelSlot::Text, ModelSlot::Multimodal, ModelSlot::Video],
            Self::Deliver => &[],
            Self::Quality => &[ModelSlot::Text],
        }
    }
}

/// Where the resolved model id came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ResolveSource {
    RequestOverride,
    StepOverride,
    ModalityDefault,
    UserPreferredText,
    AgentDeploy,
    CatalogDefault,
}

/// Result of resolving a model for a project + step + slot.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct ResolvedModel {
    pub model_id: String,
    pub step: String,
    pub slot: String,
    pub source: ResolveSource,
}

/// Step → slot → model id overrides stored in metadata.
pub type StepSlotMap = BTreeMap<String, BTreeMap<String, String>>;

/// Parsed `metadata.modelRouting` document.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ModelRoutingDocument {
    #[serde(default = "default_version")]
    pub version: i32,
    #[serde(default)]
    pub steps: StepSlotMap,
}

fn default_version() -> i32 {
    1
}

impl ModelRoutingDocument {
    pub fn step_slot(&self, step: StudioStepSlug, slot: ModelSlot) -> Option<&str> {
        self.steps
            .get(step.as_str())
            .and_then(|m| m.get(slot.as_str()))
            .map(String::as_str)
            .filter(|s| !s.trim().is_empty())
    }
}
