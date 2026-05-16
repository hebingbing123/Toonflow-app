use serde_json::Value;

pub(in crate::assets) fn merge_workbench_asset_metadata(
    mut metadata: Value,
    prompt_patch: Option<Option<String>>,
    remark_patch: Option<Option<String>>,
    image_id_patch: Option<Option<i32>>,
) -> Value {
    if !metadata.is_object() {
        metadata = Value::Object(Default::default());
    }
    let Some(obj) = metadata.as_object_mut() else {
        return metadata;
    };

    if let Some(next_prompt) = prompt_patch {
        match next_prompt {
            Some(v) => {
                obj.insert("prompt".into(), Value::String(v));
            }
            None => {
                obj.remove("prompt");
            }
        }
    }

    if let Some(next_remark) = remark_patch {
        match next_remark {
            Some(v) => {
                obj.insert("remark".into(), Value::String(v));
            }
            None => {
                obj.remove("remark");
            }
        }
    }

    if let Some(next_image_id) = image_id_patch {
        match next_image_id {
            Some(v) => {
                obj.insert("imageId".into(), Value::from(v));
            }
            None => {
                obj.remove("imageId");
            }
        }
    }

    metadata
}

pub(in crate::assets) fn metadata_cover_numeric_image_id(metadata: &Value) -> Option<i32> {
    let v = metadata.get("imageId")?;
    if v.is_null() {
        return None;
    }
    if let Some(n) = v.as_i64() {
        return i32::try_from(n).ok();
    }
    if let Some(n) = v.as_u64() {
        return i32::try_from(n).ok();
    }
    v.as_str().and_then(|s| s.trim().parse::<i32>().ok())
}
