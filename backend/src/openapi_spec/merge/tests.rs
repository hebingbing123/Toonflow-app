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
