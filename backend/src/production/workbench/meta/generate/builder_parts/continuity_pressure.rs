use super::super::*;

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_axis_risk(
    note: &str,
) -> bool {
    ["跳轴", "视线", "方向", "构图"]
        .iter()
        .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_blocking_risk(
    note: &str,
) -> bool {
    ["站位", "走位", "位置", "前后景"]
        .iter()
        .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_dialogue_risk(
    note: &str,
) -> bool {
    [
        "对白", "台词", "口型", "语气", "旁白", "voice", "dialogue", "lip-sync",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_emotional_risk(
    note: &str,
) -> bool {
    [
        "情绪", "压迫", "冷峻", "悲怆", "克制", "隐忍", "急迫", "停顿", "哽咽", "表演", "状态",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_lighting_risk(
    note: &str,
) -> bool {
    [
        "光", "影", "逆光", "反光", "曝光", "闪烁", "霓虹", "玻璃", "雨", "灯",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_mentions_motion_risk(
    note: &str,
) -> bool {
    [
        "跟拍", "推进", "拉远", "手持", "运镜", "抖动", "动作", "节奏", "转身", "快步",
    ]
    .iter()
    .any(|keyword| note.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn continuity_fragment_matches_constraint_pressure(
    fragment: &str,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> bool {
    continuity_note_pressure_score(fragment, constraint_pressure) > 0
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_pressure_score(
    note: &str,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let Some(pressure) = constraint_pressure else {
        return 0;
    };
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return 0;
    }

    let mentions_axis = continuity_note_mentions_axis_risk(&normalized);
    let mentions_blocking = continuity_note_mentions_blocking_risk(&normalized);
    let mentions_dialogue = continuity_note_mentions_dialogue_risk(&normalized);
    let mentions_emotion = continuity_note_mentions_emotional_risk(&normalized);
    let mentions_lighting = continuity_note_mentions_lighting_risk(&normalized);
    let mentions_motion = continuity_note_mentions_motion_risk(&normalized);

    let mut score = 0;
    if pressure.has_dialogue_guardrail {
        if mentions_dialogue {
            score += 24;
        }
        if mentions_axis {
            score += 18;
        }
    }
    if pressure.has_identity_guardrail {
        if mentions_axis || mentions_blocking {
            score += 18;
        }
        if mentions_lighting {
            score += 12;
        }
    }
    if pressure.has_blocking_guardrail {
        if mentions_blocking {
            score += 22;
        }
        if mentions_motion {
            score += 12;
        }
    }
    if pressure.has_motion_guardrail {
        if mentions_motion {
            score += 20;
        }
        if mentions_blocking {
            score += 10;
        }
    }
    if pressure.has_lighting_guardrail && mentions_lighting {
        score += 20;
    }
    if pressure.has_emotion_guardrail {
        if mentions_emotion {
            score += 18;
        }
        if mentions_dialogue {
            score += 8;
        }
    }

    score
}
