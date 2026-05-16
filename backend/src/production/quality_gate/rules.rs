//! Detection rules: structured field evaluation, progression checks, comment parsing.

use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, selected_memory_subject_aliases, StructuredStoryboardDescription,
};
use crate::settings::agent_memory::StyleBibleCharacterAnchor;

use super::{
    contains_any, first_matching_marker, issue, rework_suggestion, QualityGateIssue,
    QualityGateSeverity, StoryboardQualityState, COSTUME_MARKERS, DIALOGUE_INTENT_CUES,
    DIALOGUE_PACE_CUES, DIALOGUE_PAUSE_CUES, DIALOGUE_SILENT_MARKERS, DIALOGUE_TARGET_CUES,
    EMOTION_FLAT_WORDS, EMOTION_PEAK_CUES, GAZE_CONFLICT_PAIRS, HAIR_MARKERS, HIGH_EMOTION_CUES,
    LIMB_CONFLICT_PAIRS, PHYSICAL_RELATION_CONFLICT_PAIRS,
};

pub(super) fn prompt_has_monotone_delivery_risk(text: &str) -> bool {
    contains_any(
        text,
        &[
            "平静地说",
            "缓缓说道",
            "面无表情",
            "没有情绪",
            "语气平",
            "机械",
            "朗读感",
        ],
    )
}

pub(super) fn prompt_has_visual_conflict(text: &str) -> bool {
    (contains_any(text, &["冷光", "冷调", "冷色"]) && contains_any(text, &["暖光", "暖调", "暖色"]))
        || (text.contains("近景") && text.contains("远景"))
        || (text.contains("静止") && contains_any(text, &["狂奔", "猛冲", "高速跟拍"]))
}

pub(super) fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
    let normalized = normalize_prompt_text(dialogue).to_lowercase();
    normalized.is_empty()
        || DIALOGUE_SILENT_MARKERS
            .iter()
            .any(|marker| normalized == *marker || normalized.contains(marker))
}

pub(super) fn emotion_intensity_score(fields: &StructuredStoryboardDescription) -> u8 {
    let text = normalize_prompt_text(
        &[
            fields.mood.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ]
        .join(" "),
    );
    if contains_any(
        &text,
        &["崩溃", "失控", "怒吼", "痛哭", "爆发", "撕扯", "咆哮"],
    ) {
        3
    } else if contains_any(
        &text,
        &[
            "含泪", "强忍", "压着", "哽咽", "质问", "逼近", "对峙", "不甘", "压迫",
        ],
    ) {
        2
    } else if contains_any(&text, &["平静", "克制", "沉默", "淡淡", "冷静"]) {
        1
    } else {
        0
    }
}

pub(super) fn performance_signature(fields: &StructuredStoryboardDescription) -> String {
    let text = normalize_prompt_text(
        &[
            fields.mood.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ]
        .join(" "),
    );
    for cue in [
        "抿唇", "停顿", "低声", "哽咽", "冷笑", "怒视", "强忍", "含泪", "沉默", "逼近", "后退",
    ] {
        if text.contains(cue) {
            return cue.to_string();
        }
    }
    "neutral".to_string()
}

pub(super) fn compact_action_signature(action: &str) -> String {
    let action = normalize_prompt_text(action);
    for cue in [
        "抬眼", "低头", "转身", "逼近", "后退", "停住", "冲", "跑", "站着", "看着", "握紧", "抿唇",
    ] {
        if action.contains(cue) {
            return cue.to_string();
        }
    }
    action
}

pub(super) fn dialogue_performance_cue_count(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> usize {
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();
    let dialogue_bundle = [
        fields.dialogue.as_str(),
        fields.action.as_str(),
        fields.mood.as_str(),
        prompt.as_str(),
        fields.sound.as_str(),
    ]
    .join(" ");
    [
        contains_any(&dialogue_bundle, &DIALOGUE_TARGET_CUES),
        contains_any(&dialogue_bundle, &DIALOGUE_INTENT_CUES),
        contains_any(&dialogue_bundle, &DIALOGUE_PAUSE_CUES),
        contains_any(&dialogue_bundle, &DIALOGUE_PACE_CUES),
    ]
    .into_iter()
    .filter(|matched| *matched)
    .count()
}

pub(super) fn high_emotion_scene(fields: &StructuredStoryboardDescription) -> bool {
    contains_any(
        &[
            fields.mood.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ]
        .join(" "),
        &HIGH_EMOTION_CUES,
    )
}

pub(super) fn has_emotional_peak(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();
    contains_any(
        &[
            fields.mood.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
            prompt.as_str(),
        ]
        .join(" "),
        &EMOTION_PEAK_CUES,
    )
}

pub(super) fn prompt_has_conflict_pair(text: &str, pairs: &[(&str, &str)]) -> bool {
    pairs
        .iter()
        .any(|(left, right)| text.contains(left) && text.contains(right))
}

pub(super) fn prompt_has_repetitive_action_risk(text: &str) -> bool {
    contains_any(text, &["重复", "反复", "机械地", "一遍遍", "来回重复"])
}

pub(super) fn dialogue_emotion_mismatch(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if storyboard_dialogue_is_empty(&fields.dialogue) {
        return false;
    }
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();
    let dialogue = normalize_prompt_text(&fields.dialogue);
    let mood = normalize_prompt_text(&fields.mood);
    let action = normalize_prompt_text(&fields.action);
    let dialogue_is_intense = dialogue.contains('！')
        || contains_any(
            &dialogue,
            &["你敢", "闭嘴", "别碰我", "滚", "求你", "为什么"],
        );
    let scene_is_flat = contains_any(&mood, &EMOTION_FLAT_WORDS)
        && !contains_any(&action, &EMOTION_PEAK_CUES)
        && !contains_any(&prompt, &EMOTION_PEAK_CUES);
    dialogue_is_intense && scene_is_flat
}

fn anchor_matches_subject(anchor: &StyleBibleCharacterAnchor, aliases: &[String]) -> bool {
    let name = normalize_prompt_text(&anchor.name);
    !name.is_empty()
        && aliases.iter().any(|alias| {
            let alias = normalize_prompt_text(alias);
            alias == name || alias.contains(&name) || name.contains(&alias)
        })
}

fn find_anchor_for_subject<'a>(
    anchors: &'a [StyleBibleCharacterAnchor],
    aliases: &[String],
) -> Option<&'a StyleBibleCharacterAnchor> {
    anchors
        .iter()
        .find(|anchor| anchor_matches_subject(anchor, aliases))
}

fn appearance_anchor_fragments(anchor: &StyleBibleCharacterAnchor) -> Vec<String> {
    let mut fragments = Vec::new();
    for source in [&anchor.fixed_appearance, &anchor.emotion_expression] {
        for fragment in source.split(['，', ',', '、', '；', ';', '/', '|']) {
            let normalized = normalize_prompt_text(fragment);
            if normalized.chars().count() >= 2 && !fragments.contains(&normalized) {
                fragments.push(normalized);
            }
        }
    }
    for habit in &anchor.body_habits {
        let normalized = normalize_prompt_text(habit);
        if normalized.chars().count() >= 2 && !fragments.contains(&normalized) {
            fragments.push(normalized);
        }
    }
    fragments
}

fn appearance_anchor_similarity(
    anchor: &StyleBibleCharacterAnchor,
    scene_text: &str,
) -> Option<f32> {
    let fragments = appearance_anchor_fragments(anchor);
    if fragments.len() < 2 {
        return None;
    }

    let scene_mentions_identity_detail = first_matching_marker(scene_text, &HAIR_MARKERS).is_some()
        || first_matching_marker(scene_text, &COSTUME_MARKERS).is_some()
        || fragments
            .iter()
            .any(|fragment| scene_text.contains(fragment));
    if !scene_mentions_identity_detail {
        return None;
    }

    let matched = fragments
        .iter()
        .filter(|fragment| scene_text.contains(fragment.as_str()))
        .count();
    Some(matched as f32 / fragments.len() as f32)
}

fn appearance_drift_issue(
    anchor: &StyleBibleCharacterAnchor,
    scene_text: &str,
    scope: &str,
) -> Option<QualityGateIssue> {
    let appearance = normalize_prompt_text(&anchor.fixed_appearance);
    if appearance.is_empty() {
        return None;
    }
    let anchor_hair = first_matching_marker(&appearance, &HAIR_MARKERS);
    let scene_hair = first_matching_marker(scene_text, &HAIR_MARKERS);
    if let (Some(anchor_hair), Some(scene_hair)) = (anchor_hair, scene_hair) {
        if anchor_hair != scene_hair {
            return Some(issue(
                QualityGateSeverity::Severe,
                "face_identity_drift",
                &rework_suggestion("人物外貌锚点与当前镜头不一致，先统一发型/识别点。"),
                scope,
            ));
        }
    }
    let anchor_costume = first_matching_marker(&appearance, &COSTUME_MARKERS);
    let scene_costume = first_matching_marker(scene_text, &COSTUME_MARKERS);
    if let (Some(anchor_costume), Some(scene_costume)) = (anchor_costume, scene_costume) {
        if anchor_costume != scene_costume {
            return Some(issue(
                QualityGateSeverity::Severe,
                "costume_drift",
                &rework_suggestion("人物衣着锚点发生突变，先统一服装与镜头连续性。"),
                scope,
            ));
        }
    }
    if let Some(similarity) = appearance_anchor_similarity(anchor, scene_text) {
        if similarity < 0.7 {
            return Some(issue(
                QualityGateSeverity::Minor,
                "character_anchor_drift",
                &format!(
                    "人物锚点与当前镜头描述相似度仅 {:.0}%，建议补齐角色外观/表演锚点后再生成。",
                    similarity * 100.0
                ),
                scope,
            ));
        }
    }
    None
}

pub(super) fn evaluate_structured_fields(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
    scope: &str,
    anchors: &[StyleBibleCharacterAnchor],
    issues: &mut Vec<QualityGateIssue>,
) -> Option<StoryboardQualityState> {
    if fields.subject.trim().is_empty() {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "character_missing",
            "先补充主镜头人物主体和身份锚点，再继续进入高成本阶段。",
            scope,
        ));
        return None;
    }
    if fields.mood.trim().is_empty() || contains_any(&fields.mood, &EMOTION_FLAT_WORDS) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "emotion_flat",
            "为当前镜头补一个明确情绪目标和表情/呼吸细节，避免人物全程同一状态。",
            scope,
        ));
    }
    if fields.camera_move.trim().is_empty()
        && !contains_any(
            &fields.action,
            &["转身", "停住", "逼近", "后退", "抬眼", "冲", "跑", "贴近"],
        )
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "pacing_flat",
            "补充镜头调度或动作变化，避免分镜节奏过平。",
            scope,
        ));
    }
    if prompt_has_visual_conflict(
        &[
            fields.shot.as_str(),
            fields.camera_move.as_str(),
            fields.lighting.as_str(),
        ]
        .join(" "),
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "visual_conflict",
            "先统一镜头景别、灯光和运动方向，避免视觉指令互相冲突。",
            scope,
        ));
    }
    let aliases = selected_memory_subject_aliases(&fields.subject, &fields.subject_refs);
    let anchor = find_anchor_for_subject(anchors, &aliases);
    if anchor.is_none() && !anchors.is_empty() {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "character_anchor_missing",
            "当前镜头主体还没命中可用人物锚点，建议补角色别名或固定外观描述，避免后续串脸。",
            scope,
        ));
    }
    if let Some(anchor) = anchor {
        let appearance_text = normalize_prompt_text(
            &[
                fields.subject.as_str(),
                fields.action.as_str(),
                fields.setting.as_str(),
                prompt.unwrap_or_default(),
            ]
            .join(" "),
        );
        if let Some(appearance_issue) = appearance_drift_issue(anchor, &appearance_text, scope) {
            issues.push(appearance_issue);
        }
    }
    let dialogue_has_cues = dialogue_performance_cue_count(fields, prompt);
    if !storyboard_dialogue_is_empty(&fields.dialogue) && dialogue_has_cues < 2 {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "monotone_dialogue_risk",
            &rework_suggestion(
                "含台词镜头缺少说话对象、情绪意图、停顿或语速线索，表演容易像读文章。",
            ),
            scope,
        ));
    }
    if dialogue_emotion_mismatch(fields, prompt) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "dialogue_emotion_mismatch",
            &rework_suggestion("台词情绪与镜头表演状态不匹配，先补情绪目标和微表演。"),
            scope,
        ));
    }
    if high_emotion_scene(fields) && !has_emotional_peak(fields, prompt) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "emotion_peak_missing",
            "高情绪镜头缺少可感知峰值，建议补充停顿、眼神、呼吸或肢体爆发点。",
            scope,
        ));
    }
    let scene_text = normalize_prompt_text(
        &[
            fields.subject.as_str(),
            fields.setting.as_str(),
            fields.shot.as_str(),
            fields.camera_move.as_str(),
            fields.action.as_str(),
            fields.mood.as_str(),
            fields.dialogue.as_str(),
            prompt.unwrap_or_default(),
        ]
        .join(" "),
    );
    if prompt_has_conflict_pair(&scene_text, &GAZE_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "gaze_direction_error",
            &rework_suggestion("人物视线方向互相打架，先统一对视/背对/视线落点。"),
            scope,
        ));
    }
    if prompt_has_conflict_pair(&scene_text, &LIMB_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "limb_incoherence",
            &rework_suggestion("人物肢体动作组合不连贯，先修正手脚和姿态逻辑。"),
            scope,
        ));
    }
    if prompt_has_conflict_pair(&scene_text, &PHYSICAL_RELATION_CONFLICT_PAIRS) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "physical_relation_error",
            &rework_suggestion("人物空间关系和接触关系冲突，先修正站位与距离。"),
            scope,
        ));
    }
    if prompt_has_repetitive_action_risk(&scene_text) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "repetitive_action",
            "动作描述出现明显重复，建议换成有递进的动作或镜头调度。",
            scope,
        ));
    }
    Some(StoryboardQualityState {
        storyboard_id: scope
            .strip_prefix("storyboardId=")
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or_default(),
        subject_key: aliases
            .first()
            .cloned()
            .unwrap_or_else(|| normalize_prompt_text(&fields.subject)),
        emotion_intensity: emotion_intensity_score(fields),
        performance_signature: performance_signature(fields),
        action_signature: compact_action_signature(&fields.action),
    })
}

pub(super) fn evaluate_storyboard_progression(
    states: &[StoryboardQualityState],
) -> Vec<QualityGateIssue> {
    let mut issues = Vec::new();
    for window in states.windows(3) {
        if window
            .iter()
            .map(|s| s.subject_key.as_str())
            .all(|s| s == window[0].subject_key)
            && window
                .iter()
                .map(|s| s.emotion_intensity)
                .all(|e| e == window[0].emotion_intensity)
        {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "emotion_progression_flat",
                &rework_suggestion("同一角色连续 3 条分镜情绪强度没有起伏，先拉开递进或回落。"),
                &format!(
                    "storyboardIds={},{},{}",
                    window[0].storyboard_id, window[1].storyboard_id, window[2].storyboard_id
                ),
            ));
        }
        if window
            .iter()
            .map(|s| s.subject_key.as_str())
            .all(|s| s == window[0].subject_key)
            && window
                .iter()
                .map(|s| s.performance_signature.as_str())
                .all(|sig| sig == window[0].performance_signature)
        {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "performance_state_repeat",
                &rework_suggestion("同一角色连续 3 条分镜维持同一姿态/表演状态，先打破机械重复。"),
                &format!(
                    "storyboardIds={},{},{}",
                    window[0].storyboard_id, window[1].storyboard_id, window[2].storyboard_id
                ),
            ));
        }
        if window
            .iter()
            .map(|s| s.action_signature.as_str())
            .all(|sig| !sig.is_empty() && sig == window[0].action_signature)
        {
            issues.push(issue(
                QualityGateSeverity::Minor,
                "repetitive_action",
                "连续 3 条分镜动作签名过于一致，建议调整动作节奏或镜头切换方式。",
                &format!(
                    "storyboardIds={},{},{}",
                    window[0].storyboard_id, window[1].storyboard_id, window[2].storyboard_id
                ),
            ));
        }
    }
    issues
}

pub(super) fn quality_review_comment_issues(comment: &str, scope: &str) -> Vec<QualityGateIssue> {
    let mut issues = Vec::new();
    if contains_any(comment, &["跳轴", "视线错误", "站位错", "连续性错误"]) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "gaze_direction_error",
            &rework_suggestion("先修复人物站位、视线或镜头方向连续性，再继续高成本生成。"),
            scope,
        ));
    }
    if contains_any(
        comment,
        &[
            "串脸",
            "脸崩",
            "长相漂移",
            "五官不一致",
            "face drift",
            "identity drift",
        ],
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "face_identity_drift",
            &rework_suggestion("角色脸部识别点不稳定，先回到人物锚点修正外貌一致性。"),
            scope,
        ));
    }
    if contains_any(
        comment,
        &["服装不一致", "换装突兀", "衣着突然变化", "costume drift"],
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "costume_drift",
            &rework_suggestion("服装连续性出错，先统一衣着锚点再继续生成。"),
            scope,
        ));
    }
    if contains_any(
        comment,
        &["手崩", "四肢不连贯", "肢体错误", "手脚奇怪", "limb"],
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "limb_incoherence",
            &rework_suggestion("人物肢体表现穿帮，先修正关键姿态和手部动作。"),
            scope,
        ));
    }
    if contains_any(
        comment,
        &["空间关系错", "距离不对", "位置关系错", "物理关系错误"],
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "physical_relation_error",
            &rework_suggestion("场景中的人物/物体物理关系不成立，先修正站位和接触关系。"),
            scope,
        ));
    }
    if contains_any(comment, &["重复动作", "动作机械", "来回同一个动作"]) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "repetitive_action",
            "先给角色补一个新的动作转折或镜头变化，避免机械重复。",
            scope,
        ));
    }
    if contains_any(
        comment,
        &["情绪平", "没情绪", "生硬", "朗读", "台词假", "情绪不对"],
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "dialogue_emotion_mismatch",
            &rework_suggestion("先补充表情、呼吸、语气或节奏变化，提升人物真实感。"),
            scope,
        ));
    }
    issues
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::production::workbench::video_prompt_memory::parse_structured_storyboard_description;

    fn sample_anchor() -> StyleBibleCharacterAnchor {
        StyleBibleCharacterAnchor {
            name: "林晚".into(),
            fixed_appearance: "黑长发，米白风衣".into(),
            default_temperament: "克制隐忍".into(),
            emotion_expression: "先抿唇再低声开口".into(),
            relationship_positioning: String::new(),
            body_habits: vec!["抿唇".into(), "指尖收紧".into()],
        }
    }

    #[test]
    fn appearance_similarity_warns_when_anchor_match_drops_below_threshold() {
        let anchor = sample_anchor();
        let issue = appearance_drift_issue(
            &anchor,
            &normalize_prompt_text("林晚黑长发，米白风衣，沉默站着"),
            "storyboardId=7",
        )
        .expect("issue");
        assert_eq!(issue.issue_type, "character_anchor_drift");
        assert_eq!(issue.severity, QualityGateSeverity::Minor);
    }

    #[test]
    fn evaluate_storyboard_progression_flags_flat_emotion_three_in_a_row() {
        let make_state = |storyboard_id| StoryboardQualityState {
            storyboard_id,
            subject_key: "林晚".into(),
            emotion_intensity: 2,
            performance_signature: "强忍".into(),
            action_signature: "看着".into(),
        };
        let issues =
            evaluate_storyboard_progression(&[make_state(1), make_state(2), make_state(3)]);
        assert!(issues
            .iter()
            .any(|issue| issue.issue_type == "emotion_progression_flat"));
    }

    #[test]
    fn evaluate_structured_fields_keeps_gaze_conflict_severe() {
        let fields = parse_structured_storyboard_description(
            "（林晚、走廊、林晚、4秒、近景、固定、对视着陈默、平静、冷光、你敢再说一遍！、脚步声、A01）",
        )
        .unwrap();
        let mut issues = Vec::new();
        let _ = evaluate_structured_fields(
            &fields,
            Some("林晚背对陈默站着"),
            "storyboardId=1",
            &[sample_anchor()],
            &mut issues,
        );
        assert!(issues
            .iter()
            .any(|issue| issue.issue_type == "gaze_direction_error"
                && issue.severity == QualityGateSeverity::Severe));
    }
}
