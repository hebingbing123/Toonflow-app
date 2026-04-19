use std::collections::HashMap;

use crate::assets::models::*;

pub(super) fn build_nested_assets_response(
    total: i64,
    parents: Vec<WorkbenchGetAssetsApiDbRow>,
    children: Vec<WorkbenchGetAssetsApiDbRow>,
    project_numeric_id: i32,
) -> WorkbenchGetAssetsApiResponse {
    let mut child_map: HashMap<i32, Vec<WorkbenchGetAssetsApiChildItem>> = HashMap::new();
    for row in children {
        let child = WorkbenchGetAssetsApiChildItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(project_numeric_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
        };
        if let Some(parent_id) = child.assets_id {
            child_map.entry(parent_id).or_default().push(child);
        }
    }

    let data = parents
        .into_iter()
        .map(|row| WorkbenchGetAssetsApiParentItem {
            id: row.id,
            project_id: row.project_id.unwrap_or(project_numeric_id),
            asset_type: row.asset_type,
            name: row.name,
            assets_id: row.assets_id,
            image_id: row.image_id,
            src: row.file_path.clone(),
            file_path: row.file_path,
            state: row.state,
            error_reason: row.error_reason,
            son_assets: child_map.remove(&row.id).unwrap_or_default(),
        })
        .collect();

    WorkbenchGetAssetsApiResponse { data, total }
}
