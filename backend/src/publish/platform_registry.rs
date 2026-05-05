//! **F6** — nine-platform capability registry（契约真源；矩阵 UI / 校验 / sandbox adapter 共用）。

use serde_json::{json, Value};
use uuid::Uuid;

use crate::publish::types::PublishPlatformCapabilityRow;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum MarketRegion {
    Domestic,
    Overseas,
}

impl MarketRegion {
    pub(crate) fn as_api_str(self) -> &'static str {
        match self {
            MarketRegion::Domestic => "domestic",
            MarketRegion::Overseas => "overseas",
        }
    }
}

#[derive(Clone, Copy)]
pub(crate) struct PlatformCapability {
    pub(crate) platform_id: &'static str,
    pub(crate) label_zh: &'static str,
    pub(crate) region: MarketRegion,
    /// `full_auto` | `semi_auto` | `manual_assisted`
    pub(crate) recommended_tier: &'static str,
    pub(crate) title_max_chars: i32,
    pub(crate) tags_max: i32,
    pub(crate) description_max_chars: i32,
    pub(crate) requires_cover: bool,
    pub(crate) notes: &'static str,
}

/// 国内 5 + 海外 4；与 `requirements` 需求 12 矩阵一致。
pub(crate) const ALL: &[PlatformCapability] = &[
    PlatformCapability {
        platform_id: "douyin",
        label_zh: "抖音",
        region: MarketRegion::Domestic,
        recommended_tier: "semi_auto",
        title_max_chars: 80,
        tags_max: 15,
        description_max_chars: 800,
        requires_cover: true,
        notes: "竖屏优先；真实上传需平台 OAuth（F7 sandbox 外）",
    },
    PlatformCapability {
        platform_id: "bilibili",
        label_zh: "哔哩哔哩",
        region: MarketRegion::Domestic,
        recommended_tier: "semi_auto",
        title_max_chars: 80,
        tags_max: 12,
        description_max_chars: 800,
        requires_cover: true,
        notes: "分区与标签策略随 adapter 细化",
    },
    PlatformCapability {
        platform_id: "xiaohongshu",
        label_zh: "小红书",
        region: MarketRegion::Domestic,
        recommended_tier: "semi_auto",
        title_max_chars: 60,
        tags_max: 20,
        description_max_chars: 600,
        requires_cover: true,
        notes: "",
    },
    PlatformCapability {
        platform_id: "weixin_channels",
        label_zh: "视频号",
        region: MarketRegion::Domestic,
        recommended_tier: "semi_auto",
        title_max_chars: 60,
        tags_max: 10,
        description_max_chars: 600,
        requires_cover: true,
        notes: "",
    },
    PlatformCapability {
        platform_id: "kuaishou",
        label_zh: "快手",
        region: MarketRegion::Domestic,
        recommended_tier: "semi_auto",
        title_max_chars: 80,
        tags_max: 15,
        description_max_chars: 800,
        requires_cover: true,
        notes: "",
    },
    PlatformCapability {
        platform_id: "tiktok",
        label_zh: "TikTok",
        region: MarketRegion::Overseas,
        recommended_tier: "semi_auto",
        title_max_chars: 220,
        tags_max: 25,
        description_max_chars: 2200,
        requires_cover: false,
        notes: "",
    },
    PlatformCapability {
        platform_id: "youtube_shorts",
        label_zh: "YouTube Shorts",
        region: MarketRegion::Overseas,
        recommended_tier: "semi_auto",
        title_max_chars: 100,
        tags_max: 15,
        description_max_chars: 5000,
        requires_cover: false,
        notes: "",
    },
    PlatformCapability {
        platform_id: "instagram_reels",
        label_zh: "Instagram Reels",
        region: MarketRegion::Overseas,
        recommended_tier: "semi_auto",
        title_max_chars: 120,
        tags_max: 30,
        description_max_chars: 2200,
        requires_cover: false,
        notes: "",
    },
    PlatformCapability {
        platform_id: "facebook_reels",
        label_zh: "Facebook Reels",
        region: MarketRegion::Overseas,
        recommended_tier: "semi_auto",
        title_max_chars: 120,
        tags_max: 20,
        description_max_chars: 2000,
        requires_cover: false,
        notes: "",
    },
];

pub(crate) fn spec_for_platform(platform_id: &str) -> Option<&'static PlatformCapability> {
    ALL.iter().find(|p| p.platform_id == platform_id)
}

pub(crate) fn capability_matrix() -> Vec<PublishPlatformCapabilityRow> {
    ALL.iter()
        .map(|p| PublishPlatformCapabilityRow {
            platform_id: p.platform_id.to_string(),
            label_zh: p.label_zh.to_string(),
            market_region: p.region.as_api_str().to_string(),
            automation_mode: p.recommended_tier.to_string(),
            title_max_chars: p.title_max_chars,
            tags_max: p.tags_max,
            description_max_chars: p.description_max_chars,
            requires_cover: p.requires_cover,
            notes: p.notes.to_string(),
        })
        .collect()
}

/// Per-platform sandbox 回执（**F7/F8** 真对接前占位闭环).
pub(crate) fn sandbox_publish_receipt(job_id: Uuid, platform_id: &str) -> Value {
    json!({
        "adapter": "sandbox",
        "platform_id": platform_id,
        "external_video_id": format!("sandbox:{platform_id}:{job_id}"),
        "published_at": chrono::Utc::now().to_rfc3339(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_has_nine_distinct_platforms() {
        assert_eq!(ALL.len(), 9);
        let mut seen = std::collections::HashSet::new();
        for p in ALL {
            assert!(seen.insert(p.platform_id));
        }
        let domestic = ALL
            .iter()
            .filter(|p| p.region == MarketRegion::Domestic)
            .count();
        let overseas = ALL
            .iter()
            .filter(|p| p.region == MarketRegion::Overseas)
            .count();
        assert_eq!(domestic, 5);
        assert_eq!(overseas, 4);
    }
}
