//! **F2** — `platform_copy` 结构与平台 adapter 占位约束校验。

use serde_json::Value;

use crate::publish::platform_registry::spec_for_platform;
use crate::publish::types::{PublishPrepareIssue, PublishTargetInput, PublishTargetRow};

fn platform_title_for_copy(platform_copy: &Value, platform_id: &str) -> Option<String> {
    let obj = platform_copy.as_object()?;
    let plat = obj.get(platform_id)?;
    plat.get("title")?.as_str().map(|s| s.to_string())
}

fn platform_description_for_copy(platform_copy: &Value, platform_id: &str) -> Option<String> {
    let obj = platform_copy.as_object()?;
    let plat = obj.get(platform_id)?;
    plat.get("description")?.as_str().map(|s| s.to_string())
}

fn platform_tags_len(platform_copy: &Value, platform_id: &str) -> Option<usize> {
    let obj = platform_copy.as_object()?;
    let plat = obj.get(platform_id)?;
    let tags = plat.get("tags")?.as_array()?;
    Some(tags.len())
}

pub(crate) fn adapter_copy_issues_for_targets(
    platform_copy: &Value,
    targets: &[PublishTargetRow],
) -> Vec<PublishPrepareIssue> {
    let ids: Vec<String> = targets.iter().map(|t| t.platform_id.clone()).collect();
    adapter_copy_issues(platform_copy, &ids)
}

pub(crate) fn adapter_copy_issues_for_inputs(
    platform_copy: &Value,
    targets: &[PublishTargetInput],
) -> Vec<PublishPrepareIssue> {
    let ids: Vec<String> = targets.iter().map(|t| t.platform_id.clone()).collect();
    adapter_copy_issues(platform_copy, &ids)
}

fn adapter_copy_issues(platform_copy: &Value, platform_ids: &[String]) -> Vec<PublishPrepareIssue> {
    let mut issues = Vec::new();

    let Some(obj) = platform_copy.as_object() else {
        if !platform_ids.is_empty() {
            issues.push(PublishPrepareIssue {
                code: "platform_copy_not_object".into(),
                message: "platform_copy 应为 JSON object".into(),
                platform_id: None,
                severity: "blocking".into(),
            });
        }
        return issues;
    };

    for pid in platform_ids {
        let pid = pid.as_str();
        let Some(spec) = spec_for_platform(pid) else {
            continue;
        };

        if !obj.contains_key(pid) {
            issues.push(PublishPrepareIssue {
                code: "missing_platform_copy_block".into(),
                message: format!(
                    "缺少平台 `{}` 的差异化文案块（建议在 platform_copy[\"{pid}\"]）",
                    spec.label_zh
                ),
                platform_id: Some(pid.to_string()),
                severity: "warning".into(),
            });
            continue;
        }

        let Some(plat_obj) = obj.get(pid).and_then(|v| v.as_object()) else {
            issues.push(PublishPrepareIssue {
                code: "platform_copy_block_not_object".into(),
                message: format!("platform_copy[\"{pid}\"] 应为 JSON object"),
                platform_id: Some(pid.to_string()),
                severity: "blocking".into(),
            });
            continue;
        };

        for key in plat_obj.keys() {
            if !matches!(key.as_str(), "title" | "description" | "tags") {
                issues.push(PublishPrepareIssue {
                    code: "unknown_platform_copy_field".into(),
                    message: format!("未知字段 `{key}`（仅允许 title/description/tags）"),
                    platform_id: Some(pid.to_string()),
                    severity: "warning".into(),
                });
            }
        }

        if let Some(title) = platform_title_for_copy(platform_copy, pid) {
            if title.chars().count() > spec.title_max_chars as usize {
                issues.push(PublishPrepareIssue {
                    code: "adapter_title_too_long".into(),
                    message: format!(
                        "差异化标题超过 {} 字（当前 {}）",
                        spec.title_max_chars,
                        title.chars().count()
                    ),
                    platform_id: Some(pid.to_string()),
                    severity: "blocking".into(),
                });
            }
        }

        if let Some(desc) = platform_description_for_copy(platform_copy, pid) {
            if desc.chars().count() > spec.description_max_chars as usize {
                issues.push(PublishPrepareIssue {
                    code: "adapter_description_too_long".into(),
                    message: format!(
                        "差异化简介超过 {} 字（当前 {}）",
                        spec.description_max_chars,
                        desc.chars().count()
                    ),
                    platform_id: Some(pid.to_string()),
                    severity: "blocking".into(),
                });
            }
        }

        if let Some(n) = platform_tags_len(platform_copy, pid) {
            if n > spec.tags_max as usize {
                issues.push(PublishPrepareIssue {
                    code: "adapter_tags_too_many".into(),
                    message: format!("标签个数超过上限 {}（当前 {n}）", spec.tags_max),
                    platform_id: Some(pid.to_string()),
                    severity: "blocking".into(),
                });
            }
        }
    }

    issues
}
