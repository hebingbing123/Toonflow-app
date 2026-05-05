//! Publish preparation validation (short-video-space **E4** / 需求 5.3).

use serde_json::Value;

use crate::publish::types::{PublishDraftRow, PublishPrepareIssue, PublishTargetRow};

#[derive(Clone, Copy)]
pub(crate) struct PlatformPublishSpec {
    pub platform_id: &'static str,
    pub label_zh: &'static str,
    pub automation_default: &'static str,
    pub title_max_chars: i32,
    pub requires_cover: bool,
    pub notes: &'static str,
}

/// Nine-platform matrix skeleton (**E12** / F6 前先给出契约与占位约束).
pub(crate) const PLATFORM_SPECS: &[PlatformPublishSpec] = &[
    PlatformPublishSpec {
        platform_id: "douyin",
        label_zh: "抖音",
        automation_default: "semi_auto",
        title_max_chars: 80,
        requires_cover: true,
        notes: "竖屏优先；标题长度按官方上限收紧占位校验",
    },
    PlatformPublishSpec {
        platform_id: "bilibili",
        label_zh: "哔哩哔哩",
        automation_default: "semi_auto",
        title_max_chars: 80,
        requires_cover: true,
        notes: "分区与标签策略后续随 adapter 细化",
    },
    PlatformPublishSpec {
        platform_id: "xiaohongshu",
        label_zh: "小红书",
        automation_default: "semi_auto",
        title_max_chars: 60,
        requires_cover: true,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "weixin_channels",
        label_zh: "视频号",
        automation_default: "semi_auto",
        title_max_chars: 60,
        requires_cover: true,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "kuaishou",
        label_zh: "快手",
        automation_default: "semi_auto",
        title_max_chars: 80,
        requires_cover: true,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "tiktok",
        label_zh: "TikTok",
        automation_default: "semi_auto",
        title_max_chars: 220,
        requires_cover: false,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "youtube_shorts",
        label_zh: "YouTube Shorts",
        automation_default: "semi_auto",
        title_max_chars: 100,
        requires_cover: false,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "instagram_reels",
        label_zh: "Instagram Reels",
        automation_default: "semi_auto",
        title_max_chars: 120,
        requires_cover: false,
        notes: "",
    },
    PlatformPublishSpec {
        platform_id: "facebook_reels",
        label_zh: "Facebook Reels",
        automation_default: "semi_auto",
        title_max_chars: 120,
        requires_cover: false,
        notes: "",
    },
];

pub(crate) fn spec_for_platform(platform_id: &str) -> Option<&'static PlatformPublishSpec> {
    PLATFORM_SPECS.iter().find(|s| s.platform_id == platform_id)
}

pub(crate) fn validate_automation_mode(mode: &str) -> Result<(), &'static str> {
    match mode {
        "full_auto" | "semi_auto" | "manual_assisted" => Ok(()),
        _ => Err("automation_mode must be full_auto, semi_auto, or manual_assisted"),
    }
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

    issues
}

fn platform_title_for_copy(platform_copy: &Value, platform_id: &str) -> Option<String> {
    let obj = platform_copy.as_object()?;
    let plat = obj.get(platform_id)?;
    plat.get("title")?.as_str().map(|s| s.to_string())
}
