use std::collections::HashMap;

use serde_json::{json, Map, Value};

use super::rows::{ProductionAssetFlowRow, ProductionStoryboardFlowRow};

fn json_string(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::to_string)
}

fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

fn history_image_src(metadata: &Value, history_images: &[Value]) -> Option<String> {
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

fn build_production_asset_item(
    row: &ProductionAssetFlowRow,
    child_rows: &[&ProductionAssetFlowRow],
) -> Value {
    let history_images = row.history_images.as_array().cloned().unwrap_or_default();
    let src = history_image_src(&row.metadata, &history_images);
    let prompt = row
        .metadata
        .get("prompt")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let flow_id = row
        .metadata
        .get("flowId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());

    let derive = child_rows
        .iter()
        .map(|child| {
            let child_history = child.history_images.as_array().cloned().unwrap_or_default();
            json!({
              "id": child.numeric_id,
              "assetsId": row.numeric_id,
              "name": child.name,
              "type": child.asset_type,
              "prompt": child.metadata.get("prompt").and_then(Value::as_str).unwrap_or_default(),
              "desc": child.description.clone().unwrap_or_default(),
              "src": history_image_src(&child.metadata, &child_history),
              "state": child.metadata.get("state").and_then(Value::as_str).unwrap_or("未生成"),
              "flowId": child.metadata.get("flowId").and_then(Value::as_i64).and_then(|v| i32::try_from(v).ok()),
              "errorReason": child.metadata.get("errorReason").and_then(Value::as_str).unwrap_or_default(),
            })
        })
        .collect::<Vec<_>>();

    json!({
      "id": row.numeric_id,
      "name": row.name,
      "type": row.asset_type,
      "prompt": prompt,
      "desc": row.description.clone().unwrap_or_default(),
      "src": src,
      "flowId": flow_id,
      "derive": derive,
    })
}

pub(super) fn build_root_assets(rows: &[ProductionAssetFlowRow]) -> Vec<Value> {
    rows.iter()
        .filter(|row| match row.metadata.get("assetsId") {
            None => true,
            Some(v) => v.is_null(),
        })
        .map(|row| {
            let child_rows = rows
                .iter()
                .filter(|child| {
                    child
                        .metadata
                        .get("assetsId")
                        .and_then(Value::as_i64)
                        .and_then(|v| i32::try_from(v).ok())
                        == Some(row.numeric_id)
                })
                .collect::<Vec<_>>();
            build_production_asset_item(row, &child_rows)
        })
        .collect()
}

pub(super) fn build_storyboard_items(
    saved_obj: Option<&Map<String, Value>>,
    storyboards: Vec<ProductionStoryboardFlowRow>,
) -> Vec<Value> {
    let saved_storyboard_by_id = saved_obj
        .and_then(|obj| obj.get("storyboard"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|item| {
            let obj = item.as_object()?.clone();
            Some((json_i32(&obj, "id")?, obj))
        })
        .collect::<HashMap<_, _>>();

    storyboards
        .into_iter()
        .map(|row| {
            let saved_storyboard = saved_storyboard_by_id.get(&row.numeric_id);
            json!({
              "id": row.numeric_id,
              "index": row.sb_index,
              "duration": row.duration.as_deref().and_then(|v| v.parse::<i32>().ok()).unwrap_or(0),
              "prompt": row.prompt.clone().unwrap_or_default(),
              "associateAssetsIds": saved_storyboard
                .and_then(|obj| obj.get("associateAssetsIds"))
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default(),
              "src": row.file_path,
              "state": row.state,
              "videoDesc": row.video_desc,
              "shouldGenerateImage": row.should_generate_image,
              "reason": row.reason.unwrap_or_default(),
              "flowId": row.flow_id,
            })
        })
        .collect()
}

pub(super) fn merge_flow(
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
