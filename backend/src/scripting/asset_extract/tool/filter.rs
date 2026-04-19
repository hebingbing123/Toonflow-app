//! 模型输出过滤：类型白名单、去重、脚本 id 校验。

use super::types::{ExistingRefItem, ExistingRefItemFiltered, NewAssetItem, NewAssetItemFiltered};

pub(crate) fn filter_tool_new_assets(
    items: Vec<NewAssetItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<NewAssetItemFiltered> {
    let mut out = Vec::new();
    let mut seen_name: std::collections::HashSet<String> = std::collections::HashSet::new();
    for mut it in items {
        let t = it.asset_type.trim().to_lowercase();
        if t != "role" && t != "tool" && t != "scene" {
            continue;
        }
        let name = it.name.trim().to_string();
        if name.is_empty() || !seen_name.insert(name.clone()) {
            continue;
        }
        it.script_numeric_ids.retain(|id| valid.contains(id));
        if it.script_numeric_ids.is_empty() {
            continue;
        }
        out.push(NewAssetItemFiltered {
            name,
            desc: it.desc,
            asset_type: t,
            script_numeric_ids: it.script_numeric_ids,
        });
    }
    out
}

pub(crate) fn filter_tool_existing(
    items: Vec<ExistingRefItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<ExistingRefItemFiltered> {
    let mut out = Vec::new();
    for mut it in items {
        let name = it.name.trim().to_string();
        if name.is_empty() {
            continue;
        }
        it.script_numeric_ids.retain(|id| valid.contains(id));
        if it.script_numeric_ids.is_empty() {
            continue;
        }
        out.push(ExistingRefItemFiltered {
            name,
            script_numeric_ids: it.script_numeric_ids,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
