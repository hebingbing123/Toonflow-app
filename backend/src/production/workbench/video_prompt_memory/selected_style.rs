use super::*;

pub(super) fn compact_selected_memory_style_fragments(fragments: Vec<String>) -> Vec<String> {
    let note = fragments.join("，");
    compact_video_style_prompt_note(&note)
        .map(|value| split_prompt_note_fragments(&value).collect())
        .unwrap_or_default()
}

pub(super) fn compact_selected_memory_motion_style(action: &str, mood: &str) -> Option<String> {
    let action = normalize_prompt_text(action);
    if action.is_empty() {
        return None;
    }
    let mood = normalize_prompt_text(mood);

    if [
        "优雅", "轻盈", "舒展", "轻拂", "轻旋", "轻扬", "提裙", "拂袖",
    ]
    .iter()
    .any(|keyword| action.contains(keyword))
    {
        return Some("动作缓慢优雅".to_string());
    }

    let subtle_motion = [
        "轻扶", "轻抬", "轻触", "轻拢", "轻掀", "抬眼", "垂眼", "停顿", "顿住", "收住", "缓缓",
        "徐徐", "稳稳", "从容", "迟疑", "克制",
    ]
    .iter()
    .any(|keyword| action.contains(keyword));
    let restrained_mood = ["隐忍", "克制", "压抑", "沉静", "沉稳", "冷静"]
        .iter()
        .any(|keyword| mood.contains(keyword));
    if subtle_motion && restrained_mood {
        return Some("动作从容克制".to_string());
    }

    if [
        "自然",
        "生活化",
        "日常",
        "轻轻",
        "慢慢",
        "缓步",
        "缓慢",
        "平稳",
        "稳步",
    ]
    .iter()
    .any(|keyword| action.contains(keyword))
        || subtle_motion
    {
        return Some("动作自然".to_string());
    }

    None
}

pub(super) fn compact_selected_memory_voice_style(
    action: &str,
    dialogue: &str,
    mood: &str,
) -> Option<String> {
    if selected_memory_field_looks_silent(dialogue) && selected_memory_field_looks_silent(action) {
        return None;
    }

    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    let speech_signal = format!("{action} {dialogue}");
    let restrained_mood = ["隐忍", "克制", "压抑", "沉静", "沉稳", "冷静"]
        .iter()
        .any(|keyword| mood.contains(keyword));
    let hushed = [
        "轻声",
        "低声",
        "压低",
        "压着嗓子",
        "压着声音",
        "耳语",
        "呢喃",
        "喃喃",
        "悄声",
    ]
    .iter()
    .any(|keyword| speech_signal.contains(keyword));
    let fragile = ["哽咽", "颤声", "发颤", "鼻音", "抽气"]
        .iter()
        .any(|keyword| speech_signal.contains(keyword));
    let clipped = ["短促", "急声", "脱口", "急急", "急促"]
        .iter()
        .any(|keyword| speech_signal.contains(keyword));
    let breath_suppressed = [
        "压低气息",
        "压住气息",
        "压着气息",
        "屏住气息",
        "收住气息",
        "抽气后",
    ]
    .iter()
    .any(|keyword| speech_signal.contains(keyword));
    let tail_tremble = ["尾音", "尾声", "发颤", "轻颤", "颤了颤", "尾音发抖"]
        .iter()
        .any(|keyword| speech_signal.contains(keyword));

    if breath_suppressed && (tail_tremble || fragile) {
        return Some("语气压低气息尾音发颤".to_string());
    }
    if hushed && tail_tremble {
        return Some(
            if speech_signal.contains("低声") || speech_signal.contains("压低") {
                "语气低声尾音发颤".to_string()
            } else {
                "语气轻声尾音发颤".to_string()
            },
        );
    }
    if fragile && restrained_mood {
        return Some("语气哽咽克制".to_string());
    }
    if hushed && restrained_mood {
        return Some(
            if speech_signal.contains("低声") || speech_signal.contains("压低") {
                "语气低声克制".to_string()
            } else {
                "语气轻声克制".to_string()
            },
        );
    }
    if fragile {
        return Some("语气哽咽".to_string());
    }
    if hushed {
        return Some(
            if speech_signal.contains("低声") || speech_signal.contains("压低") {
                "语气低声".to_string()
            } else if speech_signal.contains("呢喃")
                || speech_signal.contains("喃喃")
                || speech_signal.contains("耳语")
            {
                "语气呢喃".to_string()
            } else {
                "语气轻声".to_string()
            },
        );
    }
    if clipped {
        return Some("语气短促".to_string());
    }

    None
}

pub(super) fn compact_selected_memory_delivery_style(
    performance: Option<&str>,
    voice: Option<&str>,
) -> Option<String> {
    let performance = performance
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())?;
    let voice = voice
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())?;
    let performance_body = performance
        .strip_prefix("表演")
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())?;
    let voice_body = voice
        .strip_prefix("语气")
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())?;
    Some(format!("表演{performance_body}{voice_body}"))
}

pub(super) fn selected_memory_voice_fragment_is_redundant_with_performance(
    performance: &str,
    voice: &str,
    prompt: Option<&str>,
) -> bool {
    let voice = voice
        .strip_prefix("语气")
        .map(normalize_prompt_text)
        .unwrap_or_else(|| normalize_prompt_text(voice));
    let performance = normalize_prompt_text(performance);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();
    let prompt_already_covers_delivery = !prompt.is_empty()
        && prompt.contains("低声")
        && (prompt.contains("抬眼")
            || prompt.contains("垂眼")
            || prompt.contains("喉头滚动")
            || prompt.contains("喉结滚动"));

    selected_style_fragment_is_low_gain_voice(&voice)
        && (matches!(performance.as_str(), "表演抬眼停顿" | "表演垂眼停顿")
            || (matches!(performance.as_str(), "表演喉结滚动") && prompt_already_covers_delivery))
}

pub(super) fn compact_selected_memory_performance_style(
    action: &str,
    dialogue: &str,
    mood: &str,
) -> Option<String> {
    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    if action.is_empty() && dialogue.is_empty() && mood.is_empty() {
        return None;
    }

    let restrained_mood = ["隐忍", "克制", "压抑", "沉静", "沉稳", "冷静"]
        .iter()
        .any(|keyword| mood.contains(keyword));
    let fragile_mood = ["悲伤", "难过", "心碎", "哀伤", "哽咽"]
        .iter()
        .any(|keyword| mood.contains(keyword));

    if ["抬眼", "抬眸", "抬头"]
        .iter()
        .any(|keyword| action.contains(keyword))
        && ["停顿", "顿住", "迟疑", "没有开口", "欲言又止"]
            .iter()
            .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演抬眼停顿".to_string());
    }
    if ["垂眼", "低头", "别开眼", "移开视线"]
        .iter()
        .any(|keyword| action.contains(keyword))
        && ["停顿", "沉默", "没有开口", "欲言又止"]
            .iter()
            .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演垂眼停顿".to_string());
    }
    if ["咬唇", "抿唇", "唇线绷紧", "嘴唇发白"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演唇线收紧".to_string());
    }
    if ["眼眶发红", "眼圈泛红", "红了眼眶", "眼眶微红"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演眼眶发红".to_string());
    }
    if ["喉结滚动", "喉头滚动", "喉结滑动", "喉头滑动"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演喉结滚动".to_string());
    }
    if ["指尖发颤", "手指发颤", "指尖轻颤", "手指轻颤"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演指尖发颤".to_string());
    }
    if ["嘴角发僵", "嘴角僵住", "嘴角绷紧", "唇角发僵"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演嘴角发僵".to_string());
    }
    if ["下颌绷紧", "下巴绷紧", "下颌发紧", "下巴发紧"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演下颌绷紧".to_string());
    }
    if ["欲言又止", "迟迟没有开口", "张了张嘴", "话到嘴边"]
        .iter()
        .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演欲言又止".to_string());
    }
    if restrained_mood
        && ["忍住", "强忍", "憋住", "压住", "收住"]
            .iter()
            .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演强忍泪意".to_string());
    }
    if fragile_mood
        && ["抽气", "呼吸发颤", "呼吸不稳", "气息发颤"]
            .iter()
            .any(|keyword| action.contains(keyword) || dialogue.contains(keyword))
    {
        return Some("表演呼吸发颤".to_string());
    }
    if restrained_mood
        && ["眉心紧锁", "蹙眉", "皱眉"]
            .iter()
            .any(|keyword| action.contains(keyword))
    {
        return Some("表演眉心紧锁".to_string());
    }

    None
}

pub(super) fn compact_selected_memory_sound_style(sound: &str) -> Option<String> {
    if selected_memory_field_looks_silent(sound) {
        return None;
    }

    let sound = normalize_prompt_text(sound);
    for cue in SOUND_STAGE_STYLE_KEYWORDS {
        if sound.contains(cue) {
            return Some(format!("声场{cue}"));
        }
    }

    if sound.contains("雨") && (sound.contains("回响") || sound.contains("回荡")) {
        return Some("声场雨声回响".to_string());
    }
    if sound.contains("脚步")
        && (sound.contains("空") || sound.contains("回响") || sound.contains("回荡"))
    {
        return Some("声场脚步空响".to_string());
    }
    if sound.contains("风声") && (sound.contains("回响") || sound.contains("回荡")) {
        return Some("声场风声回荡".to_string());
    }
    if sound.contains("呼吸")
        && (sound.contains("近") || sound.contains("贴") || sound.contains("轻"))
    {
        return Some("声场呼吸贴近".to_string());
    }
    if sound.contains("车流") && (sound.contains("闷") || sound.contains("远")) {
        return Some("声场车流闷响".to_string());
    }
    if sound.contains("门轴") || (sound.contains("门") && sound.contains("轻响")) {
        return Some("声场门轴轻响".to_string());
    }
    if sound.contains("衣料") || sound.contains("布料") {
        return Some("声场衣料摩擦".to_string());
    }
    if sound.contains("水滴") && (sound.contains("回声") || sound.contains("回响")) {
        return Some("声场水滴回声".to_string());
    }

    None
}
