use serde_json::{json, Value};

use super::super::rows::ProductionAssetFlowRow;
use super::helpers::history_image_src;

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

pub(crate) fn build_root_assets(rows: &[ProductionAssetFlowRow]) -> Vec<Value> {
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
