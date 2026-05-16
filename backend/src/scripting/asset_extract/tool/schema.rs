//! OpenAI tools `parameters` JSON schema。

use serde_json::{json, Value};

pub(super) fn extract_tool_schema() -> Value {
    json!({
        "type": "object",
        "required": ["new_assets", "existing_asset_refs"],
        "properties": {
            "new_assets": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "desc", "type", "script_numeric_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "desc": { "type": "string" },
                        "type": { "type": "string", "enum": ["role", "tool", "scene"] },
                        "script_numeric_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            },
            "existing_asset_refs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "script_numeric_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "script_numeric_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            }
        },
        "additionalProperties": false
    })
}
