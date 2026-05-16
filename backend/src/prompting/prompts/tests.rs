use super::defaults::DEFAULT_SLOTS;
use super::merge::{merge_slot, slot_by_numeric_id};
use super::types::{PatchPromptBody, UserPromptRow};

#[test]
fn patch_prompt_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<PatchPromptBody>(r#"{"data":"x","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn patch_prompt_body_accepts_valid() {
    let b: PatchPromptBody = serde_json::from_str(r#"{"data":"test prompt"}"#).unwrap();
    assert_eq!(b.data, "test prompt");
}

#[test]
fn default_slots_have_unique_numeric_ids() {
    let mut ids: Vec<i32> = DEFAULT_SLOTS.iter().map(|s| s.numeric_id).collect();
    ids.sort();
    ids.dedup();
    assert_eq!(ids.len(), DEFAULT_SLOTS.len());
}

#[test]
fn slot_by_numeric_id_finds_existing() {
    assert!(slot_by_numeric_id(1).is_some());
    assert!(slot_by_numeric_id(2).is_some());
    assert!(slot_by_numeric_id(3).is_some());
}

#[test]
fn slot_by_numeric_id_returns_none_for_invalid() {
    assert!(slot_by_numeric_id(999).is_none());
}

#[test]
fn merge_slot_uses_defaults_when_no_row() {
    let def = &DEFAULT_SLOTS[0];
    let merged = merge_slot(def, None);
    assert_eq!(merged.id, def.numeric_id);
    assert_eq!(merged.name, def.name);
    assert_eq!(merged.prompt_type, def.kind);
    assert_eq!(merged.data, def.body);
}

#[test]
fn merge_slot_uses_row_values_when_present() {
    let def = &DEFAULT_SLOTS[0];
    let row = UserPromptRow {
        numeric_id: def.numeric_id,
        name: Some("Custom Name".to_string()),
        kind: "customKind".to_string(),
        body: "custom body".to_string(),
    };
    let merged = merge_slot(def, Some(&row));
    assert_eq!(merged.id, def.numeric_id);
    assert_eq!(merged.name, "Custom Name");
    assert_eq!(merged.prompt_type, "customKind");
    assert_eq!(merged.data, "custom body");
}

#[test]
fn merge_slot_uses_default_name_when_row_name_empty() {
    let def = &DEFAULT_SLOTS[0];
    let row = UserPromptRow {
        numeric_id: def.numeric_id,
        name: Some("   ".to_string()),
        kind: "customKind".to_string(),
        body: "custom body".to_string(),
    };
    let merged = merge_slot(def, Some(&row));
    assert_eq!(merged.name, def.name);
}
