//! 将 utoipa 生成的 `paths` / `components` 叠到基座上。

use anyhow::Context;
use serde_json::Value as Json;

const HTTP_METHODS: &[&str] = &[
    "get", "post", "put", "patch", "delete", "options", "head", "trace",
];

pub(super) fn overlay_paths(base: &mut Json, gen: &Json) -> anyhow::Result<()> {
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

/// Rich utoipa overlays request/response when both sides carry content.
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

/// Copy OpenAPI operation fields from `gen_op` onto `base_op`, keeping base-only fields (e.g. `parameters`).
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

pub(super) fn overlay_components_object(
    base: &mut Json,
    gen: &Json,
    key: &str,
) -> anyhow::Result<()> {
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

/// Add `deprecated: true` to numeric ID path parameters where UUID alternatives exist.
///
/// This marks the D-batch numeric ID parameters as deprecated in the OpenAPI spec
/// to signal the migration direction toward UUID-first APIs, without breaking existing clients.
///
/// Affected parameters (path params in routes that also have a UUID `{project_id}`):
/// - `{script_numeric_id}` — prefer UUID-based script lookup via project UUID
/// - `{storyboard_numeric_id}` — prefer UUID-based storyboard lookup via project UUID
/// - `{novel_numeric_id}` — prefer UUID-based novel lookup via project UUID
/// - `{asset_numeric_id}` — prefer UUID-based asset lookup via project UUID
///
/// Column removal is blocked by `promote_import_snapshots()` and job payload compatibility;
/// this annotation signals the migration direction without breaking existing clients.
///
/// See: `docs/plans/tasks-http-api-cleanup.md` H5·D, `.tmp/H3.2_numeric_id_dependency_analysis.md`
pub(super) fn mark_numeric_id_parameters_deprecated(doc: &mut Json) -> anyhow::Result<()> {
    let Some(paths) = doc.get_mut("paths").and_then(|p| p.as_object_mut()) else {
        return Ok(());
    };

    // Numeric ID parameter names that should be marked deprecated when UUID alternatives exist.
    // These are path parameters where the parent resource is already identified by UUID
    // (e.g. `{project_id}` is a UUID), making the numeric child ID a legacy identifier.
    const DEPRECATED_NUMERIC_PARAMS: &[(&str, &str)] = &[
        ("script_numeric_id", "Legacy numeric script id. Prefer UUID-based lookup via project UUID. Will be removed in a future release after import infrastructure migration."),
        ("storyboard_numeric_id", "Legacy numeric storyboard id. Prefer UUID-based lookup via project UUID. Will be removed in a future release after import infrastructure migration."),
        ("novel_numeric_id", "Legacy numeric novel id. Prefer UUID-based lookup via project UUID. Will be removed in a future release after import infrastructure migration."),
        ("asset_numeric_id", "Legacy numeric asset id. Prefer UUID-based lookup via project UUID. Will be removed in a future release after import infrastructure migration."),
    ];

    for (path_key, path_item) in paths.iter_mut() {
        let Some(item_obj) = path_item.as_object_mut() else {
            continue;
        };

        // Determine which numeric params appear in this path template
        let deprecated_in_path: Vec<(&str, &str)> = DEPRECATED_NUMERIC_PARAMS
            .iter()
            .filter(|(param_name, _)| path_key.contains(&format!("{{{param_name}}}")))
            .copied()
            .collect();

        if deprecated_in_path.is_empty() {
            continue;
        }

        for method in HTTP_METHODS {
            let Some(operation) = item_obj.get_mut(*method) else {
                continue;
            };
            let Some(op_obj) = operation.as_object_mut() else {
                continue;
            };

            // Get or create parameters array
            let params = op_obj
                .entry("parameters")
                .or_insert_with(|| Json::Array(vec![]));
            let Some(params_arr) = params.as_array_mut() else {
                continue;
            };

            for (param_name, description) in &deprecated_in_path {
                // Check if parameter already exists
                let existing_idx = params_arr
                    .iter()
                    .position(|p| p.get("name").and_then(|n| n.as_str()) == Some(param_name));

                if let Some(idx) = existing_idx {
                    // Mark existing parameter as deprecated
                    if let Some(param_obj) = params_arr[idx].as_object_mut() {
                        param_obj.insert("deprecated".to_string(), Json::Bool(true));
                    }
                } else {
                    // Inject a new parameter definition with deprecated: true
                    params_arr.push(serde_json::json!({
                        "name": param_name,
                        "in": "path",
                        "required": true,
                        "deprecated": true,
                        "description": description,
                        "schema": {
                            "type": "integer",
                            "format": "int32"
                        }
                    }));
                }
            }
        }
    }

    Ok(())
}
