//! 从流程 JSON 中解析 storyboard 顺序（用于保存时写回 `sb_index`）。

use serde_json::{Map, Value};

use crate::error::ApiError;

fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

pub(super) fn ordered_storyboard_numeric_ids(data: &Value) -> Result<Option<Vec<i32>>, ApiError> {
    let object = data
        .as_object()
        .ok_or_else(|| ApiError::BadRequest("data must be a JSON object".into()))?;

    Ok(object
        .get("storyboard")
        .and_then(Value::as_array)
        .and_then(|storyboards| {
            storyboards
                .iter()
                .map(|item| {
                    item.as_object()
                        .and_then(|obj| json_i32(obj, "id"))
                        .filter(|id| *id > 0)
                })
                .collect::<Option<Vec<_>>>()
        }))
}
