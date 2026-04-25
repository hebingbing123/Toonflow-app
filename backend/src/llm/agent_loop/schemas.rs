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
                    "description": "Optional numeric novel id to narrow results within the attached project."
                },
                "lineStart": { "type": "integer", "minimum": 1 },
                "lineEnd": { "type": "integer", "minimum": 1 },
                "maxChars": { "type": "integer", "minimum": 1 },
                "offset": { "type": "integer", "minimum": 0 },
                "limit": { "type": "integer", "minimum": 1 },
                "fields": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Optional field subset to reduce payload size."
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
                    "description": "Production workbench flow data key (`stoaryTable` is accepted as historical typo alias)."
                },
                "scriptId": {
                    "type": "integer",
                    "description": "Optional numeric script id; defaults to attached script context."
                },
                "format": {
                    "type": "string",
                    "enum": ["full", "idList", "count"],
                    "description": "Optional payload compaction mode for array-based keys."
                },
                "ids": {
                    "type": "array",
                    "items": { "type": "integer" },
                    "description": "Optional id filter for assets/storyboard arrays."
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
                "maxChars": { "type": "integer", "minimum": 1 },
                "rowStart": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "For key=storyboardTable: optional 1-based data-row start for compact table reads."
                },
                "rowCount": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "For key=storyboardTable: optional number of data rows to return."
                },
                "offset": { "type": "integer", "minimum": 0 },
                "limit": { "type": "integer", "minimum": 1 }
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
