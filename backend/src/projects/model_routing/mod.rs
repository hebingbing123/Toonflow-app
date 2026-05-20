//! Per-project Studio step model routing (config + resolver + credentials).

pub mod api_types;
pub mod credentials;
pub mod jobs;
pub mod resolver;
pub mod store;
pub mod types;

pub use api_types::{
    ModelRoutingDefaultsBody, ModelRoutingDefaultsPatch, ModelRoutingEffectiveEntry,
    ModelRoutingPatchBody, ModelRoutingResolveBody, ModelRoutingResolveResponse,
    ModelRoutingResponse, ModelRoutingStepsPatch,
};
pub use credentials::build_llm_config_for_model;
pub use resolver::{
    harness_channel_to_step_slot, is_model_routing_enforced, resolve_all_effective,
    resolve_model_id, ResolveInput,
};
pub use types::{ModelSlot, ResolveSource, ResolvedModel, StudioStepSlug};
