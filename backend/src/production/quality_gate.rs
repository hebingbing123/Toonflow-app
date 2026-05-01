use serde::Serialize;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::settings::agent_memory::{
    load_project_style_bible_character_anchors, replace_named_summary_memory_with_scope,
    StyleBibleCharacterAnchor,
};

use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, parse_structured_storyboard_description,
    selected_memory_subject_aliases, StoryboardPromptSeedRow, StructuredStoryboardDescription,
};

const HAIR_MARKERS: [&str; 10] = [
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
const COSTUME_MARKERS: [&str; 12] = [
    "风衣", "西装", "校服", "白裙", "红裙", "皮衣", "大衣", "衬衫", "外套", "盔甲", "制服", "婚纱",
];
const EMOTION_FLAT_WORDS: [&str; 6] = ["平静", "普通", "淡淡", "无波澜", "平稳", "平淡"];
const DIALOGUE_SILENT_MARKERS: [&str; 4] = ["无台词", "no dialogue", "silent", "旁白"];
const DIALOGUE_TARGET_CUES: [&str; 9] = [
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
const DIALOGUE_INTENT_CUES: [&str; 16] = [
    "低声", "压着", "强忍", "克制", "哽咽", "冷笑", "怒", "恨", "委屈", "试探", "逼问", "哀求",
    "示弱", "警告", "挑衅", "不甘",
];
const DIALOGUE_PAUSE_CUES: [&str; 10] = [
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
const DIALOGUE_PACE_CUES: [&str; 10] = [
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
const HIGH_EMOTION_CUES: [&str; 16] = [
    "崩溃", "爆发", "怒", "哭", "含泪", "哽咽", "失控", "压迫", "绝望", "对峙", "质问", "撕扯",
    "强忍", "痛", "喊", "吼",
];
const EMOTION_PEAK_CUES: [&str; 16] = [
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
const GAZE_CONFLICT_PAIRS: [(&str, &str); 5] = [
    ("对视", "背对"),
    ("看向左侧", "看向右侧"),
    ("盯着对方", "闭眼"),
    ("正视", "视线游离"),
    ("目光相接", "移开视线"),
];
const LIMB_CONFLICT_PAIRS: [(&str, &str); 5] = [
    ("双手插兜", "捧脸"),
    ("双臂交叉", "拥抱"),
    ("跪地", "奔跑"),
    ("双手抱胸", "牵手"),
    ("一动不动", "猛扑"),
];
const PHYSICAL_RELATION_CONFLICT_PAIRS: [(&str, &str); 5] = [
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
struct StoryboardDbRow {
    numeric_id: i32,
    prompt: Option<String>,
    video_desc: Option<String>,
    duration: Option<String>,
}

#[derive(Debug, Clone)]
struct StoryboardQualityState {
    storyboard_id: i32,
    subject_key: String,
    emotion_intensity: u8,
    performance_signature: String,
    action_signature: String,
}

fn scope_signature(storyboard_ids: &[i32]) -> Value {
    json!({ "storyboardIds": storyboard_ids })
}

fn scope_label(storyboard_ids: &[i32]) -> String {
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

fn issue(
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

fn rework_suggestion(detail: &str) -> String {
    format!(
        "{detail} 优先对该分镜发起 storyboard_item 局部返工；若同对象已连续失败 2 次则进入归因模式。"
    )
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

fn first_matching_marker<'a>(text: &str, markers: &'a [&str]) -> Option<&'a str> {
    markers.iter().copied().find(|marker| text.contains(marker))
}

fn prompt_has_monotone_delivery_risk(text: &str) -> bool {
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

fn prompt_has_visual_conflict(text: &str) -> bool {
    (contains_any(text, &["冷光", "冷调", "冷色"]) && contains_any(text, &["暖光", "暖调", "暖色"]))
        || (text.contains("近景") && text.contains("远景"))
        || (text.contains("静止") && contains_any(text, &["狂奔", "猛冲", "高速跟拍"]))
}

fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
    let normalized = normalize_prompt_text(dialogue).to_lowercase();
    normalized.is_empty()
        || DIALOGUE_SILENT_MARKERS
            .iter()
            .any(|marker| normalized == *marker || normalized.contains(marker))
}

fn emotion_intensity_score(fields: &StructuredStoryboardDescription) -> u8 {
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

fn performance_signature(fields: &StructuredStoryboardDescription) -> String {
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

fn compact_action_signature(action: &str) -> String {
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

fn dialogue_performance_cue_count(
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

fn high_emotion_scene(fields: &StructuredStoryboardDescription) -> bool {
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

fn has_emotional_peak(fields: &StructuredStoryboardDescription, prompt: Option<&str>) -> bool {
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

fn prompt_has_conflict_pair(text: &str, pairs: &[(&str, &str)]) -> bool {
    pairs
        .iter()
        .any(|(left, right)| text.contains(left) && text.contains(right))
}

fn prompt_has_repetitive_action_risk(text: &str) -> bool {
    contains_any(text, &["重复", "反复", "机械地", "一遍遍", "来回重复"])
}

fn dialogue_emotion_mismatch(
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

    None
}

fn evaluate_structured_fields(
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

fn evaluate_storyboard_progression(states: &[StoryboardQualityState]) -> Vec<QualityGateIssue> {
    let mut issues = Vec::new();
    for window in states.windows(3) {
        if window
            .iter()
            .map(|state| state.subject_key.as_str())
            .all(|subject| subject == window[0].subject_key)
            && window
                .iter()
                .map(|state| state.emotion_intensity)
                .all(|score| score == window[0].emotion_intensity)
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
            .map(|state| state.subject_key.as_str())
            .all(|subject| subject == window[0].subject_key)
            && window
                .iter()
                .map(|state| state.performance_signature.as_str())
                .all(|signature| signature == window[0].performance_signature)
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
            .map(|state| state.action_signature.as_str())
            .all(|signature| !signature.is_empty() && signature == window[0].action_signature)
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

fn quality_review_comment_issues(comment: &str, scope: &str) -> Vec<QualityGateIssue> {
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

async fn load_storyboard_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<Vec<(i32, StoryboardPromptSeedRow)>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(Vec::new());
    }
    let rows = sqlx::query_as::<_, StoryboardDbRow>(
        r#"
        SELECT sb.numeric_id, sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
        ORDER BY sb.numeric_id ASC
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows
        .into_iter()
        .map(|row| {
            (
                row.numeric_id,
                StoryboardPromptSeedRow {
                    prompt: row.prompt,
                    video_desc: row.video_desc,
                    duration: row.duration,
                },
            )
        })
        .collect())
}

async fn has_role_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<bool, ApiError> {
    sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        INNER JOIN app_script sc ON sc.id = sa.script_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND a.asset_type = 'role'
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_one(pool)
    .await
    .map(|count| count > 0)
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn load_recent_quality_comments(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
) -> Result<Vec<String>, ApiError> {
    let upstream_stage = match stage {
        QualityGateStage::StoryboardPanel => "storyboard_table",
        QualityGateStage::VideoPrompt => "storyboard_panel",
        QualityGateStage::VideoGenerate => "video_prompt",
    };
    let target_ids = storyboard_ids
        .iter()
        .map(i32::to_string)
        .collect::<Vec<_>>();
    sqlx::query_scalar(
        r#"
        SELECT comments
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND script_id = $3
          AND stage = $4
          AND comments IS NOT NULL
          AND (
            COALESCE(array_length($5::text[], 1), 0) = 0
            OR target_id = ANY($5)
          )
        ORDER BY created_at DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(upstream_stage)
    .bind(&target_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

fn decision_prefers_patch_scope(decision: &QualityGateDecision) -> &'static str {
    if decision
        .issues
        .iter()
        .any(|issue| issue.issue_type == "character_missing")
    {
        "scene"
    } else {
        "storyboard_item"
    }
}

fn decision_suggests_attribution(decision: &QualityGateDecision) -> bool {
    decision.issues.iter().any(|issue| {
        issue.severity == QualityGateSeverity::Severe
            && matches!(
                issue.issue_type.as_str(),
                "face_identity_drift"
                    | "costume_drift"
                    | "gaze_direction_error"
                    | "limb_incoherence"
                    | "physical_relation_error"
                    | "dialogue_emotion_mismatch"
                    | "emotion_progression_flat"
                    | "performance_state_repeat"
            )
    })
}

async fn persist_precheck_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
    decision: &QualityGateDecision,
) -> Result<(), ApiError> {
    if decision.issues.is_empty() {
        return Ok(());
    }
    let name = format!(
        "quality_precheck:{}:{}",
        stage.as_str(),
        if storyboard_ids.is_empty() {
            "project".to_string()
        } else {
            storyboard_ids
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join("_")
        }
    );
    let content = serde_json::to_string(&json!({
        "stage": stage.as_str(),
        "blocked": decision.blocked,
        "savedHighCostCallCount": if decision.blocked { 1 } else { 0 },
        "preferredPatchScope": decision_prefers_patch_scope(decision),
        "attributionModeSuggested": decision_suggests_attribution(decision),
        "issues": decision.issues,
    }))
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    let signature = scope_signature(storyboard_ids);
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        Some(script_id),
        "productionAgent",
        "assistant",
        &name,
        &content,
        "delta_memory",
        Some(&signature),
        None,
    )
    .await
}

fn decision_message(stage: QualityGateStage, decision: &QualityGateDecision) -> String {
    let suggestion = decision
        .issues
        .iter()
        .find(|issue| issue.severity == QualityGateSeverity::Severe)
        .or_else(|| decision.issues.first())
        .map(|issue| issue.suggestion.as_str())
        .unwrap_or("请先最小修复上游质量问题。");
    format!(
        "quality precheck blocked {}: {}",
        stage.as_str(),
        suggestion
    )
}

pub(crate) async fn run_quality_gate(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
    text_inputs: &[String],
) -> Result<QualityGateDecision, ApiError> {
    let storyboard_rows =
        load_storyboard_rows(pool, user_id, project_id, script_id, storyboard_ids).await?;
    let has_role_rows = has_role_rows(pool, user_id, project_id, script_id).await?;
    let character_anchors =
        load_project_style_bible_character_anchors(pool, user_id, project_id).await?;
    let quality_comments =
        load_recent_quality_comments(pool, user_id, project_id, script_id, stage, storyboard_ids)
            .await?;

    let mut issues = Vec::new();
    let mut storyboard_states = Vec::new();
    let scope = scope_label(storyboard_ids);

    if !has_role_rows && character_anchors.is_empty() && storyboard_rows.is_empty() {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "character_missing",
            "项目还缺少可用角色锚点，先补角色资产或人物主体信息。",
            &scope,
        ));
    }

    for row in &storyboard_rows {
        if let Some(fields) = row
            .1
            .video_desc
            .as_deref()
            .and_then(parse_structured_storyboard_description)
        {
            let row_scope = format!("storyboardId={}", row.0);
            if let Some(state) = evaluate_structured_fields(
                &fields,
                row.1.prompt.as_deref(),
                &row_scope,
                &character_anchors,
                &mut issues,
            ) {
                storyboard_states.push(state);
            }
        }
    }
    issues.extend(evaluate_storyboard_progression(&storyboard_states));

    for input in text_inputs {
        let normalized = normalize_prompt_text(input);
        if normalized.is_empty() {
            continue;
        }
        if prompt_has_visual_conflict(&normalized) {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "visual_conflict",
                "先删掉互相冲突的镜头/灯光/动作指令，再继续生成。",
                &scope,
            ));
        }
        if prompt_has_monotone_delivery_risk(&normalized) {
            issues.push(issue(
                QualityGateSeverity::Minor,
                "monotone_dialogue_risk",
                "把台词表达改成带情绪和动作细节的表演指令，避免像朗读。",
                &scope,
            ));
        }
        if contains_any(&normalized, &["平稳推进", "轻轻看着前方", "安静站着"]) {
            issues.push(issue(
                QualityGateSeverity::Minor,
                "pacing_flat",
                "增加节奏变化或动作转折，别让整段镜头过于平铺。",
                &scope,
            ));
        }
        if prompt_has_conflict_pair(&normalized, &GAZE_CONFLICT_PAIRS) {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "gaze_direction_error",
                &rework_suggestion("文本里已经出现明显视线冲突，先修正人物目光方向。"),
                &scope,
            ));
        }
    }

    for comment in quality_comments {
        issues.extend(quality_review_comment_issues(&comment, &scope));
    }

    issues.sort_by(|left, right| {
        let left_score = matches!(left.severity, QualityGateSeverity::Severe) as i32;
        let right_score = matches!(right.severity, QualityGateSeverity::Severe) as i32;
        right_score
            .cmp(&left_score)
            .then(left.issue_type.cmp(&right.issue_type))
            .then(left.scope.cmp(&right.scope))
    });
    issues.dedup_by(|left, right| {
        left.severity == right.severity
            && left.issue_type == right.issue_type
            && left.scope == right.scope
    });

    let decision = QualityGateDecision {
        blocked: issues
            .iter()
            .any(|issue| issue.severity == QualityGateSeverity::Severe),
        issues,
    };
    if !decision.issues.is_empty() {
        persist_precheck_memory(
            pool,
            user_id,
            project_id,
            script_id,
            stage,
            storyboard_ids,
            &decision,
        )
        .await?;
    }
    Ok(decision)
}

pub(crate) fn enforce_quality_gate(
    stage: QualityGateStage,
    decision: &QualityGateDecision,
) -> Result<(), ApiError> {
    if decision.blocked {
        return Err(ApiError::Conflict(decision_message(stage, decision)));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        dialogue_emotion_mismatch, emotion_intensity_score, enforce_quality_gate,
        evaluate_storyboard_progression, issue, parse_structured_storyboard_description,
        prompt_has_visual_conflict, scope_label, storyboard_dialogue_is_empty, QualityGateDecision,
        QualityGateSeverity, QualityGateStage, StoryboardQualityState,
    };
    use crate::error::ApiError;

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
}
