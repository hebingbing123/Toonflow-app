//! Publish preparation validation (short-video-space **E4** / 需求 5.3).

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

        let Some(_spec) = spec_for_platform(&t.platform_id) else {
            issues.push(PublishPrepareIssue {
                code: "unknown_platform".into(),
                message: format!("未知平台 `{}`（请先接入矩阵）", t.platform_id),
                platform_id: Some(t.platform_id.clone()),
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
