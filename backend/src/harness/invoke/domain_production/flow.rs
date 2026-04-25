use serde_json::Value;

use crate::harness::HarnessContext;

use super::super::{
    apply_text_window, map_api_error, parse_optional_i32_array, parse_optional_string_array,
    parse_optional_usize, parse_optional_zero_based_usize, project_numeric_from_ctx, require_pool,
    script_numeric_id_from_args_or_ctx, select_object_fields, InvokeError,
};

struct FlowArraySelection<'a> {
    ids: Option<&'a Vec<i32>>,
    fields: Option<&'a Vec<String>>,
    asset_types: Option<&'a Vec<String>>,
    related_asset_ids: Option<&'a Vec<i32>>,
    offset: usize,
    limit: Option<usize>,
    format: &'a str,
}

fn select_flow_array(value: Value, selection: FlowArraySelection<'_>) -> Value {
    let Some(items) = value.as_array() else {
        return value;
    };
    let filtered = items
        .iter()
        .filter(|item| {
            selection.ids.is_none_or(|ids| {
                item.get("id")
                    .and_then(Value::as_i64)
                    .and_then(|id| i32::try_from(id).ok())
                    .is_some_and(|id| ids.contains(&id))
            })
        })
        .filter(|item| {
            selection.asset_types.is_none_or(|asset_types| {
                item.get("type")
                    .and_then(Value::as_str)
                    .is_some_and(|kind| asset_types.iter().any(|expected| expected == kind))
            })
        })
        .filter(|item| {
            selection.related_asset_ids.is_none_or(|related_ids| {
                item.get("associateAssetsIds")
                    .and_then(Value::as_array)
                    .is_some_and(|ids| {
                        ids.iter().any(|id| {
                            id.as_i64()
                                .and_then(|v| i32::try_from(v).ok())
                                .is_some_and(|v| related_ids.contains(&v))
                        })
                    })
            })
        })
        .skip(selection.offset)
        .take(selection.limit.unwrap_or(usize::MAX))
        .cloned()
        .collect::<Vec<_>>();

    match selection.format {
        "idList" => Value::Array(
            filtered
                .iter()
                .filter_map(|item| item.get("id").cloned())
                .collect(),
        ),
        "count" => serde_json::json!({ "count": filtered.len() }),
        _ => Value::Array(
            filtered
                .into_iter()
                .map(|item| {
                    if let Some(fields) = selection.fields {
                        select_object_fields(&item, fields)
                    } else {
                        item
                    }
                })
                .collect(),
        ),
    }
}

pub(crate) async fn invoke_get_flow_data(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let key = arguments
        .get("key")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("key must be a non-empty string".into()))?;
    let mapped_key = if key == "stoaryTable" {
        "storyboardTable"
    } else {
        key
    };
    let format = arguments
        .get("format")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .unwrap_or("full");
    if !matches!(format, "full" | "idList" | "count") {
        return Err(InvokeError::InvalidArgs(format!(
            "unsupported flow format: {format}"
        )));
    }
    let line_start = parse_optional_usize(arguments, "lineStart")?;
    let line_end = parse_optional_usize(arguments, "lineEnd")?;
    let max_chars = parse_optional_usize(arguments, "maxChars")?;
    let offset = parse_optional_zero_based_usize(arguments, "offset")?.unwrap_or(0);
    let limit = parse_optional_usize(arguments, "limit")?;
    let ids = parse_optional_i32_array(arguments, "ids")?;
    let related_asset_ids = parse_optional_i32_array(arguments, "relatedAssetIds")?;
    let fields = parse_optional_string_array(arguments, "fields")?;
    let asset_types = parse_optional_string_array(arguments, "assetTypes")?;
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;

    let flow = crate::production::flow_data::load_owned_production_flow_json(
        pool,
        ctx.user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await
    .map_err(|e| map_api_error(e, "failed to read production flow data"))?;

    let value = flow
        .get(mapped_key)
        .cloned()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("unsupported flow key: {key}")))?;
    Ok(match value {
        Value::String(text) => {
            Value::String(apply_text_window(&text, line_start, line_end, max_chars))
        }
        Value::Array(_) => select_flow_array(
            value,
            FlowArraySelection {
                ids: ids.as_ref(),
                fields: fields.as_ref(),
                asset_types: asset_types.as_ref(),
                related_asset_ids: related_asset_ids.as_ref(),
                offset,
                limit,
                format,
            },
        ),
        Value::Object(_) if fields.is_some() => {
            select_object_fields(&value, fields.as_ref().expect("checked is_some"))
        }
        other => other,
    })
}
