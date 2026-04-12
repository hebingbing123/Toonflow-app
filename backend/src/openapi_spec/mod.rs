//! OpenAPI: Rust shell ([`shell`]), path index ([`merge`] reads `openapi_paths_index.yaml`), generated stubs
//! ([`generated`]), and legacy component names ([`legacy_components`]).
//!
//! **你不需要维护一份「手写整本」`openapi.yaml`。** 运行中的契约来自本模块的 utoipa 合并结果；`openapi_paths_index.yaml`
//! 与 `embedded/legacy_component_schemas.json` 是 **从单体 OpenAPI 抽取/再生成** 的产物（见 `scripts/extract_openapi_rust_sources.py`），
//! 日常改接口应优先改各域 handler 上的 utoipa 注解与 Rust 类型。
//!
//! **字段级 `#[derive(ToSchema)]` 的终点**：逐步用真实 Rust DTO（或 `typify` 等从 JSON Schema 批量生成再手修）
//! 替换 `legacy_components` 里 JSON 反序列化的占位类型；每迁走一个 schema，就从嵌入 JSON 删掉对应键并再跑生成器。

mod generated;
mod legacy_components;
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

/// Full utoipa document: core handlers, legacy component registry, domain APIs, and YAML-index stubs.
pub fn combined_openapi() -> utoipa::openapi::OpenApi {
    let mut doc = CoreHandlersApi::openapi();
    doc.merge(legacy_components::merged_legacy_components_openapi());
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
