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

#[derive(Debug, Clone, PartialEq, Eq)]
struct StoryboardTableSelection<'a> {
    row_start: usize,
    row_count: usize,
    columns: Option<&'a Vec<String>>,
}

fn normalize_storyboard_table_column(column: &str) -> String {
    match column.trim() {
        "id" | "序号" => "id".into(),
        "description" | "画面描述" => "description".into(),
        "scene" | "场景" => "scene".into(),
        "associateAssetsNames" | "关联资产名称" => "associateAssetsNames".into(),
        "duration" | "时长" => "duration".into(),
        "camera" | "景别" => "camera".into(),
        "cameraMove" | "运镜" => "cameraMove".into(),
        "action" | "角色动作" => "action".into(),
        "emotion" | "情绪" => "emotion".into(),
        "lighting" | "光影氛围" => "lighting".into(),
        "lines" | "台词" => "lines".into(),
        "sound" | "音效" => "sound".into(),
        "associateAssetsIds" | "关联资产ID" | "关联资产Ids" => "associateAssetsIds".into(),
        other => other.to_string(),
    }
}

fn parse_storyboard_table_markdown(text: &str) -> Option<(Vec<String>, Vec<Vec<String>>)> {
    let mut table_lines = text
        .lines()
        .map(str::trim)
        .filter(|line| line.starts_with('|') && line.ends_with('|'))
        .collect::<Vec<_>>();
    if table_lines.len() < 2 {
        return None;
    }
    let header_line = table_lines.remove(0);
    let separator_line = table_lines.remove(0);
    if !separator_line.contains('-') {
        return None;
    }
    let headers = header_line
        .trim_matches('|')
        .split('|')
        .map(|cell| normalize_storyboard_table_column(cell.trim()))
        .collect::<Vec<_>>();
    if headers.is_empty() {
        return None;
    }
    let rows = table_lines
        .into_iter()
        .filter_map(|line| {
            let cells = line
                .trim_matches('|')
                .split('|')
                .map(|cell| cell.trim().to_string())
                .collect::<Vec<_>>();
            if cells.len() == headers.len() {
                Some(cells)
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    Some((headers, rows))
}

fn select_storyboard_table_window(text: &str, selection: StoryboardTableSelection<'_>) -> Value {
    let Some((headers, rows)) = parse_storyboard_table_markdown(text) else {
        return Value::String(text.to_string());
    };
    let selected_columns = selection.columns.map(|columns| {
        columns
            .iter()
            .map(|column| normalize_storyboard_table_column(column))
            .collect::<Vec<_>>()
    });
    let total_rows = rows.len();
    let start = selection.row_start.saturating_sub(1).min(total_rows);
    let end = start.saturating_add(selection.row_count).min(total_rows);
    let out_rows = rows[start..end]
        .iter()
        .map(|row| {
            let mut map = serde_json::Map::new();
            for (idx, header) in headers.iter().enumerate() {
                if selected_columns
                    .as_ref()
                    .is_some_and(|columns| !columns.contains(header))
                {
                    continue;
                }
                if let Some(cell) = row.get(idx) {
                    map.insert(header.clone(), Value::String(cell.clone()));
                }
            }
            Value::Object(map)
        })
        .collect::<Vec<_>>();
    serde_json::json!({
        "table": "storyboardTable",
        "rowStart": selection.row_start,
        "rowCount": out_rows.len(),
        "totalRows": total_rows,
        "columns": selected_columns.unwrap_or(headers),
        "rows": out_rows,
    })
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
    let row_start = parse_optional_usize(arguments, "rowStart")?;
    let row_count = parse_optional_usize(arguments, "rowCount")?;
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
            if mapped_key == "storyboardTable"
                && (row_start.is_some() || row_count.is_some() || fields.is_some())
            {
                select_storyboard_table_window(
                    &text,
                    StoryboardTableSelection {
                        row_start: row_start.unwrap_or(1),
                        row_count: row_count.unwrap_or(8),
                        columns: fields.as_ref(),
                    },
                )
            } else {
                Value::String(apply_text_window(&text, line_start, line_end, max_chars))
            }
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

#[cfg(test)]
mod tests {
    use super::{
        normalize_storyboard_table_column, parse_storyboard_table_markdown,
        select_storyboard_table_window, StoryboardTableSelection,
    };

    const STORYBOARD_TABLE: &str = r#"
| 序号 | 画面描述 | 场景 | 关联资产名称 | 时长 | 景别 | 运镜 | 角色动作 | 情绪 | 光影氛围 | 台词 | 音效 | 关联资产ID |
|----|-------------|------|----------|------|------|------|------|------|------|-------|-------|----------|
| 1 | 首镜 | 大殿 | [苏晚卿, 大殿] | 4 | 近景 | 静止 | 冷笑 | 冷傲 | 顶光 | 无台词 | 风声 | [101, 300] |
| 2 | 次镜 | 大殿 | [凌玄, 大殿] | 3 | 中景 | 推 | 吐血 | 压迫 | 逆光 | 无台词 | 喷血声 | [100, 300] |
"#;

    #[test]
    fn normalize_storyboard_table_column_maps_aliases() {
        assert_eq!(normalize_storyboard_table_column("景别"), "camera");
        assert_eq!(
            normalize_storyboard_table_column("associateAssetsIds"),
            "associateAssetsIds"
        );
    }

    #[test]
    fn parse_storyboard_table_markdown_returns_headers_and_rows() {
        let (headers, rows) = parse_storyboard_table_markdown(STORYBOARD_TABLE).expect("table");
        assert_eq!(headers.first().map(String::as_str), Some("id"));
        assert_eq!(headers.get(5).map(String::as_str), Some("camera"));
        assert_eq!(rows.len(), 2);
    }

    #[test]
    fn select_storyboard_table_window_returns_compact_rows() {
        let selected = select_storyboard_table_window(
            STORYBOARD_TABLE,
            StoryboardTableSelection {
                row_start: 2,
                row_count: 1,
                columns: Some(&vec!["id".into(), "scene".into(), "duration".into()]),
            },
        );
        assert_eq!(selected["totalRows"].as_u64(), Some(2));
        assert_eq!(selected["rowStart"].as_u64(), Some(2));
        assert_eq!(selected["rowCount"].as_u64(), Some(1));
        let rows = selected["rows"].as_array().expect("rows");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["id"].as_str(), Some("2"));
        assert_eq!(rows[0]["scene"].as_str(), Some("大殿"));
        assert_eq!(rows[0]["duration"].as_str(), Some("3"));
        assert!(rows[0].get("camera").is_none());
    }
}
