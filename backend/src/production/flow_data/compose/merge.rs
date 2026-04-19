use serde_json::Value;

pub(crate) fn merge_flow(
    saved: Value,
    script_content: Option<String>,
    root_assets: Vec<Value>,
    storyboard_items: Vec<Value>,
) -> Value {
    let mut merged = saved.as_object().cloned().unwrap_or_default();
    merged.insert(
        "script".into(),
        Value::String(script_content.unwrap_or_default()),
    );
    merged.insert(
        "scriptPlan".into(),
        merged
            .get("scriptPlan")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("assets".into(), Value::Array(root_assets));
    merged.insert(
        "storyboardTable".into(),
        merged
            .get("storyboardTable")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("storyboard".into(), Value::Array(storyboard_items));
    Value::Object(merged)
}
