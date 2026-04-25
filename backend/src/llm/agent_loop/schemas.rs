//! OpenAI `tools[].function.parameters` JSON Schema，与 Harness 工具目录对齐。

use serde_json::{json, Value};

use crate::harness::tools::ToolRegistry;

fn tool_parameters_schema(name: &str) -> Value {
    match name {
        "skills.read" => json!({
            "type": "object",
            "required": ["path"],
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Relative path under data/skills (same rules as REST GET /api/v1/skills/content)"
                }
            },
            "additionalProperties": false
        }),
        "get_script_content" => json!({
            "type": "object",
            "properties": {
                "scriptId": {
                    "type": "integer",
                    "description": "Numeric script id under the attached project; optional when attached production context already contains script_id."
                },
                "relativeOffset": {
                    "type": "integer",
                    "description": "Optional non-zero offset relative to the base script id (for example -1 reads the previous episode, +1 reads the next episode)."
                },
                "lineStart": { "type": "integer", "minimum": 1 },
                "lineEnd": { "type": "integer", "minimum": 1 },
                "maxChars": { "type": "integer", "minimum": 1 },
                "fields": {
                    "type": "array",
                    "items": { "type": "string", "enum": ["numeric_id", "name", "content", "extract_state"] },
                    "description": "Optional field subset to reduce payload size."
                }
            },
            "additionalProperties": false
        }),
        "get_planData" => json!({
            "type": "object",
            "properties": {
                "key": {
                    "type": "string",
                    "enum": ["storySkeleton", "adaptationStrategy", "script"],
                    "description": "Optional specific plan section; when set, returns only that section instead of the full wrapper."
                },
                "scriptId": {
                    "type": "integer",
                    "description": "Optional numeric script id filter when key=script."
                },
                "lineStart": { "type": "integer", "minimum": 1 },
                "lineEnd": { "type": "integer", "minimum": 1 },
                "maxChars": { "type": "integer", "minimum": 1 },
                "offset": { "type": "integer", "minimum": 0 },
                "limit": { "type": "integer", "minimum": 1 },
                "fields": {
                    "type": "array",
                    "items": { "type": "string", "enum": ["numeric_id", "name", "content", "extract_state"] },
                    "description": "Optional script-row field subset when key=script."
                }
            },
            "additionalProperties": false
        }),
        "get_novel_text" | "get_novel_events" => json!({
            "type": "object",
            "properties": {
                "novelId": {
                    "type": "integer",
                    "description": "Optional numeric chapter id to narrow reads within the attached project; when omitted, the server now returns only a compact first window by default."
                },
                "lineStart": { "type": "integer", "minimum": 1 },
                "lineEnd": { "type": "integer", "minimum": 1 },
                "maxChars": { "type": "integer", "minimum": 1 },
                "offset": { "type": "integer", "minimum": 0 },
                "limit": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Optional row cap. Defaults are compact: get_novel_text=1 chapter window, get_novel_events=8 event rows."
                },
                "fields": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Optional field subset to reduce payload size. Defaults are already compact when omitted: get_novel_text => [numeric_id, chapter_index, chapter, chapter_data], get_novel_events => [numeric_id, name, detail]."
                }
            },
            "additionalProperties": false
        }),
        "get_flowData" => json!({
            "type": "object",
            "required": ["key"],
            "properties": {
                "key": {
                    "type": "string",
                    "enum": ["script", "scriptPlan", "assets", "storyboardTable", "storyboard", "stoaryTable"],
                    "description": "Production workbench flow data key (`stoaryTable` is accepted as historical typo alias). When extra filters are omitted, the server now defaults to compact reads by key: script/scriptPlan => text windows, storyboardTable => first-row window, assets/storyboard => trimmed field subsets."
                },
                "scriptId": {
                    "type": "integer",
                    "description": "Optional numeric script id; defaults to attached script context."
                },
                "format": {
                    "type": "string",
                    "enum": ["full", "idList", "count"],
                    "description": "Optional payload compaction mode for array-based keys. Even with format=full, omitted filters now fall back to compact key-specific defaults."
                },
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "description": "Optional id filter for assets/storyboard arrays, or exact storyboardTable row ids when key=storyboardTable."
                },
                "assetTypes": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Optional type filter for assets arrays."
                },
                "relatedAssetIds": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "description": "Optional associated asset filter for storyboard arrays."
                },
                "fields": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Optional object field subset; for key=storyboardTable also accepts column aliases such as id, description, scene, duration, camera, cameraMove, lines, sound, associateAssetsIds."
                },
                "lineStart": { "type": "integer", "minimum": 1 },
                "lineEnd": { "type": "integer", "minimum": 1 },
                "maxChars": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Optional text cap. Compact defaults are applied when omitted: script≈1800 chars, scriptPlan≈2200 chars."
                },
                "rowStart": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "For key=storyboardTable: optional 1-based data-row start for compact table reads."
                },
                "rowCount": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "For key=storyboardTable: optional number of data rows to return. Defaults to a compact 8-row window when omitted together with rowStart/fields."
                },
                "offset": { "type": "integer", "minimum": 0 },
                "limit": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Optional row cap. Compact defaults are applied when omitted for broad assets/storyboard reads."
                }
            },
            "additionalProperties": false
        }),
        "add_deriveAsset" => json!({
            "type": "object",
            "required": ["assetsId", "name", "desc"],
            "properties": {
                "assetsId": { "type": "integer", "description": "Parent asset numeric id." },
                "id": { "type": ["integer", "null"], "description": "Derived asset numeric id; null means create new." },
                "name": { "type": "string" },
                "desc": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional numeric script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "del_deriveAsset" => json!({
            "type": "object",
            "required": ["assetsId", "id"],
            "properties": {
                "assetsId": { "type": "integer", "description": "Parent asset numeric id." },
                "id": { "type": "integer", "description": "Derived asset numeric id to delete." },
                "scriptId": { "type": "integer", "description": "Optional numeric script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "generate_deriveAsset" => json!({
            "type": "object",
            "required": ["ids"],
            "properties": {
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Derived asset numeric ids."
                },
                "model": { "type": "string" },
                "resolution": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional numeric script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "generate_storyboard" => json!({
            "type": "object",
            "required": ["ids"],
            "properties": {
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Storyboard numeric ids."
                },
                "model": { "type": "string" },
                "resolution": { "type": "string" },
                "scriptId": { "type": "integer", "description": "Optional numeric script id; defaults to attached script context." }
            },
            "additionalProperties": false
        }),
        "run_sub_agent_storySkeleton"
        | "run_sub_agent_adaptationStrategy"
        | "run_sub_agent_script"
        | "run_supervision_agent"
        | "run_sub_agent_derive_assets"
        | "run_sub_agent_generate_assets"
        | "run_sub_agent_director_plan"
        | "run_sub_agent_storyboard_gen"
        | "run_sub_agent_storyboard_panel"
        | "run_sub_agent_storyboard_table"
        | "run_sub_agent_production_supervision" => json!({
            "type": "object",
            "required": ["prompt"],
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": "Sub-agent task prompt (concise instruction, <= 2000 chars)."
                },
                "assetIds": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Optional focused production asset numeric ids."
                },
                "assetTypes": {
                    "type": "array",
                    "items": { "type": "string", "enum": ["role", "scene", "tool"] },
                    "minItems": 1,
                    "description": "Optional focused production asset type scope when exact ids are not yet known."
                },
                "storyboardIds": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "minItems": 1,
                    "description": "Optional focused production storyboard numeric ids."
                }
            },
            "additionalProperties": false
        }),
        _ => json!({
            "type": "object",
            "description": "JSON arguments for this tool (echo / isolated.echo accept any shape; wasm.probe ignores args)",
            "additionalProperties": true
        }),
    }
}

/// OpenAI Chat Completions `tools` array built from the static Harness catalog.
#[must_use]
pub(super) fn harness_openai_tools() -> Vec<Value> {
    ToolRegistry::catalog()
        .iter()
        .map(|t| {
            json!({
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": tool_parameters_schema(t.name),
                }
            })
        })
        .collect()
}
