use std::collections::HashMap;

use serde_json::{json, Map, Value};

use super::super::rows::ProductionStoryboardFlowRow;
use super::helpers::json_i32;

pub(crate) fn build_storyboard_items(
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
