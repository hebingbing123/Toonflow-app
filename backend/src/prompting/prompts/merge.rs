//! 默认槽位与用户行合并。

use super::defaults::{DefaultSlot, DEFAULT_SLOTS};
use super::types::{PromptTemplateJson, UserPromptRow};

pub(super) fn slot_by_numeric_id(id: i32) -> Option<&'static DefaultSlot> {
    DEFAULT_SLOTS.iter().find(|s| s.numeric_id == id)
}

pub(super) fn merge_slot(
    def: &'static DefaultSlot,
    row: Option<&UserPromptRow>,
) -> PromptTemplateJson {
    let name = row
        .and_then(|r| r.name.as_deref())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(def.name)
        .to_string();
    let prompt_type = row.map(|r| r.kind.as_str()).unwrap_or(def.kind).to_string();
    let data = row.map(|r| r.body.as_str()).unwrap_or(def.body).to_string();
    PromptTemplateJson {
        id: def.numeric_id,
        name,
        prompt_type,
        data,
    }
}
