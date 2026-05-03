//! Quality gate: pre-generation checks for storyboard panels, video prompts, and video generation.

pub(crate) mod anti_ai;
mod attribution;
mod enforce;
mod rules;

use serde::Serialize;
use serde_json::{json, Value};

pub(crate) use enforce::{enforce_quality_gate, run_quality_gate};

pub(crate) const HAIR_MARKERS: [&str; 10] = [
    "黑长发",
    "黑发",
    "金发",
    "银发",
    "白发",
    "短发",
    "长发",
    "卷发",
    "马尾",
    "寸头",
];
pub(crate) const COSTUME_MARKERS: [&str; 12] = [
    "风衣", "西装", "校服", "白裙", "红裙", "皮衣", "大衣", "衬衫", "外套", "盔甲", "制服", "婚纱",
];
pub(crate) const EMOTION_FLAT_WORDS: [&str; 6] = ["平静", "普通", "淡淡", "无波澜", "平稳", "平淡"];
pub(crate) const DIALOGUE_SILENT_MARKERS: [&str; 4] = ["无台词", "no dialogue", "silent", "旁白"];
pub(crate) const DIALOGUE_TARGET_CUES: [&str; 9] = [
    "对着",
    "冲着",
    "朝着",
    "看向",
    "盯着",
    "望向",
    "叫住",
    "喊住",
    "回头看",
];
pub(crate) const DIALOGUE_INTENT_CUES: [&str; 16] = [
    "低声", "压着", "强忍", "克制", "哽咽", "冷笑", "怒", "恨", "委屈", "试探", "逼问", "哀求",
    "示弱", "警告", "挑衅", "不甘",
];
pub(crate) const DIALOGUE_PAUSE_CUES: [&str; 10] = [
    "停顿",
    "顿了顿",
    "沉默",
    "吸气",
    "抿唇",
    "咬字",
    "迟疑",
    "欲言又止",
    "呼吸",
    "气口",
];
pub(crate) const DIALOGUE_PACE_CUES: [&str; 10] = [
    "语速",
    "尾音",
    "轻声",
    "急促",
    "缓慢",
    "一字一顿",
    "断句",
    "短促",
    "拖长",
    "发颤",
];
pub(crate) const HIGH_EMOTION_CUES: [&str; 16] = [
    "崩溃", "爆发", "怒", "哭", "含泪", "哽咽", "失控", "压迫", "绝望", "对峙", "质问", "撕扯",
    "强忍", "痛", "喊", "吼",
];
pub(crate) const EMOTION_PEAK_CUES: [&str; 16] = [
    "眼眶发红",
    "泪",
    "哽咽",
    "呼吸发颤",
    "喉结滚动",
    "嘴角发僵",
    "下颌绷紧",
    "抿唇",
    "强忍",
    "冷笑",
    "停顿",
    "怒视",
    "咬牙",
    "颤",
    "发抖",
    "吸气",
];
pub(crate) const GAZE_CONFLICT_PAIRS: [(&str, &str); 5] = [
    ("对视", "背对"),
    ("看向左侧", "看向右侧"),
    ("盯着对方", "闭眼"),
    ("正视", "视线游离"),
    ("目光相接", "移开视线"),
];
pub(crate) const LIMB_CONFLICT_PAIRS: [(&str, &str); 5] = [
    ("双手插兜", "捧脸"),
    ("双臂交叉", "拥抱"),
    ("跪地", "奔跑"),
    ("双手抱胸", "牵手"),
    ("一动不动", "猛扑"),
];
pub(crate) const PHYSICAL_RELATION_CONFLICT_PAIRS: [(&str, &str); 5] = [
    ("贴身", "相隔很远"),
    ("牵手", "完全不接触"),
    ("扶住", "隔着整张桌子"),
    ("面对面", "背对背"),
    ("拥抱", "各自站在房间两端"),
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum QualityGateStage {
    StoryboardPanel,
    VideoPrompt,
    VideoGenerate,
}

impl QualityGateStage {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::StoryboardPanel => "storyboard_panel",
            Self::VideoPrompt => "video_prompt",
            Self::VideoGenerate => "video_generate",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) enum QualityGateSeverity {
    Severe,
    Minor,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct QualityGateIssue {
    pub severity: QualityGateSeverity,
    pub issue_type: String,
    pub suggestion: String,
    pub scope: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct QualityGateDecision {
    pub blocked: bool,
    pub issues: Vec<QualityGateIssue>,
}

#[derive(Debug, sqlx::FromRow)]
pub(super) struct StoryboardDbRow {
    pub(super) numeric_id: i32,
    pub(super) prompt: Option<String>,
    pub(super) video_desc: Option<String>,
    pub(super) duration: Option<String>,
}

#[derive(Debug, Clone)]
pub(super) struct StoryboardQualityState {
    pub(super) storyboard_id: i32,
    pub(super) subject_key: String,
    pub(super) emotion_intensity: u8,
    pub(super) performance_signature: String,
    pub(super) action_signature: String,
}

pub(super) fn scope_signature(storyboard_ids: &[i32]) -> Value {
    json!({ "storyboardIds": storyboard_ids })
}

pub(super) fn scope_label(storyboard_ids: &[i32]) -> String {
    if storyboard_ids.is_empty() {
        "project".to_string()
    } else {
        format!(
            "storyboardIds={}",
            storyboard_ids
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join(",")
        )
    }
}

pub(super) fn issue(
    severity: QualityGateSeverity,
    issue_type: &str,
    suggestion: &str,
    scope: &str,
) -> QualityGateIssue {
    QualityGateIssue {
        severity,
        issue_type: issue_type.to_string(),
        suggestion: suggestion.to_string(),
        scope: scope.to_string(),
    }
}

pub(super) fn rework_suggestion(detail: &str) -> String {
    format!(
        "{detail} 优先对该分镜发起 storyboard_item 局部返工；若同对象已连续失败 2 次则进入归因模式。"
    )
}

pub(super) fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

pub(super) fn first_matching_marker<'a>(text: &str, markers: &'a [&str]) -> Option<&'a str> {
    markers.iter().copied().find(|marker| text.contains(marker))
}

#[cfg(test)]
mod tests {
    use super::{
        enforce::enforce_quality_gate,
        issue,
        rules::{
            dialogue_emotion_mismatch, emotion_intensity_score, evaluate_storyboard_progression,
            prompt_has_visual_conflict, storyboard_dialogue_is_empty,
        },
        scope_label, QualityGateDecision, QualityGateSeverity, QualityGateStage,
        StoryboardQualityState,
    };
    use crate::error::ApiError;
    use crate::production::workbench::video_prompt_memory::parse_structured_storyboard_description;
    use proptest::prelude::*;

    fn quality_gate_stage_strategy() -> impl Strategy<Value = QualityGateStage> {
        prop_oneof![
            Just(QualityGateStage::StoryboardPanel),
            Just(QualityGateStage::VideoPrompt),
            Just(QualityGateStage::VideoGenerate),
        ]
    }

    #[test]
    fn scope_label_compacts_storyboard_ids() {
        assert_eq!(scope_label(&[3, 9]), "storyboardIds=3,9");
    }

    #[test]
    fn visual_conflict_detector_flags_cold_warm_mix() {
        assert!(prompt_has_visual_conflict("冷光近景同时切成暖光远景"));
    }

    #[test]
    fn enforce_quality_gate_blocks_severe_decision() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![issue(
                QualityGateSeverity::Severe,
                "visual_conflict",
                "先统一镜头语言。",
                "storyboardId=12",
            )],
        };
        let err = enforce_quality_gate(QualityGateStage::VideoPrompt, &decision)
            .expect_err("should block");
        match err {
            ApiError::Conflict(message) => assert!(message.contains("video_prompt")),
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn dialogue_scene_requires_non_silent_marker() {
        assert!(storyboard_dialogue_is_empty("无台词"));
        assert!(storyboard_dialogue_is_empty("silent"));
        assert!(!storyboard_dialogue_is_empty("你终于来了"));
    }

    #[test]
    fn dialogue_emotion_mismatch_flags_flat_scene_with_intense_line() {
        let fields = parse_structured_storyboard_description(
            "（林晚、走廊、林晚、4秒、近景、固定、安静站着、平静克制、冷光、你敢再说一遍！、脚步声、A01）",
        )
        .expect("fields");
        assert!(dialogue_emotion_mismatch(&fields, Some("镜头保持平静")));
    }

    #[test]
    fn emotion_intensity_detects_high_emotion_words() {
        let fields = parse_structured_storyboard_description(
            "（林晚、雨夜街头、林晚、5秒、近景、推进、含泪怒视对方、情绪爆发、雨夜冷光、别碰我！、雨声、A02）",
        )
        .expect("fields");
        assert_eq!(emotion_intensity_score(&fields), 3);
    }

    #[test]
    fn progression_checker_blocks_three_flat_states() {
        let issues = evaluate_storyboard_progression(&[
            StoryboardQualityState {
                storyboard_id: 1,
                subject_key: "林晚".into(),
                emotion_intensity: 1,
                performance_signature: "低声".into(),
                action_signature: "站着".into(),
            },
            StoryboardQualityState {
                storyboard_id: 2,
                subject_key: "林晚".into(),
                emotion_intensity: 1,
                performance_signature: "低声".into(),
                action_signature: "站着".into(),
            },
            StoryboardQualityState {
                storyboard_id: 3,
                subject_key: "林晚".into(),
                emotion_intensity: 1,
                performance_signature: "低声".into(),
                action_signature: "站着".into(),
            },
        ]);
        assert!(issues
            .iter()
            .any(|issue| issue.issue_type == "emotion_progression_flat"));
        assert!(issues
            .iter()
            .any(|issue| issue.issue_type == "performance_state_repeat"));
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]

        // Feature: drama-platform-completion, Property 6: 高成本阶段预检阻断
        // 验证：需求 9.3
        #[test]
        fn prop_high_cost_stage_precheck_blocks_on_severe_issues(
            stage in quality_gate_stage_strategy(),
            severities in proptest::collection::vec(prop_oneof![
                Just(QualityGateSeverity::Severe),
                Just(QualityGateSeverity::Minor),
            ], 1..8usize),
            blocked_flag in any::<bool>(),
        ) {
            let has_severe = severities.iter().any(|severity| *severity == QualityGateSeverity::Severe);
            let issues = severities
                .iter()
                .enumerate()
                .map(|(index, severity)| {
                    issue(
                        *severity,
                        if *severity == QualityGateSeverity::Severe { "visual_conflict" } else { "emotion_flat" },
                        "测试建议",
                        &format!("storyboardId={}", index + 1),
                    )
                })
                .collect::<Vec<_>>();
            let decision = QualityGateDecision {
                blocked: blocked_flag && !has_severe,
                issues,
            };
            let result = enforce_quality_gate(stage, &decision);
            if has_severe || decision.blocked {
                prop_assert!(matches!(result, Err(ApiError::Conflict(_))));
            } else {
                prop_assert!(result.is_ok());
            }
        }
    }
}
