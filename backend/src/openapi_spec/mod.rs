//! utoipa [`OpenApi`] fragment; merged into `docs/openapi.yaml` for serving and export.

mod merge;
mod system;

pub use merge::{merged_openapi_yaml_cached, merged_openapi_yaml_string};

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
pub struct ApiDoc;
