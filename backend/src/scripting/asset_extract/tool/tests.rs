use super::filter::filter_tool_new_assets;
use super::types::NewAssetItem;

#[test]
fn filter_new_drops_bad_type() {
    let valid: std::collections::HashSet<i32> = [1].into_iter().collect();
    let out = filter_tool_new_assets(
        vec![NewAssetItem {
            name: "A".into(),
            desc: "d".into(),
            asset_type: "wizard".into(),
            script_numeric_ids: vec![1],
        }],
        &valid,
    );
    assert!(out.is_empty());
}
