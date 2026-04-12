//! Merge utoipa-generated path/schema fragments into the hand-maintained `docs/openapi.yaml` base.

use std::sync::OnceLock;

use anyhow::Context;
use serde_json::Value as Json;
use utoipa::OpenApi;

const BASE_OPENAPI_YAML: &str = include_str!("../../../docs/openapi.yaml");

/// Full OpenAPI document: base YAML with utoipa overlays for migrated paths and schemas.
pub fn merged_openapi_yaml_string() -> anyhow::Result<String> {
    let mut base: Json =
        serde_yaml::from_str(BASE_OPENAPI_YAML).context("parse base openapi.yaml")?;
    let gen = crate::openapi_spec::ApiDoc::openapi();
    let gen_val: Json = serde_json::to_value(&gen).context("serialize utoipa OpenApi")?;

    overlay_paths(&mut base, &gen_val)?;
    overlay_components_object(&mut base, &gen_val, "schemas")?;
    overlay_components_object(&mut base, &gen_val, "securitySchemes")?;

    let raw = serde_yaml::to_string(&base).context("serialize merged openapi")?;
    Ok(strip_optional_yaml_document_prefix(raw))
}

/// `serde_yaml` may emit a leading `---` and/or whitespace before `openapi:`.
fn strip_optional_yaml_document_prefix(s: String) -> String {
    let mut t = s.trim_start_matches(['\n', '\r', ' ', '\t']);
    if let Some(rest) = t.strip_prefix("---") {
        t = rest.trim_start_matches(['\n', '\r', ' ', '\t']);
    }
    t.to_string()
}

/// Lazily merged spec for the running server (logs and falls back to static YAML on failure).
pub fn merged_openapi_yaml_cached() -> &'static str {
    static DOC: OnceLock<String> = OnceLock::new();
    DOC.get_or_init(|| {
        merged_openapi_yaml_string().unwrap_or_else(|err| {
            tracing::error!(%err, "OpenAPI merge failed; serving static docs/openapi.yaml");
            BASE_OPENAPI_YAML.to_string()
        })
    })
    .as_str()
}

fn overlay_paths(base: &mut Json, gen: &Json) -> anyhow::Result<()> {
    let Some(gen_paths) = gen.get("paths").and_then(|p| p.as_object()) else {
        return Ok(());
    };
    let base_paths = base
        .get_mut("paths")
        .and_then(|p| p.as_object_mut())
        .context("base OpenAPI missing paths")?;
    for (k, v) in gen_paths {
        base_paths.insert(k.clone(), v.clone());
    }
    Ok(())
}

fn overlay_components_object(base: &mut Json, gen: &Json, key: &str) -> anyhow::Result<()> {
    let ptr = format!("/components/{key}");
    let Some(gen_obj) = gen.pointer(&ptr).and_then(|s| s.as_object()) else {
        return Ok(());
    };
    let base_components = base
        .get_mut("components")
        .and_then(|c| c.as_object_mut())
        .context("base OpenAPI missing components")?;
    let base_bucket = base_components
        .entry(key)
        .or_insert_with(|| Json::Object(Default::default()))
        .as_object_mut()
        .context("components bucket must be an object")?;
    for (k, v) in gen_obj {
        base_bucket.insert(k.clone(), v.clone());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merged_openapi_is_valid_yaml_and_keeps_ws_route() {
        let yaml = merged_openapi_yaml_string().expect("merge");
        assert!(
            yaml.contains("/api/v1/ws:"),
            "merged spec should retain base WebSocket path until migrated"
        );
        assert!(
            yaml.contains("operationId: healthRoot"),
            "utoipa should overlay healthRoot"
        );
        let v: Json = serde_yaml::from_str(&yaml).expect("round-trip yaml");
        assert_eq!(v.get("openapi").and_then(|x| x.as_str()), Some("3.1.0"));
    }
}
