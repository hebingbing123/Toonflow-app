// Allow dead code for functions used by negative_prompt_builder.rs
#![allow(dead_code)]

use super::fragment_parsing::canonical_negative_fragment;
use super::negative_prompt_analysis::storyboard_dialogue_is_empty;
use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, StructuredStoryboardDescription,
};

// Allow dead code for functions used by negative_prompt_builder.rs
#[allow(dead_code)]
fn negative_prompt_scene_has_motion_risk(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍", "推进", "拉远", "摇镜", "手持", "奔跑", "跑", "冲", "扑", "追", "快步",
                "转身", "踉跄", "急退", "handheld", "push in", "whip",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_lighting_risk(fields: &StructuredStoryboardDescription) -> bool {
    negative_prompt_scene_has_backlight_silhouette_risk(fields)
        || negative_prompt_scene_has_flat_cold_lighting_risk(fields)
        || negative_prompt_scene_has_neon_reflection_risk(fields)
}

fn negative_prompt_scene_has_neon_reflection_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "reflection",
                "wet street",
                "headlight reflection",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_backlight_silhouette_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && ["逆光", "背光", "剪影", "车灯", "silhouette", "backlight"]
                .iter()
                .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_flat_cold_lighting_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "冷光",
                "冷调",
                "阴天",
                "曝光",
                "flat lighting",
                "cold lighting",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_framing_risk(fields: &StructuredStoryboardDescription) -> bool {
    negative_prompt_scene_has_extreme_angle_risk(fields)
        || negative_prompt_scene_has_tight_close_up_risk(fields)
        || negative_prompt_scene_has_shot_change_risk(fields)
}

fn negative_prompt_scene_has_shot_change_risk(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍",
                "推进",
                "拉远",
                "摇镜",
                "甩镜",
                "切换",
                "转场",
                "追",
                "跑",
                "冲",
                "手持",
                "follow",
                "push in",
                "pull back",
                "whip",
                "pan",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_has_extreme_angle_risk(fields: &StructuredStoryboardDescription) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "仰拍",
                    "俯拍",
                    "倾斜",
                    "low angle",
                    "high angle",
                    "dutch angle",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_has_tight_close_up_risk(fields: &StructuredStoryboardDescription) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && ["近景", "特写", "close-up", "tight close-up"]
                    .iter()
                    .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_needs_emotional_memory(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "哭",
                "泪",
                "哽咽",
                "颤",
                "停顿",
                "压抑",
                "克制",
                "愤怒",
                "惊慌",
                "紧张",
                "压迫",
                "冷峻",
                "崩溃",
                "隐忍",
                "欲言又止",
                "迟疑",
                "回头",
                "犹豫",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_prompt_scene_needs_expressive_performance_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    if !negative_prompt_scene_needs_emotional_memory(fields) {
        return false;
    }

    if !storyboard_dialogue_is_empty(&fields.dialogue) {
        return true;
    }

    [fields.mood.as_str(), fields.action.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "欲言又止",
                    "隐忍",
                    "哽咽",
                    "低声",
                    "轻声",
                    "迟疑",
                    "停顿",
                    "犹豫",
                    "强忍",
                    "颤",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

fn negative_prompt_scene_prefers_restrained_emotional_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let restrained = [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "克制",
                "隐忍",
                "欲言又止",
                "迟疑",
                "犹豫",
                "哽咽",
                "停顿",
                "低声",
                "轻声",
                "压低声音",
                "忍住",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    let intended_cold_or_oppressive = [fields.mood.as_str(), fields.lighting.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && ["压迫", "紧张", "冷峻", "冷调", "冷色", "冷光"]
                    .iter()
                    .any(|keyword| value.contains(keyword))
        });
    restrained
        && !intended_cold_or_oppressive
        && !negative_prompt_scene_intends_frantic_mood(fields)
}

fn negative_prompt_scene_intends_frantic_mood(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "惊慌",
                "崩溃",
                "失控",
                "慌乱",
                "怒吼",
                "狂奔",
                "冲出",
                "扑过去",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn negative_fragment_requires_strict_continuity_budget(fragment: &str) -> bool {
    let canonical = canonical_negative_fragment(fragment);
    canonical.contains("face")
        || canonical.contains("identity")
        || canonical.contains("costume")
        || canonical.contains("warped")
        || canonical.contains("anatom")
        || canonical.contains("lip-sync")
        || canonical.contains("shot changes")
        || canonical.contains("wrong framing")
}
