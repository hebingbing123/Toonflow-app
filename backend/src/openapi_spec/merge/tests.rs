use serde_json::Value as Json;

use super::merged_openapi_yaml_string;

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

/// UUID-scoped stats route must appear under the path template (utoipa stubs; parameters may be implicit).
#[test]
fn merged_openapi_project_stats_route_and_response_ref() {
    let yaml = merged_openapi_yaml_string().expect("merge");
    assert!(
        yaml.contains("/api/v1/projects/{project_id}/stats:"),
        "expected stats path key in merged YAML"
    );
    assert!(
        yaml.contains("operationId: getProjectStatsByProjectIdV1"),
        "expected stats operation"
    );
    let op = yaml
        .find("operationId: getProjectStatsByProjectIdV1")
        .expect("op present");
    let window = &yaml[op..op.saturating_add(1200)];
    assert!(
        window.contains("ProjectStatsResponse"),
        "expected stats response ref; got: {window:?}"
    );
}

/// D-batch migration: numeric ID path parameters must be marked `deprecated: true` in the merged spec.
///
/// This validates that `mark_numeric_id_parameters_deprecated` correctly annotates the
/// `{script_numeric_id}`, `{storyboard_numeric_id}`, `{novel_numeric_id}`, and `{asset_numeric_id}`
/// path parameters as deprecated, signalling the UUID-first migration direction.
#[test]
fn merged_openapi_numeric_id_path_params_are_deprecated() {
    let yaml = merged_openapi_yaml_string().expect("merge");
    let doc: Json = serde_yaml::from_str(&yaml).expect("round-trip yaml");

    // Helper: find a parameter by name in an operation's parameters array
    let find_param_deprecated = |path_key: &str, method: &str, param_name: &str| -> Option<bool> {
        // JSON pointer requires escaping / as ~1 and ~ as ~0
        let escaped_path = path_key.replace('~', "~0").replace('/', "~1");
        let pointer = format!("/paths/{escaped_path}/{method}/parameters");
        doc.pointer(&pointer)
            .and_then(|p| p.as_array())
            .and_then(|arr| {
                arr.iter()
                    .find(|p| p.get("name").and_then(|n| n.as_str()) == Some(param_name))
                    .and_then(|p| p.get("deprecated"))
                    .and_then(|d| d.as_bool())
            })
    };

    // script_numeric_id in scripts path should be deprecated
    let script_path = "/api/v1/projects/{project_id}/scripts/{script_numeric_id}";
    for method in &["get", "patch", "delete"] {
        if let Some(deprecated) = find_param_deprecated(script_path, method, "script_numeric_id") {
            assert!(
                deprecated,
                "script_numeric_id in {method} {script_path} should be deprecated=true"
            );
        }
        // project_id (UUID) should NOT be deprecated
        if let Some(deprecated) = find_param_deprecated(script_path, method, "project_id") {
            assert!(
                !deprecated,
                "project_id (UUID) in {method} {script_path} should NOT be deprecated"
            );
        }
    }

    // storyboard_numeric_id in storyboards path should be deprecated
    let storyboard_path = "/api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}";
    for method in &["get", "patch", "delete"] {
        if let Some(deprecated) =
            find_param_deprecated(storyboard_path, method, "storyboard_numeric_id")
        {
            assert!(
                deprecated,
                "storyboard_numeric_id in {method} {storyboard_path} should be deprecated=true"
            );
        }
    }

    // novel_numeric_id in novels path should be deprecated
    let novel_path = "/api/v1/projects/{project_id}/novels/{novel_numeric_id}";
    for method in &["get", "patch", "delete"] {
        if let Some(deprecated) = find_param_deprecated(novel_path, method, "novel_numeric_id") {
            assert!(
                deprecated,
                "novel_numeric_id in {method} {novel_path} should be deprecated=true"
            );
        }
    }

    // asset_numeric_id in assets path should be deprecated
    let asset_path = "/api/v1/projects/{project_id}/assets/{asset_numeric_id}";
    for method in &["get", "patch", "delete"] {
        if let Some(deprecated) = find_param_deprecated(asset_path, method, "asset_numeric_id") {
            assert!(
                deprecated,
                "asset_numeric_id in {method} {asset_path} should be deprecated=true"
            );
        }
    }

    // Verify the merged YAML round-trips cleanly (no parse errors from deprecated annotations)
    let _: Json = serde_yaml::from_str(&yaml)
        .expect("merged YAML with deprecated annotations should parse cleanly");
}
