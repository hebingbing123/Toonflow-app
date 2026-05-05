//! Publish preparation validation (short-video-space **E4** / 需求 5.3).

use std::collections::HashSet;

use serde_json::Value;

use crate::publish::copy_validate;
use crate::publish::platform_registry::spec_for_platform;
use crate::publish::types::{
    PublishDraftRow, PublishPrepareIssue, PublishTargetInput, PublishTargetRow,
};

pub(crate) fn validate_automation_mode(mode: &str) -> Result<(), &'static str> {
    match mode {
        "full_auto" | "semi_auto" | "manual_assisted" => Ok(()),
        _ => Err("automation_mode must be full_auto, semi_auto, or manual_assisted"),
    }
}

/// Targets-only checks for **`POST …/publish/validate-copy`** (**F**).
pub(crate) fn prepare_issues_target_inputs_only(
    targets: &[PublishTargetInput],
) -> Vec<PublishPrepareIssue> {
    let mut issues = Vec::new();
    let mut seen_platforms = HashSet::new();

    if targets.is_empty() {
        issues.push(PublishPrepareIssue {
            code: "missing_targets".into(),
            message: "请至少添加一个发布平台目标".into(),
            platform_id: None,
            severity: "blocking".into(),
        });
        return issues;
    }

    for t in targets {
        let platform_id = t.platform_id.trim();
        if platform_id.is_empty() {
            issues.push(PublishPrepareIssue {
                code: "missing_platform_id".into(),
                message: "platform_id 不能为空".into(),
                platform_id: None,
                severity: "blocking".into(),
            });
            continue;
        }

        if !seen_platforms.insert(platform_id.to_string()) {
            issues.push(PublishPrepareIssue {
                code: "duplicate_platform".into(),
                message: format!("平台 `{platform_id}` 重复出现，请保留一条目标"),
                platform_id: Some(platform_id.to_string()),
                severity: "blocking".into(),
            });
            continue;
        }

        if validate_automation_mode(&t.automation_mode).is_err() {
            issues.push(PublishPrepareIssue {
                code: "invalid_automation_mode".into(),
                message: format!("平台 {platform_id} 的 automation_mode 非法"),
                platform_id: Some(platform_id.to_string()),
                severity: "blocking".into(),
            });
            continue;
        }

        if t.serial_order < 0 {
            issues.push(PublishPrepareIssue {
                code: "negative_serial_order".into(),
                message: format!("平台 {platform_id} 的 serial_order 不能为负数"),
                platform_id: Some(platform_id.to_string()),
                severity: "blocking".into(),
            });
            continue;
        }

        let Some(_spec) = spec_for_platform(platform_id) else {
            issues.push(PublishPrepareIssue {
                code: "unknown_platform".into(),
                message: format!("未知平台 `{platform_id}`（请先接入矩阵）"),
                platform_id: Some(platform_id.to_string()),
                severity: "blocking".into(),
            });
            continue;
        };
    }

    issues
}

pub(crate) fn prepare_check_for_draft(
    draft: &PublishDraftRow,
    targets: &[PublishTargetRow],
) -> Vec<PublishPrepareIssue> {
    let mut issues = Vec::new();

    if draft.title.trim().is_empty() {
        issues.push(PublishPrepareIssue {
            code: "missing_title".into(),
            message: "发布标题不能为空".into(),
            platform_id: None,
            severity: "blocking".into(),
        });
    }

    if draft
        .video_asset_key
        .as_ref()
        .map(|s| s.trim().is_empty())
        .unwrap_or(true)
    {
        issues.push(PublishPrepareIssue {
            code: "missing_video".into(),
            message: "尚未绑定成片视频引用（video_asset_key）".into(),
            platform_id: None,
            severity: "blocking".into(),
        });
    }

    if targets.is_empty() {
        issues.push(PublishPrepareIssue {
            code: "missing_targets".into(),
            message: "请至少添加一个发布平台目标".into(),
            platform_id: None,
            severity: "blocking".into(),
        });
        return issues;
    }

    for t in targets {
        if validate_automation_mode(&t.automation_mode).is_err() {
            issues.push(PublishPrepareIssue {
                code: "invalid_automation_mode".into(),
                message: format!("平台 {} 的 automation_mode 非法", t.platform_id),
                platform_id: Some(t.platform_id.clone()),
                severity: "blocking".into(),
            });
            continue;
        }

        let Some(spec) = spec_for_platform(&t.platform_id) else {
            issues.push(PublishPrepareIssue {
                code: "unknown_platform".into(),
                message: format!("未知平台 `{}`（请先接入矩阵）", t.platform_id),
                platform_id: Some(t.platform_id.clone()),
                severity: "blocking".into(),
            });
            continue;
        };

        let title_for_platform = platform_title_for_copy(&draft.platform_copy.0, &t.platform_id)
            .unwrap_or_else(|| draft.title.clone());

        if title_for_platform.chars().count() > spec.title_max_chars as usize {
            issues.push(PublishPrepareIssue {
                code: "title_too_long".into(),
                message: format!(
                    "标题超过 {} 字符上限（当前 {}）",
                    spec.title_max_chars,
                    title_for_platform.chars().count()
                ),
                platform_id: Some(t.platform_id.clone()),
                severity: "blocking".into(),
            });
        }

        if spec.requires_cover {
            let cover_ok = draft
                .cover_asset_key
                .as_ref()
                .map(|s| !s.trim().is_empty())
                .unwrap_or(false);
            if !cover_ok {
                issues.push(PublishPrepareIssue {
                    code: "missing_cover".into(),
                    message: format!("{} 需要封面（cover_asset_key）", spec.label_zh),
                    platform_id: Some(t.platform_id.clone()),
                    severity: "blocking".into(),
                });
            }
        }
    }

    issues.extend(copy_validate::adapter_copy_issues_for_targets(
        &draft.platform_copy.0,
        targets,
    ));

    issues
}

fn platform_title_for_copy(platform_copy: &Value, platform_id: &str) -> Option<String> {
    let obj = platform_copy.as_object()?;
    let plat = obj.get(platform_id)?;
    plat.get("title")?.as_str().map(|s| s.to_string())
}

#[cfg(test)]
mod tests {
    use super::{prepare_issues_target_inputs_only, validate_automation_mode};
    use crate::publish::types::PublishTargetInput;
    use serde_json::Value;

    fn target(platform_id: &str, automation_mode: &str, serial_order: i32) -> PublishTargetInput {
        PublishTargetInput {
            platform_id: platform_id.to_string(),
            automation_mode: automation_mode.to_string(),
            serial_order,
            extra: Value::Object(Default::default()),
        }
    }

    #[test]
    fn automation_mode_accepts_known_values() {
        assert!(validate_automation_mode("full_auto").is_ok());
        assert!(validate_automation_mode("semi_auto").is_ok());
        assert!(validate_automation_mode("manual_assisted").is_ok());
    }

    #[test]
    fn target_input_checks_duplicate_unknown_and_negative_order() {
        let issues = prepare_issues_target_inputs_only(&[
            target("douyin", "semi_auto", 0),
            target("douyin", "semi_auto", 1),
            target("mystery_platform", "semi_auto", 0),
            target("bilibili", "semi_auto", -1),
        ]);
        let codes = issues
            .iter()
            .map(|issue| issue.code.as_str())
            .collect::<Vec<_>>();
        assert!(codes.contains(&"duplicate_platform"));
        assert!(codes.contains(&"unknown_platform"));
        assert!(codes.contains(&"negative_serial_order"));
    }
}
