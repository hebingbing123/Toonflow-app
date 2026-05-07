//! OpenAPI: Rust shell ([`shell`]), [`merge`] 输出，以及已提交的 path stubs（[`generated`]）。
//!
//! **你不需要维护一份「手写整本」`openapi.yaml`。** 运行中的契约来自本模块的 utoipa 合并结果；`scripts/fixtures/openapi_stub_input.yaml`
//! （仅用于 **重新生成** stubs，见 `scripts/extract_openapi_rust_sources.py` /
//! `scripts/gen_openapi_utoipa_stubs.py`）是 **从单体 OpenAPI 抽取** 的产物，**不参与** `merge.rs` 运行时合并。
//! 日常改接口应优先改各域 handler 上的 utoipa 注解与 Rust 类型。
//!
//! 契约由各域 `#[derive(OpenApi)]` / handler utoipa 注解与 Rust `#[derive(ToSchema)]` 类型组成；
//! 不再保留旧组件注册层或相关生成物。

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
        crate::app::handlers::get_metrics,
        crate::app::handlers::get_sli_status,
        crate::app::handlers::get_sli_definitions,
    ),
    components(schemas(
        crate::app::handlers::HealthResponse,
        crate::app::handlers::PingResponse,
        crate::app::handlers::VersionResponse,
        crate::app::handlers::ReadyResponse,
        crate::app::handlers::MeResponse,
        crate::app::handlers::metrics::MetricsQuery,
        crate::app::handlers::metrics::MetricsResponse,
        crate::app::handlers::metrics::SliStatusResponse,
        crate::http_kit::metrics::registry::EndpointMetrics,
        crate::http_kit::metrics::sli::SliDefinition,
        crate::http_kit::metrics::sli::SliSnapshot,
        crate::http_kit::metrics::sli::CriticalPath,
        crate::error::ErrorBody,
        crate::state::MemoryConfig,
    )),
    tags(
        (name = "system", description = "Health, readiness, and lightweight probes"),
        (name = "session", description = "Auth probe (Supabase JWT)"),
        (name = "observability", description = "Metrics, SLIs, and monitoring endpoints"),
    )
)]
pub struct CoreHandlersApi;

/// Full utoipa document: core handlers, domain APIs, and YAML-index stubs.
pub fn combined_openapi() -> utoipa::openapi::OpenApi {
    let mut doc = CoreHandlersApi::openapi();
    doc.merge(crate::assets::AssetsSchemasOpenApi::openapi());
    doc.merge(crate::manuals::art_styles::ArtStyleSchemasOpenApi::openapi());
    doc.merge(crate::billing::BillingApi::openapi());
    doc.merge(crate::settings::SettingsOpenApi::openapi());
    doc.merge(crate::vendor::VendorCatalogOpenApi::openapi());
    doc.merge(crate::prompting::PromptingHttpOpenApi::openapi());
    doc.merge(crate::production::ProductionApi::openapi());
    doc.merge(crate::projects::ProjectsOpenApi::openapi());
    doc.merge(crate::publish::PublishOpenApi::openapi());
    doc.merge(crate::jobs::JobsOpenApi::openapi());
    doc.merge(crate::harness::HarnessOpenApi::openapi());
    doc.merge(crate::harness::WsUpgradeOpenApi::openapi());
    doc.merge(crate::metering::MeteringOpenApi::openapi());
    doc.merge(crate::narrative::novels::NovelsHttpOpenApi::openapi());
    doc.merge(crate::workspaces::WorkspacesOpenApi::openapi());
    doc.merge(generated::merged_generated_openapi());
    doc
}
