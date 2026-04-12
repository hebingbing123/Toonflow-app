//! OpenAPI: Rust shell ([`shell`]), [`merge`] 输出，已提交的 path stubs（[`generated`]），以及 legacy 组件注册（[`legacy_components`]）。
//!
//! **你不需要维护一份「手写整本」`openapi.yaml`。** 运行中的契约来自本模块的 utoipa 合并结果；`embedded/legacy_component_schemas.json`
//! 与 `scripts/fixtures/openapi_stub_input.yaml`（仅用于 **重新生成** stubs，见 `scripts/extract_openapi_rust_sources.py` /
//! `scripts/gen_openapi_utoipa_stubs.py`）是 **从单体 OpenAPI 抽取** 的产物，**不参与** `merge.rs` 运行时合并。
//! 日常改接口应优先改各域 handler 上的 utoipa 注解与 Rust 类型。
//!
//! **目标形态（你描述的「只要 utoipa」）**：契约 **只** 由各域 `#[derive(OpenApi)]` / handler 上的 utoipa 注解与
//! **`#[derive(ToSchema)]`（或等价 `PartialSchema`）Rust 类型** 组成；**不再**把 `embedded/legacy_component_schemas.json`
//! 当作需要人工维护的真源——迁完后应 **删空该 JSON**、移除下面 `legacy_components` 的 `merge`、删掉
//! `scripts/gen_legacy_utoipa_registry.py` 与 `legacy_components/` 生成物。
//!
//! **过渡期**：`legacy_components` 仍从嵌入 JSON 批量注册组件名，直到每个 `ref("…")` 都有对应 Rust `ToSchema`；
//! 每迁走一个 schema，从 JSON 删掉该键并执行 `python3 scripts/gen_legacy_utoipa_registry.py` 再提交。
//! **已迁 Rust（示例）**：`manuals::art_styles` 的 6 个 DTO 经 [`crate::manuals::art_styles::ArtStyleSchemasOpenApi`] 在 `legacy` 之前合并；
//! `scripts/extract_openapi_rust_sources.py` 会跳过同名键以免抽回 JSON。

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
    doc.merge(crate::manuals::art_styles::ArtStyleSchemasOpenApi::openapi());
    // TODO(utoipa-only): 当 `embedded/legacy_component_schemas.json` 为空时，删除此行并移除 `legacy_components` 模块与生成脚本。
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
