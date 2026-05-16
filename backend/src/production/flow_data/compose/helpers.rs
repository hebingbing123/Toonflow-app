use serde_json::{Map, Value};

pub(super) fn json_string(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::to_string)
}

pub(super) fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

pub(super) fn history_image_src(metadata: &Value, history_images: &[Value]) -> Option<String> {
    let selected_numeric_image_id = metadata
        .get("imageId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());
    if let Some(selected_id) = selected_numeric_image_id {
        if let Some(src) = history_images.iter().find_map(|img| {
            let img_obj = img.as_object()?;
            if json_i32(img_obj, "numeric_image_id") == Some(selected_id) {
                return json_string(img_obj, "file_path");
            }
            None
        }) {
            return Some(src);
        }
    }
    history_images.iter().find_map(|img| {
        img.as_object()
            .and_then(|obj| json_string(obj, "file_path"))
    })
}
