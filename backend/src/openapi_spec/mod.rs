//! OpenAPI: Rust shell (`shell`), embedded legacy schemas, `openapi_paths_index.yaml` paths, and utoipa merge (see [`merge`]).

mod generated;
mod merge;
mod shell;
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
    doc.merge(crate::billing::BillingApi::openapi());
    doc.merge(crate::settings::SettingsOpenApi::openapi());
    doc.merge(crate::vendor::VendorCatalogOpenApi::openapi());
    doc.merge(crate::prompting::PromptingHttpOpenApi::openapi());
    doc.merge(crate::production::ProductionApi::openapi());
    doc.merge(crate::jobs::JobsOpenApi::openapi());
    doc.merge(crate::harness::HarnessOpenApi::openapi());
    doc.merge(crate::harness::WsUpgradeOpenApi::openapi());
    doc.merge(crate::metering::MeteringOpenApi::openapi());
    doc.merge(generated::merged_generated_openapi());
    doc
}
