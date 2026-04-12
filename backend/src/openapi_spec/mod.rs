//! utoipa [`OpenApi`] fragment; merged into `docs/openapi.yaml` for serving and export.

mod generated;
mod merge;
mod system;

pub use merge::{merged_openapi_yaml_cached, merged_openapi_yaml_string};

use utoipa::OpenApi;

/// Hand-written utoipa for core routes (schemas + rich responses). Merged before YAML-derived stubs
/// so [`utoipa::openapi::OpenApi::merge`] keeps these operations when paths overlap.
#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        crate::app::handlers::health,
        crate::openapi_spec::system::health_v1_openapi,
        crate::app::handlers::ping,
        crate::app::handlers::version,
        crate::app::handlers::ready,
        crate::app::handlers::me,
    ),
    components(schemas(
        crate::app::handlers::HealthResponse,
        crate::app::handlers::PingResponse,
        crate::app::handlers::VersionResponse,
        crate::app::handlers::ReadyResponse,
        crate::app::handlers::MeResponse,
        crate::error::ErrorBody,
        crate::state::MemoryConfig,
    )),
    tags(
        (name = "system", description = "Health, readiness, and lightweight probes"),
        (name = "session", description = "Auth probe (Supabase JWT)"),
    )
)]
pub struct CoreHandlersApi;

/// Full utoipa document: core handlers plus all operations from `scripts/gen_openapi_utoipa_stubs.py`.
pub fn combined_openapi() -> utoipa::openapi::OpenApi {
    let mut doc = CoreHandlersApi::openapi();
    doc.merge(generated::merged_generated_openapi());
    doc
}
