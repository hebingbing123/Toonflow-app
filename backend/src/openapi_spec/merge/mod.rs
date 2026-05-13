//! Merge OpenAPI fragments into the document base.
//!
//! The base is built from **[`crate::openapi_spec::shell::openapi_shell`]** (metadata + security) with **empty `paths`**
//! before merges. Component schemas come from **[`crate::openapi_spec::combined_openapi`]** (utoipa).
//!
//! Merge order:
//! 1. **[`crate::openapi_spec::combined_openapi`]** — utoipa output (hand-written handler docs + committed
//!    stubs under [`super::generated`]). Path items come entirely from Rust; regenerate stubs only when you
//!    have an external OpenAPI YAML (see `scripts/gen_openapi_utoipa_stubs.py`).
//!
//! [`overlay::overlay_paths`] / rich operation merge remain for merging multiple utoipa
//! fragments onto the same path key (later merges overlay richer `requestBody` / `responses`).

use std::sync::OnceLock;

use anyhow::Context;
use serde_json::Value as Json;

mod base;
mod overlay;

#[cfg(test)]
mod tests;

/// Full OpenAPI document: shell + utoipa paths/components (no embedded paths YAML).
pub fn merged_openapi_yaml_string() -> anyhow::Result<String> {
    let mut base = base::document_base()?;

    let gen = crate::openapi_spec::combined_openapi();
    let gen_val: Json = serde_json::to_value(&gen).context("serialize utoipa OpenApi")?;

    overlay::overlay_paths(&mut base, &gen_val)?;
    overlay::overlay_components_object(&mut base, &gen_val, "schemas")?;
    overlay::overlay_components_object(&mut base, &gen_val, "securitySchemes")?;

    // D-batch migration: mark numeric ID path parameters as deprecated where UUID alternatives exist.
    // Column removal is blocked by import infrastructure; this annotation signals migration direction.
    overlay::mark_numeric_id_parameters_deprecated(&mut base)?;

    let raw = serde_yaml::to_string(&base).context("serialize merged openapi")?;
    Ok(base::strip_optional_yaml_document_prefix(raw))
}

/// Lazily merged spec for the running server (logs and falls back to static YAML on failure).
pub fn merged_openapi_yaml_cached() -> &'static str {
    static DOC: OnceLock<String> = OnceLock::new();
    DOC.get_or_init(|| {
        merged_openapi_yaml_string().unwrap_or_else(|err| {
            tracing::error!(%err, "OpenAPI merge failed; serving document base only (shell only)");
            base::document_base_yaml_for_fallback()
        })
    })
    .as_str()
}
