//! Merge OpenAPI fragments into the document base.
//!
//! The base is built from **[`super::shell::openapi_shell`]** (metadata + security) plus
//! **`embedded/legacy_component_schemas.json`** (transitional component schemas until everything is `ToSchema`),
//! with **empty `paths`** before merges.
//!
//! Merge order:
//! 1. **`openapi_paths_index.yaml`** — canonical path items (request bodies, responses, parameters,
//!    descriptions) migrated from the historical monolithic OpenAPI.
//! 2. **[`crate::openapi_spec::combined_openapi`]** — utoipa output (hand-written handler docs + generated
//!    stubs from `scripts/gen_openapi_utoipa_stubs.py`). When utoipa carries **request/response content** and the
//!    index already documented the same operation, [`merge_rich_operation_onto_base`] **overlays** utoipa
//!    `requestBody` / `responses` (and `operationId` / `summary` / `tags`) onto the YAML op so **`parameters`**,
//!    **`security`**, and long **`description`** stay with the index. Thin utoipa stubs still do not erase YAML.
//!
//! Routes only documented in utoipa (e.g. **`GET /api/v1/ws`**) still appear because they merge after the index.

use std::sync::OnceLock;

use anyhow::Context;
use serde_json::Value as Json;

const PATHS_INDEX_YAML: &str = include_str!("openapi_paths_index.yaml");

const FALLBACK_MINIMAL_YAML: &str =
    "openapi: 3.1.0\ninfo:\n  title: Toonflow API\n  version: 1.0.0\npaths: {}\n";

fn document_base() -> anyhow::Result<Json> {
    let shell = super::shell::openapi_shell();
    let mut base = serde_json::to_value(&shell).context("serialize openapi shell")?;
    inject_legacy_schemas(&mut base)?;
    ensure_paths_object(&mut base)?;
    Ok(base)
}

fn inject_legacy_schemas(base: &mut Json) -> anyhow::Result<()> {
    const LEGACY: &str = include_str!("embedded/legacy_component_schemas.json");
    let legacy: Json =
        serde_json::from_str(LEGACY).context("parse embedded legacy_component_schemas.json")?;
    let legacy_obj = legacy
        .as_object()
        .context("legacy_component_schemas.json must be a JSON object")?;
    let root = base
        .as_object_mut()
        .context("OpenAPI root must be a JSON object")?;
    let components = root
        .entry("components")
        .or_insert_with(|| Json::Object(Default::default()));
    let co = components
        .as_object_mut()
        .context("components must be a JSON object")?;
    let schemas = co
        .entry("schemas")
        .or_insert_with(|| Json::Object(Default::default()));
    let sm = schemas
        .as_object_mut()
        .context("components.schemas must be a JSON object")?;
    for (k, v) in legacy_obj {
        sm.insert(k.clone(), v.clone());
    }
    Ok(())
}

fn ensure_paths_object(base: &mut Json) -> anyhow::Result<()> {
    let root = base
        .as_object_mut()
        .context("OpenAPI root must be a JSON object")?;
    let paths = root
        .entry("paths")
        .or_insert_with(|| Json::Object(Default::default()));
    if paths.as_object().is_none() {
        *paths = Json::Object(Default::default());
    }
    Ok(())
}

fn document_base_yaml_for_fallback() -> String {
    match document_base() {
        Ok(base) => match serde_yaml::to_string(&base) {
            Ok(raw) => strip_optional_yaml_document_prefix(raw),
            Err(e) => {
                tracing::error!(%e, "OpenAPI fallback: YAML serialize of document base failed");
                FALLBACK_MINIMAL_YAML.to_string()
            }
        },
        Err(e) => {
            tracing::error!(%e, "OpenAPI fallback: document base build failed");
            FALLBACK_MINIMAL_YAML.to_string()
        }
    }
}

/// Full OpenAPI document: base + indexed paths + utoipa overlays and extra components.
pub fn merged_openapi_yaml_string() -> anyhow::Result<String> {
    let mut base = document_base()?;
    let paths_index: Json = serde_yaml::from_str(PATHS_INDEX_YAML)
        .context("parse embedded openapi_paths_index.yaml")?;
    overlay_paths(&mut base, &paths_index).context("merge openapi_paths_index paths")?;

    let gen = crate::openapi_spec::combined_openapi();
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
            tracing::error!(%err, "OpenAPI merge failed; serving document base only (shell + legacy schemas)");
            document_base_yaml_for_fallback()
        })
    })
    .as_str()
}

const HTTP_METHODS: &[&str] = &[
    "get", "post", "put", "patch", "delete", "options", "head", "trace",
];

fn overlay_paths(base: &mut Json, gen: &Json) -> anyhow::Result<()> {
    let Some(gen_paths) = gen.get("paths").and_then(|p| p.as_object()) else {
        return Ok(());
    };
    let base_paths = base
        .get_mut("paths")
        .and_then(|p| p.as_object_mut())
        .context("base OpenAPI missing paths")?;
    for (path_key, gen_item) in gen_paths {
        match base_paths.get_mut(path_key) {
            None => {
                base_paths.insert(path_key.clone(), gen_item.clone());
            }
            Some(base_item) => merge_path_item_in_place(base_item, gen_item),
        }
    }
    Ok(())
}

fn merge_path_item_in_place(base_item: &mut Json, gen_item: &Json) {
    let Some(gobj) = gen_item.as_object() else {
        return;
    };
    let Some(bobj) = base_item.as_object_mut() else {
        return;
    };
    for method in HTTP_METHODS {
        let Some(gen_op) = gobj.get(*method) else {
            continue;
        };
        match bobj.get_mut(*method) {
            None => {
                bobj.insert((*method).to_string(), gen_op.clone());
            }
            Some(base_op) => merge_operation_in_place(base_op, gen_op),
        }
    }
}

/// Rich utoipa overlays request/response onto the index op; thin stubs never replace YAML content.
fn merge_operation_in_place(base_op: &mut Json, gen_op: &Json) {
    if operation_has_content(gen_op) {
        if operation_has_content(base_op) {
            merge_rich_operation_onto_base(base_op, gen_op);
        } else {
            *base_op = gen_op.clone();
        }
        return;
    }
    if operation_has_content(base_op) {
        return;
    }
    if base_op.as_object().map(|o| !o.is_empty()).unwrap_or(false) {
        return;
    }
    *base_op = gen_op.clone();
}

/// Copy OpenAPI operation fields from `gen_op` onto `base_op`, keeping index-only fields (e.g. `parameters`).
fn merge_rich_operation_onto_base(base_op: &mut Json, gen_op: &Json) {
    let Some(base_obj) = base_op.as_object_mut() else {
        return;
    };
    let Some(gen_obj) = gen_op.as_object() else {
        return;
    };
    for key in ["requestBody", "responses"] {
        if let Some(v) = gen_obj.get(key) {
            base_obj.insert(key.to_string(), v.clone());
        }
    }
    for key in ["operationId", "summary", "tags"] {
        if let Some(v) = gen_obj.get(key) {
            base_obj.insert(key.to_string(), v.clone());
        }
    }
}

fn operation_has_content(op: &Json) -> bool {
    let Some(o) = op.as_object() else {
        return false;
    };
    if let Some(rb) = o.get("requestBody") {
        if request_body_has_content(rb) {
            return true;
        }
    }
    let Some(resps) = o.get("responses").and_then(|r| r.as_object()) else {
        return false;
    };
    resps.values().any(response_has_content)
}

fn request_body_has_content(rb: &Json) -> bool {
    rb.get("content")
        .and_then(|c| c.as_object())
        .map(|o| !o.is_empty())
        .unwrap_or(false)
}

fn response_has_content(r: &Json) -> bool {
    r.get("content")
        .and_then(|c| c.as_object())
        .map(|o| !o.is_empty())
        .unwrap_or(false)
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
            "merged spec should retain WebSocket path from utoipa"
        );
        assert!(
            yaml.contains("operationId: healthRoot"),
            "utoipa should overlay healthRoot"
        );
        let v: Json = serde_yaml::from_str(&yaml).expect("round-trip yaml");
        assert_eq!(v.get("openapi").and_then(|x| x.as_str()), Some("3.1.0"));
    }

    /// Generated stubs use utoipa `ref("…")` for response bodies; merged spec must still expose the ref.
    #[test]
    fn merged_openapi_stub_routes_keep_response_schema_refs() {
        let yaml = merged_openapi_yaml_string().expect("merge");
        let op = yaml
            .find("operationId: listArtStylesV1")
            .expect("op present");
        let window = &yaml[op..op.saturating_add(1200)];
        assert!(
            window.contains("ListArtStylesResponse"),
            "expected ListArtStylesResponse in merged op; got: {window:?}"
        );
    }

    /// Rich utoipa overlay must not drop path `parameters` from the YAML index.
    #[test]
    fn merged_openapi_overlays_utoipa_onto_yaml_keeps_parameters() {
        let yaml = merged_openapi_yaml_string().expect("merge");
        let op = yaml
            .find("operationId: getProjectStatsByProjectIdV1")
            .expect("op present");
        let window = &yaml[op..op.saturating_add(1600)];
        assert!(
            window.contains("name: project_id"),
            "expected path parameter from index; got: {window:?}"
        );
        assert!(
            window.contains("ProjectStatsResponse"),
            "expected stats response ref; got: {window:?}"
        );
    }
}
