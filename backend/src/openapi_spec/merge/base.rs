//! OpenAPI 文档基座（shell 序列化、`paths` 占位、YAML 回退）。

use anyhow::Context;
use serde_json::Value as Json;

pub(super) const FALLBACK_MINIMAL_YAML: &str =
    "openapi: 3.1.0\ninfo:\n  title: OpenFlow API\n  version: 1.0.0\npaths: {}\n";

pub(super) fn document_base() -> anyhow::Result<Json> {
    let shell = crate::openapi_spec::shell::openapi_shell();
    let mut base = serde_json::to_value(&shell).context("serialize openapi shell")?;
    ensure_paths_object(&mut base)?;
    Ok(base)
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

pub(super) fn document_base_yaml_for_fallback() -> String {
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

/// `serde_yaml` may emit a leading `---` and/or whitespace before `openapi:`.
pub(super) fn strip_optional_yaml_document_prefix(s: String) -> String {
    let mut t = s.trim_start_matches(['\n', '\r', ' ', '\t']);
    if let Some(rest) = t.strip_prefix("---") {
        t = rest.trim_start_matches(['\n', '\r', ' ', '\t']);
    }
    t.to_string()
}
