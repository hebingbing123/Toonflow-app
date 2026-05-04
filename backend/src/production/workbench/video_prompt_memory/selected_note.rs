use super::*;

pub(super) fn selected_video_memory_note(row: &StoryboardPromptSeedRow) -> Option<String> {
    if let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
        let visible_speech_risk =
            selected_memory_has_visible_speech_performance_risk(&fields, row.prompt.as_deref());
        let mut narrative_fragments = Vec::new();
        let mut style_fragments = Vec::new();
        let subject = compact_selected_memory_subject(&fields.subject, &fields.action);
        let setting = compact_selected_memory_setting(
            &fields.setting,
            subject.as_deref(),
            Some(fields.subject_refs.as_str()),
            Some(fields.action.as_str()),
        );
        let action = compact_selected_memory_action(
            &fields.action,
            subject.as_deref(),
            Some(fields.subject.as_str()),
            Some(fields.subject_refs.as_str()),
            Some(fields.setting.as_str()),
            &fields.mood,
        );

        match merge_selected_memory_subject_action(subject.as_deref(), action.as_deref()) {
            Some(merged) => narrative_fragments.push(clip_prompt_fragment(&merged, 20)),
            None => {
                if let Some(subject) = subject.as_ref() {
                    narrative_fragments.push(clip_prompt_fragment(subject, 20));
                }
                if let Some(action) = action.as_ref() {
                    narrative_fragments.push(clip_prompt_fragment(action, 18));
                }
            }
        }
        if let Some(motion) = compact_selected_memory_motion_style(&fields.action, &fields.mood) {
            let should_skip_motion = visible_speech_risk
                && compact_selected_memory_performance_style(
                    &fields.action,
                    &fields.dialogue,
                    &fields.mood,
                )
                .is_some()
                && motion
                    .strip_prefix("动作")
                    .map(normalize_prompt_text)
                    .is_some_and(|value| selected_style_fragment_is_low_gain_motion(&value));
            if !should_skip_motion {
                style_fragments.push(motion);
            }
        }
        let performance = compact_selected_memory_performance_style(
            &fields.action,
            &fields.dialogue,
            &fields.mood,
        )
        .filter(|_| {
            visible_speech_risk
                || selected_memory_has_high_signal_visual_performance_cue(&fields.action)
        });
        let voice = visible_speech_risk
            .then(|| {
                compact_selected_memory_voice_style(&fields.action, &fields.dialogue, &fields.mood)
            })
            .flatten();
        if let Some(ref performance) = performance {
            let should_hide_voice = voice.as_deref().is_some_and(|voice| {
                selected_memory_voice_fragment_is_redundant_with_performance(
                    performance,
                    voice,
                    row.prompt.as_deref(),
                )
            });
            style_fragments.push(performance.clone());
            if !should_hide_voice {
                if let Some(ref voice) = voice {
                    style_fragments.push(voice.clone());
                }
            }
        } else if let Some(ref voice) = voice {
            style_fragments.push(voice.clone());
        }
        let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join("");
        if !camera.is_empty() {
            style_fragments.push(format!("镜头{}", clip_prompt_fragment(&camera, 14)));
        }
        if !fields.mood.is_empty() {
            style_fragments.push(format!("情绪{}", clip_prompt_fragment(&fields.mood, 12)));
        }
        if !selected_memory_field_looks_silent(&fields.lighting) {
            style_fragments.push(format!(
                "光影{}",
                clip_prompt_fragment(&fields.lighting, 14)
            ));
        }
        if let Some(sound_stage) = compact_selected_memory_sound_style(&fields.sound) {
            style_fragments.push(sound_stage);
        }
        if let Some(environment) = compact_selected_memory_environment(&fields) {
            style_fragments.push(format!("环境{}", clip_prompt_fragment(&environment, 12)));
        } else if let Some(setting) = setting {
            style_fragments.push(format!("场景{}", clip_prompt_fragment(&setting, 12)));
        }
        style_fragments = compact_selected_memory_style_fragments(style_fragments);
        let has_performance_style = style_fragments
            .iter()
            .any(|fragment| fragment.starts_with("表演"));
        let has_lighting_style = style_fragments
            .iter()
            .any(|fragment| fragment.starts_with("光影"));
        let has_sound_style = style_fragments
            .iter()
            .any(|fragment| fragment.starts_with("声场"));
        if has_performance_style && has_lighting_style && has_sound_style {
            style_fragments.retain(|fragment| {
                if let Some(environment) = fragment.strip_prefix("环境").map(normalize_prompt_text)
                {
                    return !matches!(environment.as_str(), "雨丝玻璃" | "霓虹反光");
                }
                true
            });
        }
        if selected_memory_is_strong_identity_close_up(&fields)
            && performance.is_none()
            && voice.is_none()
        {
            style_fragments.retain(|fragment| {
                fragment
                    .strip_prefix("情绪")
                    .map(normalize_prompt_text)
                    .is_none_or(|mood| !selected_style_fragment_is_generic_restrained_mood(&mood))
            });
        }
        style_fragments =
            compact_selected_memory_identity_scene_style_fragments(style_fragments, &fields);
        let note = compact_selected_memory_note_fragments(style_fragments, narrative_fragments);
        if !note.is_empty() {
            return Some(note);
        }
    }

    row.prompt
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty())
        .map(|text| clip_prompt_fragment(&text, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .or_else(|| {
            row.video_desc
                .as_deref()
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .map(|text| clip_prompt_fragment(&text, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        })
}

pub(super) fn selected_memory_field_looks_silent(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    normalized.is_empty()
        || matches!(
            normalized.as_str(),
            "无" | "无台词" | "无对白" | "无音效" | "无声音" | "none" | "no dialogue" | "no sound"
        )
}

pub(super) fn selected_memory_has_visible_speech_performance_risk(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if selected_memory_field_looks_silent(&fields.dialogue) {
        return false;
    }

    let dialogue = normalize_prompt_text(&fields.dialogue);
    let action = normalize_prompt_text(&fields.action);
    let shot = normalize_prompt_text(&fields.shot);
    let camera_move = normalize_prompt_text(&fields.camera_move);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();

    if selected_memory_dialogue_is_low_gain_utterance(&dialogue)
        && !selected_memory_explicitly_signals_speech(&action, &dialogue, &prompt)
    {
        return false;
    }

    let mut score = 0i32;
    if ["特写", "近景", "近特写", "大特写"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score += 2;
    } else if shot.contains("中景") {
        score += 1;
    } else if ["远景", "全景"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score -= 1;
    }

    if selected_memory_explicitly_signals_speech(&action, &dialogue, &prompt)
        || [
            "嘴角", "唇线", "抿唇", "喉结", "口型", "嘴唇", "失声", "哽咽", "呢喃", "低声", "轻声",
        ]
        .iter()
        .any(|keyword| {
            action.contains(keyword) || dialogue.contains(keyword) || prompt.contains(keyword)
        })
    {
        score += 2;
    }

    if !selected_memory_scene_has_motion_risk(fields)
        || ["静止", "缓推", "慢推", "停顿", "驻足", "停步"]
            .iter()
            .any(|keyword| camera_move.contains(keyword) || action.contains(keyword))
    {
        score += 1;
    }

    if selected_memory_subject_count(fields) > 1 {
        score -= 1;
    }

    score >= 2
}

fn selected_memory_dialogue_is_low_gain_utterance(dialogue: &str) -> bool {
    let stripped = dialogue
        .chars()
        .filter(|ch| {
            !ch.is_whitespace()
                && !matches!(ch, '：' | ':' | '，' | ',' | '。' | '！' | '!' | '？' | '?')
        })
        .collect::<String>();
    if stripped.is_empty() {
        return true;
    }
    if stripped.chars().count() > 2 {
        return false;
    }

    [
        "嗯", "啊", "呀", "哎", "欸", "诶", "哦", "喂", "哈", "呵", "呃", "唉", "哼",
    ]
    .iter()
    .any(|token| stripped == *token)
}

fn selected_memory_explicitly_signals_speech(action: &str, dialogue: &str, prompt: &str) -> bool {
    [action, dialogue, prompt].into_iter().any(|value| {
        !value.is_empty()
            && [
                "开口",
                "说道",
                "说出",
                "说着",
                "低声说",
                "轻声说",
                "哽咽",
                "失声",
                "喊",
                "叫住",
                "质问",
                "回答",
                "回应",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn selected_memory_scene_has_motion_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
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
                "转身", "扑向", "踉跄", "急退",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn selected_memory_subject_count(fields: &StructuredStoryboardDescription) -> usize {
    let subject_refs = selected_memory_subject_aliases(&fields.subject, &fields.subject_refs);
    if !subject_refs.is_empty() {
        return subject_refs.len();
    }

    fields
        .subject
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut subjects, value| {
            if !subjects.iter().any(|existing| existing == &value) {
                subjects.push(value);
            }
            subjects
        })
        .len()
}

pub(super) fn selected_memory_has_high_signal_visual_performance_cue(action: &str) -> bool {
    let action = normalize_prompt_text(action);
    !action.is_empty()
        && [
            "抬眼",
            "抬眸",
            "垂眼",
            "低头",
            "咬唇",
            "抿唇",
            "眼眶发红",
            "喉结滚动",
            "喉头滚动",
            "指尖发颤",
            "指尖轻颤",
            "手指发颤",
            "手指轻颤",
            "嘴角发僵",
            "嘴角僵住",
            "嘴角绷紧",
            "唇角发僵",
            "下颌绷紧",
            "下巴绷紧",
            "下颌发紧",
            "下巴发紧",
            "欲言又止",
            "迟迟没有开口",
            "张了张嘴",
            "话到嘴边",
            "抽气",
            "呼吸发颤",
            "眉心紧锁",
            "蹙眉",
            "皱眉",
        ]
        .iter()
        .any(|keyword| action.contains(keyword))
}

fn selected_memory_needs_identity_continuity(fields: &StructuredStoryboardDescription) -> bool {
    let shot = normalize_prompt_text(&fields.shot);
    let camera_move = normalize_prompt_text(&fields.camera_move);
    let action = normalize_prompt_text(&fields.action);

    let mut score = 0i32;
    if ["特写", "近特写", "大特写", "近景"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score += 2;
    }
    if ["中近景", "肩部", "半身"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score += 1;
    }
    if [
        "抬眼", "抬眸", "垂眼", "低头", "眼神", "目光", "唇", "嘴角", "喉结",
    ]
    .iter()
    .any(|keyword| action.contains(keyword))
    {
        score += 1;
    }
    if ["静止", "停顿", "驻足", "慢推", "缓推", "定镜"]
        .iter()
        .any(|keyword| camera_move.contains(keyword) || action.contains(keyword))
    {
        score += 1;
    }

    score >= 2
}

fn compact_selected_memory_identity_scene_style_fragments(
    fragments: Vec<String>,
    fields: &StructuredStoryboardDescription,
) -> Vec<String> {
    if !selected_memory_needs_identity_continuity(fields)
        || !selected_memory_is_strong_identity_close_up(fields)
        || !selected_memory_field_looks_silent(&fields.dialogue)
    {
        return fragments;
    }

    let has_micro_performance = fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            && (score_selected_identity_micro_performance_fragment(fragment) >= 3
                || ["眼神", "目光", "抬眼", "眉", "唇", "喉结"]
                    .iter()
                    .any(|keyword| fragment.contains(keyword)))
    });
    if !has_micro_performance {
        return fragments;
    }

    let original_len = fragments.len();
    let filtered = fragments
        .iter()
        .filter(|fragment| {
            !matches!(
                selected_identity_scene_low_gain_fragment_family(fragment),
                Some("镜头")
                    | Some("光影")
                    | Some("环境")
                    | Some("场景")
                    | Some("声场")
                    | Some("动作")
                    | Some("情绪")
            )
        })
        .cloned()
        .collect::<Vec<_>>();
    if filtered.is_empty() || filtered.len() == original_len {
        return fragments;
    }

    filtered
}

fn selected_identity_scene_low_gain_fragment_family(fragment: &str) -> Option<&'static str> {
    [
        "镜头", "光影", "环境", "场景", "声场", "动作", "情绪", "表演", "语气",
    ]
    .into_iter()
    .find(|prefix| fragment.starts_with(prefix))
}

pub(super) fn selected_memory_is_strong_identity_close_up(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let shot = normalize_prompt_text(&fields.shot);
    let setting = normalize_prompt_text(&fields.setting);
    let action = normalize_prompt_text(&fields.action);

    ["特写", "近特写", "大特写"]
        .iter()
        .any(|keyword| shot.contains(keyword))
        || ["镜", "倒影", "镜前", "镜中"]
            .iter()
            .any(|keyword| setting.contains(keyword))
        || ["眼神", "目光", "咬唇", "抿唇", "嘴角", "喉结"]
            .iter()
            .any(|keyword| action.contains(keyword))
}

fn score_selected_identity_micro_performance_fragment(fragment: &str) -> i32 {
    let body = fragment.strip_prefix("表演").unwrap_or(fragment);
    let mut score = 0;
    for keyword in [
        "抬眼", "垂眼", "眼神", "目光", "咬唇", "抿唇", "嘴角", "喉结", "下颌",
    ] {
        if body.contains(keyword) {
            score += 2;
        }
    }
    for keyword in ["停顿", "迟疑", "欲言又止", "发颤", "绷紧", "发红"] {
        if body.contains(keyword) {
            score += 1;
        }
    }
    score
}

fn compact_selected_memory_note_fragments(
    style_fragments: Vec<String>,
    narrative_fragments: Vec<String>,
) -> String {
    let mut selected = Vec::new();
    let mut used_chars = 0usize;

    for fragment in style_fragments.into_iter().chain(narrative_fragments) {
        let fragment = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
        if fragment.is_empty() || selected.iter().any(|existing| existing == &fragment) {
            continue;
        }
        let separator_chars = usize::from(!selected.is_empty());
        let next_chars = used_chars + separator_chars + fragment.chars().count();
        if next_chars > VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS {
            continue;
        }
        used_chars = next_chars;
        selected.push(fragment);
    }

    selected.join("，")
}
