use serde::Deserialize;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

const SELECTED_VIDEO_MEMORY_NAME: &str = "selected_video_memory";
const SCRIPT_VIDEO_STYLE_MEMORY_NAME: &str = "script_video_style_memory";
const PROJECT_VIDEO_STYLE_MEMORY_NAME: &str = "project_video_style_memory";
const SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME: &str = "script_role_video_style_memory";
const PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME: &str = "project_role_video_style_memory";
const REJECTED_VIDEO_NEGATIVE_MEMORY_NAME: &str = "rejected_video_negative_memory";
const SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME: &str = "script_video_observation_memory";
const PROJECT_VIDEO_OBSERVATION_MEMORY_NAME: &str = "project_video_observation_memory";
const SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME: &str = "script_role_video_observation_memory";
const PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME: &str = "project_role_video_observation_memory";
const SELECTED_VIDEO_MEMORY_KEEP_ROWS: i64 = 12;
const SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 1;
const PROJECT_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 1;
const SCRIPT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 6;
const PROJECT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 8;
const PROJECT_VIDEO_STYLE_MEMORY_MAX_SAMPLES_PER_SCRIPT: usize = 2;
const REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS: i64 = 12;
const REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS: u32 = 2;
const REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT: usize = 2;
const SCRIPT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS: i64 = 1;
const PROJECT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS: i64 = 1;
const SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS: i64 = 6;
const PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS: i64 = 8;
const PROJECT_VIDEO_OBSERVATION_MEMORY_MAX_SAMPLES_PER_SCRIPT: usize = 2;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
const STYLE_NOTE_PREFIXES: [&str; 9] = [
    "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场", "场景",
];
const STYLE_PROMPT_PREFIXES: [&str; 8] = [
    "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
];
const STABLE_PROMPT_SHOT_KEYWORDS: [&str; 8] = [
    "稳定跟拍",
    "手持跟拍",
    "慢推",
    "推进",
    "拉远",
    "环绕",
    "手持",
    "跟拍",
];
const CONTINUITY_NOTE_KEYWORDS: [&str; 8] = [
    "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
];
const SHOT_STYLE_KEYWORDS: [&str; 9] = [
    "稳定跟拍",
    "手持跟拍",
    "慢推",
    "推进",
    "拉远",
    "环绕",
    "稳定",
    "手持",
    "跟拍",
];
const MOOD_STYLE_KEYWORDS: [&str; 11] = [
    "冷峻压迫",
    "紧张压迫",
    "压迫感",
    "压迫",
    "冷峻",
    "紧张",
    "克制",
    "悬疑",
    "冷调",
    "冷色",
    "悲怆",
];
const LIGHTING_STYLE_KEYWORDS: [&str; 12] = [
    "阴天冷光",
    "暖金逆光",
    "冷调逆光",
    "冷色逆光",
    "霓虹反光",
    "潮湿反光",
    "侧逆光",
    "逆光",
    "冷调",
    "冷光",
    "暖光",
    "霓虹",
];
const ENVIRONMENT_STYLE_KEYWORDS: [&str; 13] = [
    "咖啡热气",
    "手机屏幕亮灭",
    "雨丝玻璃",
    "窗帘轻摆",
    "车流反光",
    "霓虹反光",
    "烛火轻晃",
    "竹影摇动",
    "水波微晃",
    "烟雾流动",
    "花瓣飘落",
    "树叶轻摆",
    "雪花飘落",
];
const MOTION_STYLE_KEYWORDS: [&str; 8] = [
    "缓慢优雅",
    "从容克制",
    "克制自然",
    "简洁平滑",
    "自然",
    "缓慢",
    "轻盈",
    "利落",
];
const PERFORMANCE_STYLE_KEYWORDS: [&str; 12] = [
    "抬眼停顿",
    "垂眼停顿",
    "眼眶发红",
    "唇线收紧",
    "欲言又止",
    "强忍泪意",
    "呼吸发颤",
    "喉结滚动",
    "指尖发颤",
    "眉心紧锁",
    "嘴角发僵",
    "下颌绷紧",
];
const VOICE_STYLE_KEYWORDS: [&str; 11] = [
    "压低气息尾音发颤",
    "低声尾音发颤",
    "轻声尾音发颤",
    "轻声克制",
    "低声克制",
    "哽咽克制",
    "轻声",
    "低声",
    "呢喃",
    "哽咽",
    "短促",
];
const SOUND_STAGE_STYLE_KEYWORDS: [&str; 9] = [
    "雨声回响",
    "脚步空响",
    "风声回荡",
    "呼吸贴近",
    "车流闷响",
    "门轴轻响",
    "衣料摩擦",
    "水滴回声",
    "静场留白",
];
const ACTION_PACE_PREFIXES: [&str; 9] = [
    "快步", "缓步", "迅速", "缓慢", "慢慢", "急忙", "猛地", "立刻", "立即",
];
const ACTION_OBJECT_PREFIX_VERBS: [&str; 10] = [
    "握紧", "拿着", "提着", "举着", "攥着", "扶住", "抱着", "拖着", "背着", "扛着",
];
const ACTION_SUBJECT_PREFIXES: [&str; 10] = [
    "主角", "女主", "男主", "反派", "女孩", "男孩", "女人", "男人", "老人", "孩子",
];
const GENERIC_SUBJECT_ACTION_LEADERS: [&str; 22] = [
    "推", "拉", "冲", "跑", "走", "回", "转", "穿", "扑", "握", "拿", "提", "站", "停", "坐", "靠",
    "看", "望", "抬", "低", "开口", "说",
];
const SETTING_SUBJECT_LEAD_IN_SUFFIXES: [&str; 10] = [
    "身后的",
    "身后",
    "旁边的",
    "旁的",
    "旁边",
    "面前的",
    "前的",
    "后的",
    "所在的",
    "附近的",
];
const PROMPT_LEADING_BRIDGES: [&str; 7] = ["在", "于", "向", "朝", "往", "从", "自"];
const SUBJECT_IDENTITY_TAIL_MARKERS: [&str; 37] = [
    "站在", "停在", "坐在", "靠在", "倚在", "走向", "看向", "看着", "望向", "望着", "强忍", "抬眼",
    "垂眼", "低头", "回头", "停步", "对峙", "冲出", "逼近", "转身", "伸手", "抬手", "扶着", "扶住",
    "捧着", "握着", "拿着", "提着", "轻声", "低声", "压低", "呢喃", "开口", "说着", "说道", "说出",
    "说",
];
const LOW_SIGNAL_SUBJECT_POSE_PREFIXES: [&str; 11] = [
    "站在", "站定", "看向", "看着", "望向", "望着", "坐在", "靠在", "倚在", "留在", "待在",
];
const NON_CHARACTER_ALIAS_SUFFIXES: [&str; 16] = [
    "窗边",
    "门厅",
    "门口",
    "走廊",
    "桌边",
    "桌前",
    "玻璃",
    "咖啡杯",
    "杯",
    "手机",
    "匕首",
    "雨伞",
    "窗帘",
    "门外",
    "落地窗边",
    "夜景",
];

pub(crate) fn split_prompt_note_fragments(note: &str) -> impl Iterator<Item = String> + '_ {
    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
}

#[derive(Debug, Clone, Deserialize, sqlx::FromRow)]
pub(crate) struct StoryboardPromptSeedRow {
    pub(crate) prompt: Option<String>,
    pub(crate) video_desc: Option<String>,
    pub(crate) duration: Option<String>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct AgentMemoryRow {
    pub(crate) name: String,
    pub(crate) content: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct ScopedAgentMemoryRow {
    name: String,
    content: String,
    episodes_id: Option<i32>,
}

#[derive(Debug, Clone)]
pub(crate) struct StructuredStoryboardDescription {
    pub(crate) subject: String,
    pub(crate) setting: String,
    pub(crate) subject_refs: String,
    pub(crate) duration_seconds: Option<i32>,
    pub(crate) shot: String,
    pub(crate) camera_move: String,
    pub(crate) action: String,
    pub(crate) mood: String,
    pub(crate) lighting: String,
    pub(crate) dialogue: String,
    pub(crate) sound: String,
}

pub(crate) fn build_selected_video_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let note = selected_video_memory_note(row)?;
    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    let mut selected_subject = None;
    let mut residual_subject_hint = None;
    let mut residual_action_hint = None;
    if let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
        residual_subject_hint = Some(selected_memory_identity_source(&fields.subject));
        residual_action_hint = compact_selected_memory_action(
            &fields.action,
            Some(fields.subject.as_str()),
            Some(fields.subject.as_str()),
            Some(fields.subject_refs.as_str()),
            Some(fields.setting.as_str()),
            &fields.mood,
        );
        if let Some(subject) =
            selected_memory_subject_identity(&fields.subject, &fields.subject_refs)
        {
            selected_subject = Some(subject.clone());
            parts.push(format!("subject={subject}"));
            let subject_aliases =
                selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                    .into_iter()
                    .filter(|alias| alias != &subject)
                    .collect::<Vec<_>>();
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
        }
    }
    let style = style_only_note(&note);
    if let Some(style) = style.as_ref() {
        parts.push(format!("style={style}"));
    }
    let residual_note = if style.is_some() {
        non_style_note(&note)
    } else {
        Some(note)
    };
    if let Some(note) = residual_note.and_then(|note| {
        compact_selected_memory_residual_note(
            &note,
            selected_subject
                .as_deref()
                .or(residual_subject_hint.as_deref())
                .filter(|value| !value.is_empty()),
            style.as_deref(),
            selected_subject.is_some(),
            residual_action_hint.as_deref(),
        )
    }) {
        parts.push(format!("note={note}"));
    }
    Some(parts.join(" | "))
}

pub(crate) fn build_rejected_video_negative_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut fragments = Vec::new();
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.shot),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.camera_move),
    );
    push_rejected_negative_fragment(&mut fragments, map_rejected_mood_fragment(&fields.mood));
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_lighting_fragment(&fields.lighting),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_performance_fragment(&fields.action, &fields.dialogue, &fields.mood),
    );
    let fragments = compact_rejected_negative_memory_fragments_for_storage(
        fragments.into_iter().map(str::to_string).collect(),
    );
    if fragments.is_empty() {
        return None;
    }
    let risk_tags = rejected_video_negative_risk_tags(&fields, &fragments);

    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if let Some(subject) = selected_memory_subject_identity(&fields.subject, &fields.subject_refs) {
        parts.push(format!("subject={subject}"));
        let subject_aliases =
            selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                .into_iter()
                .filter(|alias| alias != &subject)
                .collect::<Vec<_>>();
        if !subject_aliases.is_empty() {
            parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
        }
    }
    parts.push("rejectionCount=1".to_string());
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn rejected_video_negative_risk_tags(
    fields: &StructuredStoryboardDescription,
    fragments: &[String],
) -> Vec<&'static str> {
    let families = fragments
        .iter()
        .map(|fragment| observation_note_family(fragment))
        .collect::<Vec<_>>();
    let mut tags = Vec::new();

    if families.iter().any(|family| {
        matches!(
            *family,
            "camera_motion_stability" | "flicker_motion_jitter" | "shot_change_framing"
        )
    }) && selected_memory_scene_has_motion_risk(fields)
    {
        tags.push("motion");
    }
    if families
        .iter()
        .any(|family| *family == "character_consistency")
        && rejected_negative_scene_has_identity_risk(fields)
    {
        tags.push("identity");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "camera_framing" | "shot_change_framing"))
        && rejected_negative_scene_has_framing_risk(fields)
    {
        tags.push("framing");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "lighting_backlight" | "lighting_reflection"))
        && rejected_negative_scene_has_lighting_risk(fields)
    {
        tags.push("lighting");
    }
    if families.iter().any(|family| *family == "mood_tone")
        && rejected_negative_scene_needs_emotional_guard(fields)
    {
        tags.push("emotion");
    }
    if families
        .iter()
        .any(|family| *family == "performance_delivery")
        && rejected_negative_scene_needs_expressive_performance_guard(fields)
    {
        tags.push("performance");
    }
    if families.iter().any(|family| *family == "lip_sync")
        && rejected_negative_scene_has_dialogue_guard(fields)
    {
        tags.push("dialogue");
    }

    tags
}

fn rejected_negative_scene_has_framing_risk(fields: &StructuredStoryboardDescription) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "近景",
                    "特写",
                    "仰拍",
                    "俯拍",
                    "倾斜",
                    "跟拍",
                    "推进",
                    "拉远",
                    "摇镜",
                    "甩镜",
                    "切换",
                    "转场",
                    "close-up",
                    "tight close-up",
                    "low angle",
                    "high angle",
                    "dutch angle",
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

fn rejected_negative_scene_has_lighting_risk(fields: &StructuredStoryboardDescription) -> bool {
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
                "逆光",
                "背光",
                "剪影",
                "车灯",
                "冷光",
                "冷调",
                "阴天",
                "曝光",
                "reflection",
                "wet street",
                "headlight reflection",
                "silhouette",
                "backlight",
                "flat lighting",
                "cold lighting",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn rejected_negative_scene_needs_emotional_guard(fields: &StructuredStoryboardDescription) -> bool {
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

fn rejected_negative_scene_needs_expressive_performance_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    rejected_negative_scene_needs_emotional_guard(fields)
        && (!selected_memory_field_looks_silent(&fields.dialogue)
            || [fields.mood.as_str(), fields.action.as_str()]
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
                }))
}

fn rejected_negative_scene_has_dialogue_guard(fields: &StructuredStoryboardDescription) -> bool {
    !selected_memory_field_looks_silent(&fields.dialogue)
}

fn compact_rejected_negative_memory_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = compact_rejected_negative_fragment_risk_budget(fragments);
    let has_cold_lighting = compacted
        .iter()
        .any(|fragment| canonical_observation_note(fragment) == "avoid flat cold lighting");
    if has_cold_lighting {
        compacted.retain(|fragment| {
            canonical_observation_note(fragment) != "avoid overly cold emotional tone"
        });
    }

    if compacted.len() == 1
        && compacted
            .first()
            .is_some_and(|fragment| rejected_negative_memory_fragment_is_low_signal(fragment))
    {
        return Vec::new();
    }

    compacted
}

fn compact_rejected_negative_memory_fragments_for_storage(fragments: Vec<String>) -> Vec<String> {
    let mut scored = compact_rejected_negative_memory_fragments(
        compact_rejected_negative_fragment_families(fragments),
    )
    .into_iter()
    .enumerate()
    .map(|(idx, fragment)| (score_rejected_negative_fragment(&fragment), idx, fragment))
    .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    scored
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn storyboard_memory_key(storyboard_numeric_id: i32) -> Option<String> {
    if storyboard_numeric_id > 0 {
        Some(format!("storyboardIds={storyboard_numeric_id}"))
    } else {
        None
    }
}

pub(crate) async fn persist_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let latest_same_scope = load_latest_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        content,
    )
    .await?;

    if latest_same_scope.as_deref() == Some(content) {
        return Ok(());
    }
    if latest_same_scope.as_deref().is_some_and(|existing| {
        selected_video_memory_update_would_reduce_quality(existing, content)
    }) {
        return Ok(());
    }

    delete_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        content,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn load_latest_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<Option<String>, ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(None);
    };

    let rows = sqlx::query_scalar::<_, String>(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .find(|existing| selected_video_memory_scope(existing).as_ref() == Some(&scope)))
}

async fn delete_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(());
    };

    let rows = sqlx::query_as::<_, (i64, String)>(
        r#"
        SELECT id, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let duplicate_ids = rows
        .into_iter()
        .filter_map(|(id, existing)| {
            (selected_video_memory_scope(&existing).as_ref() == Some(&scope)).then_some(id)
        })
        .collect::<Vec<_>>();
    if duplicate_ids.is_empty() {
        return Ok(());
    }

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id = ANY($1)
        "#,
    )
    .bind(&duplicate_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn persist_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let Some(storyboard_numeric_id) = extract_key_value(content, "storyboardIds")
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_content = if let Some(latest) = latest.as_deref() {
        merge_rejected_video_negative_memory(latest, content)
    } else {
        content.to_string()
    };

    if latest.as_deref() == Some(next_content.as_str()) {
        return Ok(());
    }

    clear_rejected_video_negative_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(&next_content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let Some(storyboard_key) = storyboard_memory_key(storyboard_numeric_id) else {
        return Ok(());
    };
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn refresh_script_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(), ApiError> {
    let selected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rejected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_script_video_style_memory(&selected_rows);
    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME,
        build_script_role_video_style_memories(&selected_rows),
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME,
        build_script_video_observation_memory(&rejected_rows).as_deref(),
        SCRIPT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME,
        build_script_role_video_observation_memories(&rejected_rows),
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await
}

pub(crate) async fn refresh_project_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<(), ApiError> {
    let selected_rows = sqlx::query_as::<_, ScopedAgentMemoryRow>(
        r#"
        SELECT name, content, episodes_id
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS * 4)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rejected_rows = sqlx::query_as::<_, ScopedAgentMemoryRow>(
        r#"
        SELECT name, content, episodes_id
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS * 4)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_project_video_style_memory(&selected_rows);
    replace_project_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        PROJECT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_project_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME,
        build_project_role_video_style_memories(&selected_rows),
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_project_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_VIDEO_OBSERVATION_MEMORY_NAME,
        build_project_video_observation_memory(&rejected_rows).as_deref(),
        PROJECT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_project_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME,
        build_project_role_video_observation_memories(&rejected_rows),
        PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_script_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    select_script_video_style_memory_notes_for_storyboard(rows, None)
}

pub(crate) fn select_script_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    rows.iter()
        .filter(|row| row.name == SCRIPT_VIDEO_STYLE_MEMORY_NAME)
        .filter_map(|row| summary_style_memory_value_for_storyboard(row, storyboard_row))
        .take(1)
        .collect()
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_project_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    select_project_video_style_memory_notes_for_storyboard(rows, None)
}

pub(crate) fn select_project_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    rows.iter()
        .filter(|row| row.name == PROJECT_VIDEO_STYLE_MEMORY_NAME)
        .filter_map(|row| summary_style_memory_value_for_storyboard(row, storyboard_row))
        .take(1)
        .collect()
}

pub(crate) fn select_subject_role_video_style_memory_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
) -> Vec<String> {
    select_subject_role_video_style_memory_notes_for_storyboard(rows, subject_candidates, None)
}

pub(crate) fn select_subject_role_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let subject_candidates = subject_candidates
        .iter()
        .map(|value| normalize_prompt_text(value))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    if subject_candidates.is_empty() {
        return Vec::new();
    }

    let context = build_style_note_selection_context(storyboard_row);
    let mut matches = rows
        .iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME
            )
        })
        .filter(|row| {
            let memory_subjects = role_memory_subject_candidates(&row.content);
            !memory_subjects.is_empty()
                && memory_subjects.iter().any(|memory_subject| {
                    subject_candidates.iter().any(|candidate| {
                        candidate == memory_subject
                            || candidate.contains(memory_subject)
                            || memory_subject.contains(candidate)
                    })
                })
        })
        .filter_map(|row| {
            role_style_memory_value_for_storyboard(row, storyboard_row).map(|note| {
                let evidence_note = selected_video_style_value(row).unwrap_or_else(|| note.clone());
                let storyboard_focus =
                    role_style_storyboard_focus_score(&row.content, storyboard_row);
                let subject_priority =
                    memory_subject_match_priority(&row.content, &subject_candidates);
                let evidence = score_role_style_note_context_evidence(
                    &evidence_note,
                    row.name.as_str(),
                    &context,
                );
                let min_evidence =
                    role_style_memory_min_context_evidence(row.name.as_str(), &context);
                (
                    evidence >= min_evidence,
                    (
                        storyboard_focus,
                        subject_priority,
                        role_style_memory_scope_priority(row.name.as_str()),
                        evidence,
                        role_style_memory_sample_count(&row.content),
                        note,
                    ),
                )
            })
        })
        .filter(|(passes_context_gate, _)| *passes_context_gate)
        .map(|(_, candidate)| candidate)
        .collect::<Vec<_>>();
    let locked_storyboard_focus = matches.iter().map(|entry| entry.0).max().unwrap_or(0);
    if locked_storyboard_focus > 0 {
        matches.retain(|entry| entry.0 == locked_storyboard_focus);
    }
    let locked_subject_priority = matches.iter().map(|entry| entry.1).min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        matches.retain(|entry| entry.1 == locked_subject_priority);
    }
    matches.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.2.cmp(&b.2))
            .then(b.3.cmp(&a.3))
            .then(b.4.cmp(&a.4))
            .then(a.5.len().cmp(&b.5.len()))
    });
    merge_subject_role_style_memory_notes(matches)
}

fn role_style_memory_scope_priority(name: &str) -> u8 {
    match name {
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => 0,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => 1,
        _ => 2,
    }
}

fn role_style_memory_sample_count(content: &str) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

fn role_style_storyboard_focus_score(
    content: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> usize {
    let Some(storyboard_row) = storyboard_row else {
        return 0;
    };
    let memory_subjects = role_memory_subject_candidates(content);
    if memory_subjects.is_empty() {
        return 0;
    }

    let prompt = storyboard_row
        .prompt
        .as_deref()
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let action = fields
        .as_ref()
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let dialogue = fields
        .as_ref()
        .map(|fields| normalize_prompt_text(&fields.dialogue))
        .unwrap_or_default();

    memory_subjects
        .into_iter()
        .map(|memory_subject| {
            usize::from(!action.is_empty() && action.contains(&memory_subject)) * 4
                + usize::from(!dialogue.is_empty() && dialogue.contains(&memory_subject)) * 2
                + usize::from(!prompt.is_empty() && prompt.contains(&memory_subject))
        })
        .max()
        .unwrap_or(0)
}

fn merge_subject_role_style_memory_notes(
    matches: Vec<(usize, usize, u8, usize, usize, String)>,
) -> Vec<String> {
    let mut merged_fragments = Vec::<String>::new();
    let mut fallback_note = None;
    let has_script_scope = matches
        .iter()
        .any(|(_, _, scope_priority, _, _, _)| *scope_priority == 0);

    for (_, _, scope_priority, _, sample_count, note) in matches {
        let compacted = compact_video_style_prompt_note(&note).unwrap_or(note);
        if fallback_note.is_none() {
            fallback_note = Some(compacted.clone());
        }

        for fragment in split_prompt_note_fragments(&compacted) {
            if has_script_scope
                && scope_priority > 0
                && role_style_project_fill_fragment_is_low_support(fragment.as_str(), sample_count)
            {
                continue;
            }
            if !role_memory_fragment_is_character_signal(fragment.as_str())
                || merged_fragments
                    .iter()
                    .any(|existing| role_style_fragment_conflicts_or_overlaps(existing, &fragment))
            {
                continue;
            }
            merged_fragments.push(fragment);
        }
    }

    if merged_fragments.is_empty() {
        return fallback_note.into_iter().collect();
    }

    compact_video_style_prompt_note(&merged_fragments.join("，"))
        .or(fallback_note)
        .into_iter()
        .collect()
}

fn role_style_memory_min_context_evidence(
    name: &str,
    context: &StyleNoteSelectionContext,
) -> usize {
    if style_note_selection_context_is_empty(context) {
        return 0;
    }

    match name {
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => 1,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => 2,
        _ => usize::MAX,
    }
}

fn score_role_style_note_context_evidence(
    note: &str,
    source_name: &str,
    context: &StyleNoteSelectionContext,
) -> usize {
    if style_note_selection_context_is_empty(context) {
        return 0;
    }

    let ranked = RankedStyleNote {
        note: note.to_string(),
        context_note: note.to_string(),
        score: 0,
        recency_idx: 0,
        source_name: source_name.to_string(),
        storyboard_distance: None,
        storyboard_focus: 0,
        subject_priority: usize::MAX,
    };
    score_style_note_context_evidence(&ranked, context)
}

fn role_style_fragment_conflicts_or_overlaps(existing: &str, candidate: &str) -> bool {
    if existing == candidate {
        return true;
    }

    let existing_family = role_style_fragment_family(existing);
    let candidate_family = role_style_fragment_family(candidate);
    if existing_family.is_some() && existing_family == candidate_family {
        return true;
    }

    existing.contains(candidate) || candidate.contains(existing)
}

fn role_style_fragment_family(fragment: &str) -> Option<&'static str> {
    for prefix in [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ] {
        if fragment.starts_with(prefix) {
            return Some(prefix);
        }
    }
    None
}

fn role_style_project_fill_fragment_is_low_support(fragment: &str, sample_count: usize) -> bool {
    sample_count < 4 && role_style_fragment_prefers_strong_support(fragment)
}

fn role_style_fragment_prefers_strong_support(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }

    if let Some(value) = normalized.strip_prefix("动作") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "从容克制" | "克制自然" | "自然" | "缓慢" | "轻盈" | "利落"
        );
    }
    if let Some(value) = normalized.strip_prefix("语气") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "轻声克制" | "低声克制" | "轻声" | "低声" | "短促"
        );
    }
    if let Some(value) = normalized.strip_prefix("情绪") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "克制" | "隐忍" | "压抑" | "沉静" | "冷静"
        );
    }

    false
}

pub(crate) fn select_prioritized_video_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let context = build_style_note_selection_context(storyboard_row);
    let subject_candidates = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let mut candidates = collect_ranked_video_style_note_candidates(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        &subject_candidates,
    )
    .into_iter()
    .filter(|candidate| ranked_style_note_is_worth_recalling(candidate, &context))
    .collect::<Vec<_>>();
    let locked_storyboard_focus = candidates
        .iter()
        .map(|candidate| candidate.storyboard_focus)
        .max()
        .unwrap_or(0);
    if locked_storyboard_focus > 0 {
        candidates.retain(|candidate| candidate.storyboard_focus == locked_storyboard_focus);
    }
    let locked_subject_priority = candidates
        .iter()
        .map(|candidate| candidate.subject_priority)
        .min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        if locked_subject_priority != usize::MAX {
            candidates.retain(|candidate| candidate.subject_priority == locked_subject_priority);
        }
    }
    candidates.sort_by(|a, b| {
        b.storyboard_focus
            .cmp(&a.storyboard_focus)
            .then(a.subject_priority.cmp(&b.subject_priority))
            .then(score_ranked_style_note(b, &context).cmp(&score_ranked_style_note(a, &context)))
            .then(a.note.chars().count().cmp(&b.note.chars().count()))
            .then(b.score.cmp(&a.score))
            .then(a.recency_idx.cmp(&b.recency_idx))
            .then(a.note.cmp(&b.note))
    });
    candidates.into_iter().find_map(|candidate| {
        compact_video_style_prompt_note(&candidate.note).filter(|note| !note.is_empty())
    })
}

pub(crate) fn select_rejected_video_negative_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
    .negative_notes
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct RejectedVideoMemorySelection {
    pub(crate) negative_notes: Vec<String>,
    pub(crate) observation_notes: Vec<String>,
}

pub(crate) fn select_rejected_video_memory_notes_and_observation_candidates_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> RejectedVideoMemorySelection {
    let allow_unseeded_fallback = !has_exact_prompt_seed_memory_match(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[REJECTED_VIDEO_NEGATIVE_MEMORY_NAME],
    );
    let normalized_subject_candidates = subject_candidates
        .iter()
        .map(|value| normalize_prompt_text(value))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    let exact_candidate_rows = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
        .filter_map(|(idx, row)| {
            memory_matches_storyboard(&row.content, storyboard_numeric_id)
                .then_some((idx, row))
                .filter(|(_, row)| {
                    memory_matches_prompt_seed_with_fallback(
                        &row.content,
                        current_prompt_seed,
                        allow_unseeded_fallback,
                    )
                })
        })
        .collect::<Vec<_>>();
    let storyboard_tags = storyboard_risk_tags_for_subject_fallback(storyboard_row);
    let negative_exact_candidate_rows = exact_candidate_rows
        .iter()
        .copied()
        .filter(|(_, row)| {
            rejected_video_negative_rejection_count(&row.content)
                >= REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .collect::<Vec<_>>();
    let observation_exact_candidate_rows = exact_candidate_rows
        .iter()
        .copied()
        .filter(|(_, row)| {
            rejected_video_negative_rejection_count(&row.content)
                < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .collect::<Vec<_>>();
    let allow_subject_scoped_negative_fallback =
        negative_exact_candidate_rows.is_empty() && !storyboard_tags.is_empty();
    let negative_candidate_rows = if allow_subject_scoped_negative_fallback {
        rows.iter()
            .enumerate()
            .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
            .filter(|(_, row)| {
                rejected_video_negative_rejection_count(&row.content)
                    >= REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
            })
            .filter(|(_, row)| {
                memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
            })
            .filter(|(_, row)| {
                memory_matches_rejected_video_risk_tags(&row.content, &storyboard_tags)
            })
            .collect::<Vec<_>>()
    } else {
        negative_exact_candidate_rows
    };
    let allow_subject_scoped_observation_fallback =
        observation_exact_candidate_rows.is_empty() && !storyboard_tags.is_empty();
    let observation_candidate_rows = if allow_subject_scoped_observation_fallback {
        rows.iter()
            .enumerate()
            .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
            .filter(|(_, row)| {
                rejected_video_negative_rejection_count(&row.content)
                    < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
            })
            .filter(|(_, row)| {
                memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
            })
            .filter(|(_, row)| {
                memory_matches_rejected_video_risk_tags(&row.content, &storyboard_tags)
            })
            .collect::<Vec<_>>()
    } else {
        observation_exact_candidate_rows
    };
    let has_matching_negative_subject = !normalized_subject_candidates.is_empty()
        && negative_candidate_rows.iter().any(|(_, row)| {
            memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        });
    let has_matching_observation_subject = !normalized_subject_candidates.is_empty()
        && observation_candidate_rows.iter().any(|(_, row)| {
            memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        });
    let negative_candidate_rows = negative_candidate_rows
        .into_iter()
        .filter(|(_, row)| {
            !has_matching_negative_subject
                || memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        })
        .collect::<Vec<_>>();
    let observation_candidate_rows = observation_candidate_rows
        .into_iter()
        .filter(|(_, row)| {
            !has_matching_observation_subject
                || memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        })
        .collect::<Vec<_>>();

    let mut negative_scored = Vec::new();
    let mut observation_scored = Vec::new();
    for (idx, row) in negative_candidate_rows {
        let Some(avoid) = extract_key_value(&row.content, "avoid") else {
            continue;
        };
        let subject_priority =
            memory_subject_match_priority(&row.content, &normalized_subject_candidates);
        let overlap_priority = reversed_risk_tag_overlap_priority(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_negative_fallback,
        );
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = ranked_rejected_negative_fragments(&avoid);
        if ranked.is_empty() {
            let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            negative_scored.push((
                score_rejected_negative_fragment_for_storyboard(&note, &storyboard_tags),
                subject_priority,
                idx,
                overlap_priority,
                fallback_priority,
                storyboard_distance,
                0usize,
                note,
            ));
        } else {
            negative_scored.extend(ranked.into_iter().enumerate().map(|(fragment_idx, note)| {
                (
                    score_rejected_negative_fragment_for_storyboard(&note, &storyboard_tags),
                    subject_priority,
                    idx,
                    overlap_priority,
                    fallback_priority,
                    storyboard_distance,
                    fragment_idx,
                    note,
                )
            }));
        }
    }

    for (idx, row) in observation_candidate_rows {
        let Some(avoid) = extract_key_value(&row.content, "avoid") else {
            continue;
        };
        let subject_priority =
            memory_subject_match_priority(&row.content, &normalized_subject_candidates);
        let overlap_priority = reversed_risk_tag_overlap_priority(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_observation_fallback,
        );
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = ranked_observation_fragments(&avoid);
        if ranked.len() == 1
            && ranked
                .first()
                .is_some_and(|note| rejected_negative_memory_fragment_is_low_signal(note))
        {
            continue;
        }
        if ranked.is_empty() {
            let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            observation_scored.push((
                score_pending_observation_note_for_storyboard(&note, &storyboard_tags),
                subject_priority,
                idx,
                overlap_priority,
                fallback_priority,
                storyboard_distance,
                0usize,
                note,
            ));
        } else {
            observation_scored.extend(ranked.into_iter().enumerate().map(
                |(fragment_idx, note)| {
                    (
                        score_pending_observation_note_for_storyboard(&note, &storyboard_tags),
                        subject_priority,
                        idx,
                        overlap_priority,
                        fallback_priority,
                        storyboard_distance,
                        fragment_idx,
                        note,
                    )
                },
            ));
        }
    }

    let negative_notes = if negative_scored.is_empty() {
        select_rejected_video_observation_summary_notes(
            rows,
            &normalized_subject_candidates,
            storyboard_row,
        )
    } else {
        select_ranked_rejected_video_memory_negative_notes(negative_scored)
    };
    let observation_notes = if observation_scored.is_empty() {
        select_rejected_video_observation_summary_notes(
            rows,
            &normalized_subject_candidates,
            storyboard_row,
        )
    } else {
        select_ranked_rejected_video_memory_observation_notes(observation_scored)
    };

    RejectedVideoMemorySelection {
        negative_notes,
        observation_notes,
    }
}

pub(crate) fn select_rejected_video_negative_memory_notes_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
    )
    .negative_notes
}

fn select_rejected_video_observation_summary_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let storyboard_tags = storyboard_risk_tags_for_subject_fallback(storyboard_row);
    if storyboard_tags.is_empty() {
        return Vec::new();
    }

    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|row| {
            matches!(
                row.1.name.as_str(),
                SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_VIDEO_OBSERVATION_MEMORY_NAME
            )
        })
        .filter(|row| memory_matches_rejected_video_risk_tags(&row.1.content, &storyboard_tags))
        .filter(|row| {
            if matches!(
                row.1.name.as_str(),
                SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
            ) {
                memory_matches_subject_candidates(&row.1.content, subject_candidates)
            } else {
                true
            }
        })
        .flat_map(|(row_idx, row)| {
            let row_overlap = rejected_video_risk_tag_overlap(&row.content, &storyboard_tags);
            let sample_count = observation_summary_sample_count(&row.content);
            let scope_priority = rejected_observation_summary_scope_priority(row.name.as_str());
            let subject_priority = memory_subject_match_priority(&row.content, subject_candidates);
            let Some(avoid) = extract_key_value(&row.content, "avoid") else {
                return Vec::new();
            };
            let fragments = ranked_rejected_negative_fragments(&avoid);
            fragments
                .into_iter()
                .enumerate()
                .map(|(fragment_idx, fragment)| {
                    (
                        score_rejected_observation_summary_fragment_for_storyboard(
                            &fragment,
                            &storyboard_tags,
                        ),
                        subject_priority,
                        fragment_storyboard_risk_overlap(&fragment, &storyboard_tags),
                        row_overlap,
                        scope_priority,
                        sample_count,
                        row_idx,
                        fragment_idx,
                        fragment,
                    )
                })
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(b.2.cmp(&a.2))
            .then(b.3.cmp(&a.3))
            .then(a.4.cmp(&b.4))
            .then(b.5.cmp(&a.5))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let mut selected = Vec::new();
    for (_, _, _, _, _, _, _, _, fragment) in scored {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            return vec![selected.join(", ")];
        }
    }
    (!selected.is_empty())
        .then(|| vec![selected.join(", ")])
        .unwrap_or_default()
}

fn rejected_observation_summary_scope_priority(name: &str) -> u8 {
    match name {
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME => 0,
        SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME => 1,
        PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME => 2,
        PROJECT_VIDEO_OBSERVATION_MEMORY_NAME => 3,
        _ => u8::MAX,
    }
}

fn score_rejected_observation_summary_fragment_for_storyboard(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_pending_observation_note_for_storyboard(fragment, storyboard_tags)
        + score_rejected_negative_fragment_for_storyboard(fragment, storyboard_tags)
}

fn observation_summary_sample_count(content: &str) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_pending_rejected_video_observation_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Option<String> {
    select_pending_rejected_video_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
    .into_iter()
    .next()
}

pub(crate) fn select_pending_rejected_video_observation_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_pending_rejected_video_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
}

pub(crate) fn select_pending_rejected_video_observation_candidates_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
    )
    .observation_notes
}

fn select_ranked_rejected_video_memory_negative_notes(
    mut scored: Vec<(i32, usize, usize, usize, u8, i32, usize, String)>,
) -> Vec<String> {
    scored.sort_by(|a, b| {
        a.1.cmp(&b.1)
            .then(b.0.cmp(&a.0))
            .then(a.3.cmp(&b.3))
            .then(a.4.cmp(&b.4))
            .then(a.5.cmp(&b.5))
            .then(a.2.cmp(&b.2))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let locked_subject_priority = scored.first().map(|entry| entry.1);
    let mut selected = Vec::new();
    for (_, subject_priority, _, _, _, _, _, fragment) in scored {
        if locked_subject_priority.is_some_and(|locked| subject_priority > locked) {
            continue;
        }
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    (!selected.is_empty())
        .then(|| vec![selected.join(", ")])
        .unwrap_or_default()
}

fn select_ranked_rejected_video_memory_observation_notes(
    mut scored: Vec<(i32, usize, usize, usize, u8, i32, usize, String)>,
) -> Vec<String> {
    scored.sort_by(|a, b| {
        a.1.cmp(&b.1)
            .then(b.0.cmp(&a.0))
            .then(a.3.cmp(&b.3))
            .then(a.4.cmp(&b.4))
            .then(a.5.cmp(&b.5))
            .then(a.2.cmp(&b.2))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let locked_subject_priority = scored.first().map(|entry| entry.1);
    let mut notes = Vec::new();
    for (_, subject_priority, _, _, _, _, _, note) in scored {
        if locked_subject_priority.is_some_and(|locked| subject_priority > locked) {
            continue;
        }
        if observation_note_is_covered(&note, &notes) {
            continue;
        }
        notes.retain(|existing| !observation_note_covers(&note, existing));
        notes.push(note);
    }
    notes
}

fn ranked_observation_fragments(avoid: &str) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_pending_observation_note(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut notes = Vec::new();
    for (_, _, note) in ranked {
        if observation_note_is_covered(&note, &notes) {
            continue;
        }
        notes.retain(|existing| !observation_note_covers(&note, existing));
        notes.push(note);
    }
    notes
}

fn rejected_negative_fragments(avoid: &str) -> Vec<String> {
    compact_rejected_negative_fragment_risk_budget(compact_rejected_negative_fragment_families(
        stitch_rejected_negative_fragments(split_prompt_note_fragments(avoid).collect()),
    ))
}

fn stitch_rejected_negative_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut stitched = Vec::with_capacity(fragments.len());
    let mut idx = 0usize;
    while idx < fragments.len() {
        if let Some((combined, consumed)) =
            match_known_rejected_negative_fragment_sequence(&fragments[idx..])
        {
            stitched.push(combined);
            idx += consumed;
            continue;
        }
        stitched.push(fragments[idx].clone());
        idx += 1;
    }
    stitched
}

fn match_known_rejected_negative_fragment_sequence(parts: &[String]) -> Option<(String, usize)> {
    const KNOWN_COMPOSITES: &[(&str, usize)] = &[
        ("avoid overly cold, oppressive, or frantic mood", 3),
        ("avoid warped anatomy, blur, flicker", 3),
        ("avoid face distortion, identity drift, costume drift", 3),
    ];

    for &(candidate, consumed) in KNOWN_COMPOSITES {
        if parts.len() < consumed {
            continue;
        }
        let joined = parts[..consumed].join(", ");
        if normalize_prompt_text(&joined) == normalize_prompt_text(candidate) {
            return Some((candidate.to_string(), consumed));
        }
    }
    None
}

fn compact_rejected_negative_avoid(avoid: &str) -> String {
    let mut scored = ranked_rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| (score_rejected_negative_fragment(&fragment), idx, fragment))
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));

    let mut selected = Vec::new();
    for (_, _, fragment) in scored {
        if selected.iter().any(|existing| existing == &fragment) {
            continue;
        }
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    selected.join(", ")
}

fn ranked_rejected_negative_fragments(avoid: &str) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_rejected_negative_fragment(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut selected = Vec::new();
    for (_, _, fragment) in ranked {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
    }
    selected
}

fn score_rejected_negative_fragment(fragment: &str) -> i32 {
    let normalized = normalize_prompt_text(fragment).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "follow", "stable", "shot", "framing", "镜头",
        "运镜", "抖动", "跳轴", "机位",
    ] {
        if normalized.contains(keyword) {
            score += 20;
        }
    }
    for keyword in [
        "flicker", "jitter", "stutter", "blur", "warped", "anatom", "face", "identity", "costume",
        "flash", "闪烁", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "lighting",
        "light",
        "silhouette",
        "backlight",
        "cold",
        "neon",
        "flat",
        "光影",
        "逆光",
        "冷光",
        "曝光",
        "反光",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "tone",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "冷调",
        "悲怆",
        "台词",
        "表演",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 8
}

fn score_rejected_negative_fragment_for_storyboard(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_rejected_negative_fragment(fragment)
        + fragment_storyboard_risk_overlap(fragment, storyboard_tags) as i32 * 18
}

fn score_pending_observation_note(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "镜头", "运镜", "抖动", "跳轴", "站位", "走位",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "lighting", "light", "flat", "flicker", "冷光", "光影", "曝光", "闪烁", "色温",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "blur", "warped", "anatom", "face", "identity", "costume", "模糊", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "节奏",
        "表演",
        "台词",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 6
}

fn score_pending_observation_note_for_storyboard(note: &str, storyboard_tags: &[String]) -> i32 {
    score_pending_observation_note(note)
        + fragment_storyboard_risk_overlap(note, storyboard_tags) as i32 * 18
}

fn reversed_risk_tag_overlap_priority(content: &str, storyboard_tags: &[String]) -> usize {
    usize::MAX - rejected_video_risk_tag_overlap(content, storyboard_tags)
}

fn compact_rejected_negative_fragment_risk_budget(fragments: Vec<String>) -> Vec<String> {
    if fragments.len() < 2 {
        return fragments;
    }

    let has_high_signal_visual_guard = fragments
        .iter()
        .any(|fragment| rejected_negative_fragment_is_high_signal_visual_guard(fragment));
    if !has_high_signal_visual_guard {
        return fragments;
    }

    let filtered = fragments
        .iter()
        .filter(|fragment| !rejected_negative_fragment_is_low_priority_style_retry(fragment))
        .cloned()
        .collect::<Vec<_>>();
    if filtered.is_empty() {
        fragments
    } else {
        filtered
    }
}

fn rejected_negative_fragment_is_high_signal_visual_guard(fragment: &str) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid face distortion, identity drift, costume drift"
            | "avoid warped anatomy, blur, flicker"
    )
}

fn rejected_negative_fragment_is_low_priority_style_retry(fragment: &str) -> bool {
    if rejected_negative_memory_fragment_is_low_signal(fragment) {
        return true;
    }

    matches!(
        observation_note_family(fragment),
        "camera_framing" | "lighting_backlight" | "lighting_reflection"
    )
}

fn observation_note_is_covered(candidate: &str, existing_notes: &[String]) -> bool {
    existing_notes
        .iter()
        .any(|existing| observation_note_covers(existing, candidate))
}

fn observation_note_covers(existing: &str, candidate: &str) -> bool {
    if observation_note_same_family(existing, candidate) {
        return score_pending_observation_note(existing)
            >= score_pending_observation_note(candidate);
    }
    observation_note_contains(existing, candidate)
}

fn observation_note_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_observation_note(existing);
    let candidate = canonical_observation_note(candidate);
    if existing.is_empty() || candidate.is_empty() {
        return false;
    }
    if existing == candidate {
        return true;
    }
    let min_overlap_len = 12;
    existing.len() >= candidate.len()
        && candidate.len() >= min_overlap_len
        && existing.contains(&candidate)
}

fn observation_note_same_family(existing: &str, candidate: &str) -> bool {
    let existing = observation_note_family(existing);
    let candidate = observation_note_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn observation_note_family(value: &str) -> &'static str {
    let canonical = canonical_observation_note(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" | "avoid extra shot changes or wrong framing" => {
            "shot_change_framing"
        }
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid warped hands or limbs"
        | "avoid warped anatomy"
        | "avoid blur"
        | "avoid warped anatomy, blur, flicker" => "visual_error",
        "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => {
            if canonical.contains("shaky")
                || canonical.contains("handheld")
                || canonical.contains("stable follow camera")
                || canonical.contains("follow camera")
            {
                "camera_motion_stability"
            } else if canonical.contains("shot change")
                || canonical.contains("wrong framing")
                || canonical.contains("unnecessary shot")
            {
                "shot_change_framing"
            } else if canonical.contains("tragic")
                || canonical.contains("oppressive")
                || canonical.contains("frantic")
                || canonical.contains("cold emotional tone")
            {
                "mood_tone"
            } else if canonical.contains("blank expression")
                || canonical.contains("monotone")
                || canonical.contains("delivery")
            {
                "performance_delivery"
            } else if canonical.contains("neon reflection") || canonical.contains("reflection") {
                "lighting_reflection"
            } else if canonical.contains("lip-sync") {
                "lip_sync"
            } else {
                ""
            }
        }
    }
}

fn canonical_observation_note(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 {
        return Vec::new();
    }
    let allow_unseeded_fallback = !has_exact_prompt_seed_memory_match(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[SELECTED_VIDEO_MEMORY_NAME],
    );
    let mut style_notes = Vec::new();
    let mut fallback_notes = Vec::new();
    for row in rows {
        if row.name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        if !memory_matches_storyboard(&row.content, storyboard_numeric_id) {
            continue;
        }
        if !memory_matches_prompt_seed_with_fallback(
            &row.content,
            current_prompt_seed,
            allow_unseeded_fallback,
        ) {
            continue;
        }
        if let Some(note) = selected_video_style_value(row) {
            if style_notes.iter().all(|existing| existing != &note) {
                style_notes.push(note);
            }
            continue;
        }

        let Some(note) = extract_key_value(&row.content, "note")
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
            .filter(|value| !is_low_signal_selected_memory_note(value))
        else {
            continue;
        };
        if fallback_notes.iter().all(|existing| existing != &note) {
            fallback_notes.push(note);
        }
    }

    if let Some(note) = select_best_selected_video_style_note(style_notes) {
        return vec![note];
    }
    fallback_notes.into_iter().take(1).collect()
}

fn select_best_selected_video_style_note(notes: Vec<String>) -> Option<String> {
    notes.into_iter().max_by(|a, b| {
        score_selected_video_style_note(a)
            .cmp(&score_selected_video_style_note(b))
            .then(count_selected_video_style_axes(a).cmp(&count_selected_video_style_axes(b)))
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

fn score_selected_video_style_note(note: &str) -> i32 {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    if fragments.is_empty() {
        return 0;
    }

    let mut score = 0i32;
    for fragment in &fragments {
        if fragment.starts_with("情绪") {
            score += 6;
        } else if fragment.starts_with("光影") {
            score += 6;
        } else if fragment.starts_with("镜头") {
            score += if is_local_framing_only_fragment(fragment) {
                1
            } else {
                4
            };
        } else {
            score += 2;
        }
    }
    if count_selected_video_style_axes(note) >= 2 {
        score += 2;
    }
    score
}

fn count_selected_video_style_axes(note: &str) -> usize {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    [
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("镜头")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("情绪")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("光影")),
    ]
    .into_iter()
    .filter(|present| *present)
    .count()
}

fn is_local_framing_only_fragment(fragment: &str) -> bool {
    fragment == "镜头近景"
        || fragment == "镜头中景"
        || fragment == "镜头远景"
        || fragment == "镜头特写"
        || fragment == "镜头全景"
}

#[derive(Debug, Default, Clone, Copy)]
struct ObservationCharacterConsistencyFlags {
    face_distortion: bool,
    identity_drift: bool,
    costume_inconsistency: bool,
}

#[derive(Debug, Default, Clone, Copy)]
struct ObservationVisualErrorFlags {
    warped_anatomy: bool,
    blur: bool,
    flicker: bool,
}

#[derive(Debug, Default, Clone, Copy)]
struct ObservationVisualStyleConstraintFlags {
    extreme_camera_angle: bool,
    tight_close_up: bool,
    oppressive_or_frantic_mood: bool,
    blank_expression_or_monotone_delivery: bool,
    overly_cold_emotional_tone: bool,
    flat_cold_lighting: bool,
    harsh_backlight_silhouette: bool,
}

fn compact_rejected_negative_fragment_families(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut character_flags = ObservationCharacterConsistencyFlags::default();
    let mut character_idx = None;
    let mut visual_error_flags = ObservationVisualErrorFlags::default();
    let mut visual_error_idx = None;
    let mut visual_style_flags = ObservationVisualStyleConstraintFlags::default();
    let mut visual_style_idx = None;

    for (idx, fragment) in fragments.into_iter().enumerate() {
        if let Some(flags) = parse_observation_character_consistency_fragment(&fragment) {
            character_idx.get_or_insert(idx);
            character_flags.face_distortion |= flags.face_distortion;
            character_flags.identity_drift |= flags.identity_drift;
            character_flags.costume_inconsistency |= flags.costume_inconsistency;
            continue;
        }
        if let Some(flags) = parse_observation_visual_error_fragment(&fragment) {
            visual_error_idx.get_or_insert(idx);
            visual_error_flags.warped_anatomy |= flags.warped_anatomy;
            visual_error_flags.blur |= flags.blur;
            visual_error_flags.flicker |= flags.flicker;
            continue;
        }
        if let Some(flags) = parse_observation_visual_style_constraint_fragment(&fragment) {
            visual_style_idx.get_or_insert(idx);
            visual_style_flags.extreme_camera_angle |= flags.extreme_camera_angle;
            visual_style_flags.tight_close_up |= flags.tight_close_up;
            visual_style_flags.oppressive_or_frantic_mood |= flags.oppressive_or_frantic_mood;
            visual_style_flags.blank_expression_or_monotone_delivery |=
                flags.blank_expression_or_monotone_delivery;
            visual_style_flags.overly_cold_emotional_tone |= flags.overly_cold_emotional_tone;
            visual_style_flags.flat_cold_lighting |= flags.flat_cold_lighting;
            visual_style_flags.harsh_backlight_silhouette |= flags.harsh_backlight_silhouette;
            continue;
        }
        compacted.push((idx, fragment));
    }

    if let Some(idx) = character_idx {
        compacted.push((
            idx,
            render_observation_character_consistency_fragment(character_flags),
        ));
    }
    if let Some(idx) = visual_error_idx {
        for fragment in render_observation_visual_error_fragments(visual_error_flags) {
            compacted.push((idx, fragment));
        }
    }
    if let Some(idx) = visual_style_idx {
        for fragment in render_observation_visual_style_constraint_fragments(visual_style_flags) {
            compacted.push((idx, fragment));
        }
    }
    compacted.sort_by(|a, b| a.0.cmp(&b.0));
    compacted
        .into_iter()
        .map(|(_, fragment)| fragment)
        .collect()
}

fn parse_observation_character_consistency_fragment(
    fragment: &str,
) -> Option<ObservationCharacterConsistencyFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid face distortion or identity drift" => Some(ObservationCharacterConsistencyFlags {
            face_distortion: true,
            identity_drift: true,
            costume_inconsistency: false,
        }),
        "avoid costume or character drift" => Some(ObservationCharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        "avoid face drift or costume inconsistency" => Some(ObservationCharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        "avoid face distortion, identity drift, costume drift" => {
            Some(ObservationCharacterConsistencyFlags {
                face_distortion: true,
                identity_drift: true,
                costume_inconsistency: true,
            })
        }
        _ => None,
    }
}

fn render_observation_character_consistency_fragment(
    flags: ObservationCharacterConsistencyFlags,
) -> String {
    if flags.face_distortion && flags.costume_inconsistency {
        "avoid face distortion, identity drift, costume drift".to_string()
    } else if flags.costume_inconsistency {
        "avoid face drift or costume inconsistency".to_string()
    } else {
        "avoid face distortion or identity drift".to_string()
    }
}

fn parse_observation_visual_error_fragment(fragment: &str) -> Option<ObservationVisualErrorFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid warped hands or limbs" | "avoid warped anatomy" => {
            Some(ObservationVisualErrorFlags {
                warped_anatomy: true,
                ..Default::default()
            })
        }
        "avoid blur" => Some(ObservationVisualErrorFlags {
            blur: true,
            ..Default::default()
        }),
        "avoid flicker" | "avoid flicker or motion jitter" => Some(ObservationVisualErrorFlags {
            flicker: true,
            ..Default::default()
        }),
        "avoid warped anatomy, blur, flicker" => Some(ObservationVisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            flicker: true,
        }),
        _ => None,
    }
}

fn render_observation_visual_error_fragments(flags: ObservationVisualErrorFlags) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped anatomy".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    if flags.flicker {
        fragments.push("avoid flicker or motion jitter".to_string());
    }
    fragments
}

fn parse_observation_visual_style_constraint_fragment(
    fragment: &str,
) -> Option<ObservationVisualStyleConstraintFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid extreme camera angle" => Some(ObservationVisualStyleConstraintFlags {
            extreme_camera_angle: true,
            ..Default::default()
        }),
        "avoid overly tight close-up framing" => Some(ObservationVisualStyleConstraintFlags {
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle or overly tight close-up framing" => {
            Some(ObservationVisualStyleConstraintFlags {
                extreme_camera_angle: true,
                tight_close_up: true,
                ..Default::default()
            })
        }
        "avoid oppressive or frantic mood" => Some(ObservationVisualStyleConstraintFlags {
            oppressive_or_frantic_mood: true,
            ..Default::default()
        }),
        "avoid blank expression or monotone delivery" => {
            Some(ObservationVisualStyleConstraintFlags {
                blank_expression_or_monotone_delivery: true,
                ..Default::default()
            })
        }
        "avoid overly cold emotional tone" => Some(ObservationVisualStyleConstraintFlags {
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid overly cold, oppressive, or frantic mood" => {
            Some(ObservationVisualStyleConstraintFlags {
                oppressive_or_frantic_mood: true,
                overly_cold_emotional_tone: true,
                ..Default::default()
            })
        }
        "avoid flat cold lighting" => Some(ObservationVisualStyleConstraintFlags {
            flat_cold_lighting: true,
            ..Default::default()
        }),
        "avoid harsh backlight silhouette" => Some(ObservationVisualStyleConstraintFlags {
            harsh_backlight_silhouette: true,
            ..Default::default()
        }),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            Some(ObservationVisualStyleConstraintFlags {
                flat_cold_lighting: true,
                harsh_backlight_silhouette: true,
                ..Default::default()
            })
        }
        _ => None,
    }
}

fn render_observation_visual_style_constraint_fragments(
    flags: ObservationVisualStyleConstraintFlags,
) -> Vec<String> {
    let mut fragments = Vec::new();
    if flags.extreme_camera_angle && flags.tight_close_up {
        fragments.push("avoid extreme camera angle or overly tight close-up framing".to_string());
    } else if flags.extreme_camera_angle {
        fragments.push("avoid extreme camera angle".to_string());
    } else if flags.tight_close_up {
        fragments.push("avoid overly tight close-up framing".to_string());
    }

    if flags.oppressive_or_frantic_mood && flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold, oppressive, or frantic mood".to_string());
    } else if flags.oppressive_or_frantic_mood {
        fragments.push("avoid oppressive or frantic mood".to_string());
    } else if flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    if flags.blank_expression_or_monotone_delivery {
        fragments.push("avoid blank expression or monotone delivery".to_string());
    }

    if flags.flat_cold_lighting && flags.harsh_backlight_silhouette {
        fragments.push("avoid flat cold lighting or harsh backlight silhouette".to_string());
    } else if flags.flat_cold_lighting {
        fragments.push("avoid flat cold lighting".to_string());
    } else if flags.harsh_backlight_silhouette {
        fragments.push("avoid harsh backlight silhouette".to_string());
    }

    fragments
}

pub(crate) fn select_neighbor_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    limit: usize,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 || limit == 0 {
        return Vec::new();
    }
    let mut scored = rows
        .iter()
        .enumerate()
        .filter_map(|(idx, row)| {
            if row.name != SELECTED_VIDEO_MEMORY_NAME {
                return None;
            }
            let storyboard_ids = extract_storyboard_ids(&row.content);
            if storyboard_ids.is_empty() || storyboard_ids.contains(&storyboard_numeric_id) {
                return None;
            }
            let distance = storyboard_ids
                .iter()
                .map(|id| (storyboard_numeric_id - *id).abs())
                .min()?;
            let note = extract_key_value(&row.content, "style")
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .or_else(|| {
                    extract_key_value(&row.content, "note").and_then(|value| {
                        let fragments = value
                            .split(['，', ',', '；', ';', '。', '\n'])
                            .map(normalize_prompt_text)
                            .filter(|fragment| {
                                STYLE_NOTE_PREFIXES
                                    .iter()
                                    .any(|prefix| fragment.starts_with(prefix))
                            })
                            .collect::<Vec<_>>();
                        if fragments.is_empty() {
                            None
                        } else {
                            Some(clip_prompt_fragment(
                                &fragments.join("，"),
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        }
                    })
                })
                .or_else(|| selected_video_style_value(row))?;
            Some((distance, idx, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

    let mut notes = Vec::new();
    for (_, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= limit {
            break;
        }
    }
    notes
}

pub(crate) fn normalize_prompt_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(crate) fn clip_prompt_fragment(text: &str, max_chars: usize) -> String {
    let normalized = normalize_prompt_text(text);
    let mut chars = normalized.chars();
    let clipped = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

pub(crate) fn parse_structured_storyboard_description(
    description: &str,
) -> Option<StructuredStoryboardDescription> {
    let normalized = description
        .trim()
        .trim_start_matches(['（', '('])
        .trim_end_matches(['）', ')'])
        .trim();
    if normalized.is_empty() {
        return None;
    }
    let parts = normalized
        .split('、')
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();
    if parts.len() < 8 {
        return None;
    }
    Some(StructuredStoryboardDescription {
        subject: parts.first().cloned().unwrap_or_default(),
        setting: parts.get(1).cloned().unwrap_or_default(),
        subject_refs: parts.get(2).cloned().unwrap_or_default(),
        duration_seconds: parts.get(3).and_then(|value| parse_positive_int(value)),
        shot: parts.get(4).cloned().unwrap_or_default(),
        camera_move: parts.get(5).cloned().unwrap_or_default(),
        action: parts.get(6).cloned().unwrap_or_default(),
        mood: parts.get(7).cloned().unwrap_or_default(),
        lighting: parts.get(8).cloned().unwrap_or_default(),
        dialogue: parts.get(9).cloned().unwrap_or_default(),
        sound: parts.get(10).cloned().unwrap_or_default(),
    })
}

pub(crate) fn parse_positive_int(text: &str) -> Option<i32> {
    let mut digits = String::new();
    for ch in text.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }
    digits.parse::<i32>().ok().filter(|value| *value > 0)
}

pub(crate) fn extract_key_value(row: &str, key: &str) -> Option<String> {
    let marker = format!("{key}=");
    let start = row.find(&marker)? + marker.len();
    let rest = &row[start..];
    let end = rest
        .find(" | ")
        .or_else(|| rest.find("; "))
        .unwrap_or(rest.len());
    let value = normalize_prompt_text(rest[..end].trim());
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct SelectedVideoMemoryScope {
    storyboard_ids: String,
    prompt_seed: Option<String>,
}

fn selected_video_memory_scope(content: &str) -> Option<SelectedVideoMemoryScope> {
    let storyboard_ids = extract_key_value(content, "storyboardIds")?;
    Some(SelectedVideoMemoryScope {
        storyboard_ids,
        prompt_seed: extract_key_value(content, "promptSeed"),
    })
}

fn rejected_video_negative_rejection_count(content: &str) -> u32 {
    extract_key_value(content, "rejectionCount")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|count| *count > 0)
        .unwrap_or(1)
}

fn rejected_video_memory_prompt_seed(content: &str) -> Option<String> {
    extract_key_value(content, "promptSeed")
}

fn extract_rejected_video_risk_tags(content: &str) -> Vec<String> {
    extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn storyboard_risk_tags_for_subject_fallback(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Vec::new();
    };
    let mut tags = Vec::new();
    if selected_memory_scene_has_motion_risk(&fields) {
        tags.push("motion".to_string());
    }
    if rejected_negative_scene_has_identity_risk(&fields) {
        tags.push("identity".to_string());
    }
    if rejected_negative_scene_has_framing_risk(&fields) {
        tags.push("framing".to_string());
    }
    if rejected_negative_scene_has_lighting_risk(&fields) {
        tags.push("lighting".to_string());
    }
    if rejected_negative_scene_needs_emotional_guard(&fields) {
        tags.push("emotion".to_string());
    }
    if rejected_negative_scene_needs_expressive_performance_guard(&fields) {
        tags.push("performance".to_string());
    }
    if rejected_negative_scene_has_dialogue_guard(&fields) {
        tags.push("dialogue".to_string());
    }
    tags
}

fn rejected_video_risk_tag_overlap(content: &str, storyboard_tags: &[String]) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    memory_tags
        .iter()
        .filter(|memory_tag| storyboard_tags.iter().any(|tag| tag == *memory_tag))
        .count()
}

fn fragment_storyboard_risk_overlap(fragment: &str, storyboard_tags: &[String]) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    negative_fragment_storyboard_risk_tags(fragment)
        .iter()
        .filter(|tag| storyboard_tags.iter().any(|value| value == **tag))
        .count()
}

fn negative_fragment_storyboard_risk_tags(fragment: &str) -> &'static [&'static str] {
    match canonical_observation_note(fragment).as_str() {
        "avoid rushed motion"
        | "avoid rushed or jerky motion"
        | "avoid flicker"
        | "avoid flicker or motion jitter" => &["motion"],
        "avoid unnecessary shot changes"
        | "avoid extra shot changes or wrong framing"
        | "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => &["framing"],
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette"
        | "avoid distracting neon reflections" => &["lighting"],
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => &["identity"],
        "avoid lip-sync mismatch" => &["dialogue"],
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => &["performance", "dialogue", "emotion"],
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => &["emotion"],
        _ => &[],
    }
}

fn rejected_negative_scene_has_identity_risk(fields: &StructuredStoryboardDescription) -> bool {
    let has_subject = !normalize_prompt_text(&fields.subject).is_empty();
    if !has_subject {
        return false;
    }

    if rejected_negative_scene_needs_expressive_performance_guard(fields)
        || rejected_negative_scene_has_dialogue_guard(fields)
    {
        return true;
    }

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
                "近景",
                "中近景",
                "半身",
                "特写",
                "脸部",
                "面部",
                "肖像",
                "抬眼",
                "回头",
                "对视",
                "凝视",
                "眼神",
                "唇",
                "喉结",
                "眉",
                "泪",
                "close-up",
                "medium close-up",
                "portrait",
                "face",
                "eye",
                "gaze",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn memory_matches_rejected_video_risk_tags(content: &str, storyboard_tags: &[String]) -> bool {
    if storyboard_tags.is_empty() {
        return false;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    !memory_tags.is_empty()
        && memory_tags
            .iter()
            .any(|memory_tag| storyboard_tags.iter().any(|tag| tag == memory_tag))
}

fn storyboard_fallback_priority(
    content: &str,
    storyboard_numeric_id: i32,
    allow_subject_scoped_fallback: bool,
) -> u8 {
    if memory_matches_storyboard(content, storyboard_numeric_id) {
        0
    } else if allow_subject_scoped_fallback {
        1
    } else {
        0
    }
}

fn merged_subject_aliases(existing: &str, incoming: &str, subject: &str) -> String {
    let mut aliases = role_memory_subject_candidates(existing);
    aliases.extend(role_memory_subject_candidates(incoming));
    aliases.retain(|alias| alias != subject);
    aliases.sort();
    aliases.dedup();
    aliases.join("/")
}

fn merge_rejected_video_negative_memory(existing: &str, incoming: &str) -> String {
    let incoming_prompt_seed = rejected_video_memory_prompt_seed(incoming);
    let existing_prompt_seed = rejected_video_memory_prompt_seed(existing);
    if incoming_prompt_seed != existing_prompt_seed {
        return incoming.to_string();
    }

    let storyboard_numeric_id = extract_key_value(incoming, "storyboardIds")
        .or_else(|| extract_key_value(existing, "storyboardIds"))
        .unwrap_or_default();
    let prompt_seed = incoming_prompt_seed
        .or(existing_prompt_seed)
        .unwrap_or_default();
    let subject = extract_key_value(incoming, "subject")
        .or_else(|| extract_key_value(existing, "subject"))
        .unwrap_or_default();
    let subject_aliases = merged_subject_aliases(existing, incoming, &subject);
    let rejection_count = rejected_video_negative_rejection_count(existing).saturating_add(1);
    let risk_tags = merged_rejected_video_risk_tags(existing, incoming);
    let avoid = merge_rejected_negative_avoid(
        extract_key_value(existing, "avoid").as_deref(),
        extract_key_value(incoming, "avoid").as_deref(),
    );

    let mut parts = Vec::new();
    if !storyboard_numeric_id.is_empty() {
        parts.push(format!("storyboardIds={storyboard_numeric_id}"));
    }
    if !prompt_seed.is_empty() {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if !subject.is_empty() {
        parts.push(format!("subject={subject}"));
    }
    if !subject_aliases.is_empty() {
        parts.push(format!("subjectAliases={subject_aliases}"));
    }
    parts.push(format!("rejectionCount={rejection_count}"));
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !avoid.is_empty() {
        parts.push(format!("avoid={avoid}"));
    }
    parts.join(" | ")
}

fn merged_rejected_video_risk_tags(existing: &str, incoming: &str) -> Vec<String> {
    let mut tags = extract_rejected_video_risk_tags(existing);
    tags.extend(extract_rejected_video_risk_tags(incoming));
    tags.sort();
    tags.dedup();
    tags
}

fn memory_matches_subject_candidates(content: &str, subject_candidates: &[String]) -> bool {
    memory_subject_match_priority(content, subject_candidates) != usize::MAX
}

fn memory_subject_match_priority(content: &str, subject_candidates: &[String]) -> usize {
    if subject_candidates.is_empty() {
        return usize::MAX;
    }
    let memory_subjects = role_memory_subject_candidates(content);
    if memory_subjects.is_empty() {
        return usize::MAX;
    }

    subject_candidates
        .iter()
        .enumerate()
        .find_map(|(idx, candidate)| {
            memory_subjects
                .iter()
                .any(|memory_subject| {
                    candidate == memory_subject
                        || candidate.contains(memory_subject)
                        || memory_subject.contains(candidate)
                })
                .then_some(idx)
        })
        .unwrap_or(usize::MAX)
}

fn merge_rejected_negative_avoid(existing: Option<&str>, incoming: Option<&str>) -> String {
    let mut fragments = Vec::new();
    for value in [existing, incoming].into_iter().flatten() {
        for fragment in split_prompt_note_fragments(value) {
            if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
                continue;
            }
            fragments.push(fragment);
        }
    }
    compact_rejected_negative_memory_fragments_for_storage(fragments).join(", ")
}

fn selected_video_memory_note(row: &StoryboardPromptSeedRow) -> Option<String> {
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
            style_fragments.push(motion);
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
        if let Some(delivery) =
            compact_selected_memory_delivery_style(performance.as_deref(), voice.as_deref())
        {
            style_fragments.push(delivery);
        } else {
            if let Some(performance) = performance {
                style_fragments.push(performance);
            }
            if let Some(voice) = voice {
                style_fragments.push(voice);
            }
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

fn selected_memory_field_looks_silent(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    normalized.is_empty()
        || matches!(
            normalized.as_str(),
            "无" | "无台词" | "无对白" | "无音效" | "无声音" | "none" | "no dialogue" | "no sound"
        )
}

fn selected_memory_has_visible_speech_performance_risk(
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
    let char_count = stripped.chars().count();
    if char_count > 2 {
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

fn selected_memory_scene_has_motion_risk(fields: &StructuredStoryboardDescription) -> bool {
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

fn selected_memory_has_high_signal_visual_performance_cue(action: &str) -> bool {
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
            "嘴角发僵",
            "下颌绷紧",
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
                Some("镜头") | Some("光影") | Some("环境") | Some("场景") | Some("声场")
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

fn compact_selected_memory_style_fragments(fragments: Vec<String>) -> Vec<String> {
    let note = fragments.join("，");
    compact_video_style_prompt_note(&note)
        .map(|value| split_prompt_note_fragments(&value).collect())
        .unwrap_or_default()
}

fn compact_selected_memory_subject(subject: &str, action: &str) -> Option<String> {
    let subject = trim_selected_memory_subject_action_overlap(subject, action)
        .unwrap_or_else(|| normalize_prompt_text(subject));
    if subject.is_empty() {
        return None;
    }
    if prompt_fragments_substantially_overlap(&subject, action) {
        return None;
    }
    Some(subject)
}

fn compact_selected_memory_motion_style(action: &str, mood: &str) -> Option<String> {
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

fn compact_selected_memory_voice_style(action: &str, dialogue: &str, mood: &str) -> Option<String> {
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

fn compact_selected_memory_delivery_style(
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

fn compact_selected_memory_performance_style(
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

pub(crate) fn selected_memory_subject_identity(
    subject: &str,
    subject_refs: &str,
) -> Option<String> {
    selected_memory_subject_aliases(subject, subject_refs)
        .into_iter()
        .next()
}

pub(crate) fn selected_memory_subject_aliases(subject: &str, subject_refs: &str) -> Vec<String> {
    let mut aliases = Vec::new();
    let subject_hint =
        normalize_selected_memory_identity_candidate(&selected_memory_identity_source(subject));

    let refs = normalize_prompt_text(subject_refs);
    if !refs.is_empty() {
        for candidate in refs
            .split(['/', '／', '、', ',', '，'])
            .map(normalize_prompt_text)
            .filter(|value| !value.is_empty())
        {
            if let Some(identity) = normalize_selected_memory_identity_candidate_with_hint(
                &candidate,
                subject_hint.as_deref(),
            ) {
                aliases.push(identity);
            }
        }
    }

    if let Some(identity) = subject_hint {
        aliases.push(identity);
    }

    let mut deduped = Vec::new();
    for alias in aliases {
        if deduped.iter().any(|existing| existing == &alias) {
            continue;
        }
        deduped.push(alias);
    }
    let mut aliases = deduped;
    aliases.truncate(4);
    aliases
}

fn selected_memory_identity_source(candidate: &str) -> String {
    let normalized = normalize_prompt_text(candidate);
    if normalized.is_empty() {
        return normalized;
    }

    if let Some(role_prefix) = ACTION_SUBJECT_PREFIXES
        .iter()
        .find(|prefix| normalized.starts_with(**prefix))
    {
        let remainder = normalize_prompt_text(normalized.trim_start_matches(role_prefix));
        if generic_subject_role_is_followed_by_actionish_fragment(&remainder) {
            return (*role_prefix).to_string();
        }
    }

    let Some((split_idx, _)) = SUBJECT_IDENTITY_TAIL_MARKERS
        .iter()
        .filter_map(|marker| normalized.find(marker).map(|idx| (idx, *marker)))
        .min_by_key(|(idx, _)| *idx)
    else {
        return normalized;
    };
    let prefix = normalized[..split_idx].trim_end();
    if (2..=6).contains(&prefix.chars().count()) {
        prefix.to_string()
    } else {
        normalized
    }
}

fn generic_subject_role_is_followed_by_actionish_fragment(remainder: &str) -> bool {
    let remainder = normalize_prompt_text(remainder);
    !remainder.is_empty()
        && (GENERIC_SUBJECT_ACTION_LEADERS
            .iter()
            .any(|prefix| remainder.starts_with(prefix))
            || SUBJECT_IDENTITY_TAIL_MARKERS
                .iter()
                .any(|marker| remainder.starts_with(marker)))
}

fn normalize_selected_memory_identity_candidate(candidate: &str) -> Option<String> {
    normalize_selected_memory_identity_candidate_with_hint(candidate, None)
}

fn normalize_selected_memory_identity_candidate_with_hint(
    candidate: &str,
    subject_hint: Option<&str>,
) -> Option<String> {
    let normalized = normalize_prompt_text(candidate);
    if normalized.is_empty() {
        return None;
    }
    let normalized = selected_memory_identity_source(&normalized);
    if ACTION_SUBJECT_PREFIXES
        .iter()
        .any(|prefix| normalized == *prefix)
    {
        return Some(normalized);
    }

    let stripped = strip_selected_memory_subject_role_prefix(&normalized)
        .map(normalize_prompt_text)
        .unwrap_or(normalized);
    if stripped.is_empty()
        || ACTION_SUBJECT_PREFIXES
            .iter()
            .any(|prefix| stripped == *prefix)
        || selected_memory_identity_looks_like_non_character_fragment(&stripped, subject_hint)
    {
        return None;
    }
    let clipped = clip_prompt_fragment(&stripped, 12);
    (clipped.chars().count() >= 2).then_some(clipped)
}

fn selected_memory_identity_looks_like_non_character_fragment(
    candidate: &str,
    subject_hint: Option<&str>,
) -> bool {
    candidate.contains('的')
        || NON_CHARACTER_ALIAS_SUFFIXES
            .iter()
            .any(|suffix| candidate.ends_with(suffix))
        || subject_hint.is_some_and(|hint| {
            !hint.is_empty()
                && candidate != hint
                && !candidate.contains(hint)
                && !hint.contains(candidate)
                && NON_CHARACTER_ALIAS_SUFFIXES
                    .iter()
                    .any(|suffix| candidate.ends_with(suffix))
        })
}

fn compact_selected_memory_sound_style(sound: &str) -> Option<String> {
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

fn trim_selected_memory_subject_action_overlap(subject: &str, action: &str) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    let action = normalize_prompt_text(action);
    if subject.is_empty() || action.is_empty() {
        return None;
    }

    let Some(identity_tail) = strip_selected_memory_subject_role_prefix(&subject) else {
        return None;
    };
    if identity_tail.chars().count() < 3 {
        return None;
    }

    for overlap_len in (3..=identity_tail.chars().count().min(12)).rev() {
        let overlap = identity_tail.chars().take(overlap_len).collect::<String>();
        if !action.contains(&overlap) {
            continue;
        }
        let Some(trimmed) = subject.strip_suffix(&overlap) else {
            continue;
        };
        let trimmed = normalize_prompt_text(trimmed)
            .trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、')
            })
            .to_string();
        if trimmed.chars().count() < 2 || trimmed == subject {
            continue;
        }
        return Some(trimmed);
    }

    None
}

fn merge_selected_memory_subject_action(
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let subject = subject.map(normalize_prompt_text)?;
    let action = action.map(normalize_prompt_text)?;
    let simplified_subject = normalize_prompt_text(
        &subject
            .replace(['后', '又', '再', '便', '才'], "")
            .trim()
            .to_string(),
    );
    let simplified_action = normalize_prompt_text(
        &action
            .replace(['后', '又', '再', '便', '才'], "")
            .trim()
            .to_string(),
    );
    if subject.is_empty()
        || action.is_empty()
        || subject == action
        || (!simplified_subject.is_empty()
            && !simplified_action.is_empty()
            && simplified_subject.contains(&simplified_action))
        || subject.contains('在')
        || action.chars().count() < 4
    {
        return None;
    }

    let subject_chars = subject.chars().count();
    let action_chars = action.chars().count();
    let max_overlap = action_chars.min(4);
    for overlap_len in (2..=max_overlap).rev() {
        let overlap = action
            .chars()
            .rev()
            .take(overlap_len)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect::<String>();
        let Some(start) = subject.find(&overlap) else {
            continue;
        };
        if start == 0 {
            continue;
        }
        let end = start + overlap.len();
        let merged = format!("{}{}{}", &subject[..start], action, &subject[end..]);
        let merged = normalize_prompt_text(&merged);
        if merged == subject
            || merged == action
            || merged.chars().count() >= subject_chars + action_chars
            || merged.contains("，，")
        {
            continue;
        }
        return Some(merged);
    }

    None
}

fn compact_selected_memory_action(
    action: &str,
    subject: Option<&str>,
    subject_source: Option<&str>,
    subject_coverage: Option<&str>,
    setting: Option<&str>,
    mood: &str,
) -> Option<String> {
    let mut action = normalize_prompt_text(action);
    if action.is_empty() {
        return None;
    }

    if let Some(subject) = subject
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    {
        if action == subject {
            return None;
        }
        if let Some(stripped) = action.strip_prefix(&subject) {
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            });
            if stripped.chars().count() >= 2 {
                action = stripped.to_string();
            }
        }
        if let Some(prefix) = ACTION_SUBJECT_PREFIXES.iter().find(|prefix| {
            action.starts_with(**prefix)
                && (subject.starts_with(**prefix) || subject.contains(**prefix))
        }) {
            if let Some(stripped) = action.strip_prefix(prefix) {
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
                });
                if stripped.chars().count() >= 2 {
                    action = stripped.to_string();
                }
            }
        }
    }

    action = strip_selected_memory_action_subject_overlap(&action, subject_source);
    action = strip_selected_memory_action_object_prefix(&action, subject_coverage);
    action = strip_selected_memory_action_setting_prefix(&action, setting);

    if !normalize_prompt_text(mood).is_empty() {
        for prefix in ACTION_PACE_PREFIXES {
            if let Some(stripped) = action.strip_prefix(prefix) {
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace() || matches!(ch, '地' | '着' | ':' | '：' | ',' | '，' | '、')
                });
                if stripped.chars().count() >= 2 {
                    action = stripped.to_string();
                    break;
                }
            }
        }
    }

    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &action)) {
        return None;
    }
    Some(action)
}

fn strip_selected_memory_action_subject_overlap(
    action: &str,
    subject_source: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }

    let Some(subject_source) = subject_source
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return compacted;
    };
    let Some(subject_tail) = strip_selected_memory_subject_role_prefix(&subject_source)
        .map(normalize_prompt_text)
        .filter(|value| value.chars().count() >= 3)
    else {
        return compacted;
    };

    for overlap_len in (3..=subject_tail.chars().count().min(12)).rev() {
        let overlap = subject_tail.chars().take(overlap_len).collect::<String>();
        let Some(start) = compacted.find(&overlap) else {
            continue;
        };
        if start == 0 {
            continue;
        }
        let end = start + overlap.len();
        let prefix = compacted[..start].trim_end_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ',' | '，' | '、' | ';' | '；')
        });
        let suffix = compacted[end..].trim_start_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ',' | '，' | '、' | ';' | '；')
        });
        if prefix.chars().count() < 2 || suffix.chars().count() < 2 {
            continue;
        }
        if !matches!(
            suffix.chars().next(),
            Some('后' | '再' | '并' | '且' | '仍')
        ) {
            continue;
        }
        let merged = normalize_prompt_text(&format!("{prefix}{suffix}"));
        if merged.chars().count() < 4 || merged == compacted {
            continue;
        }
        compacted = merged;
        break;
    }

    compacted
}

fn strip_selected_memory_action_object_prefix(
    action: &str,
    subject_coverage: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }

    let mut coverage = subject_coverage
        .map(normalize_prompt_text)
        .unwrap_or_default()
        .split(['/', '／', '、', ',', '，'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &coverage {
            if candidate.chars().count() < 2 {
                continue;
            }
            for verb in ACTION_OBJECT_PREFIX_VERBS {
                let Some(stripped) = compacted.strip_prefix(verb) else {
                    continue;
                };
                let Some(stripped) = stripped.strip_prefix(candidate) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn strip_selected_memory_action_setting_prefix(action: &str, setting: Option<&str>) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = build_selected_memory_setting_prefix_candidates(setting);
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 4 {
                continue;
            }
            let Some(stripped) = strip_selected_memory_prefix_candidate(&compacted, candidate)
            else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn compact_selected_memory_setting(
    setting: &str,
    subject: Option<&str>,
    subject_coverage: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let mut setting = normalize_prompt_text(setting);
    if setting.is_empty() {
        return None;
    }

    setting = strip_selected_memory_setting_subject_prefix(&setting, subject_coverage);
    setting = strip_selected_memory_setting_context_prefix(&setting, subject, action);

    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
        || action.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
    {
        return None;
    }
    Some(setting)
}

fn strip_selected_memory_setting_subject_prefix(
    setting: &str,
    subject_coverage: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }

    let mut coverage = subject_coverage
        .map(normalize_prompt_text)
        .unwrap_or_default()
        .split(['/', '／', '、', ',', '，'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &coverage {
            if candidate.chars().count() < 2 || !compacted.starts_with(candidate) {
                continue;
            }
            let rest = compacted[candidate.len()..].trim_start();
            for suffix in SETTING_SUBJECT_LEAD_IN_SUFFIXES {
                let Some(stripped) = rest.strip_prefix(suffix) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn strip_selected_memory_setting_context_prefix(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> String {
    let compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }

    let Some(locative_lead_in) = selected_memory_setting_locative_lead_in(&compacted) else {
        return compacted;
    };
    if locative_lead_in.chars().count() < 4 {
        return compacted;
    }

    let covered_by_context = subject
        .into_iter()
        .chain(action)
        .map(selected_memory_context_variants)
        .flatten()
        .any(|candidate| candidate.starts_with(&locative_lead_in));
    if !covered_by_context {
        return compacted;
    }

    let Some((_, suffix)) = strip_selected_memory_setting_descriptive_lead_in(&compacted) else {
        return compacted;
    };
    let suffix = suffix.trim_start_matches(|ch: char| {
        ch.is_whitespace()
            || matches!(
                ch,
                '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
            )
    });
    if suffix.chars().count() < 2 {
        return compacted;
    }

    suffix.to_string()
}

fn build_selected_memory_setting_prefix_candidates(setting: Option<&str>) -> Vec<String> {
    let mut candidates = Vec::new();
    let Some(setting) = setting
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return candidates;
    };

    candidates.push(setting.clone());
    if let Some(stripped) = strip_selected_memory_leading_bridge(&setting) {
        candidates.push(stripped.to_string());
    }
    if let Some((prefix, _)) = strip_selected_memory_setting_descriptive_lead_in(&setting) {
        candidates.push(prefix.to_string());
        if let Some(stripped) = strip_selected_memory_leading_bridge(prefix) {
            candidates.push(stripped.to_string());
        }
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

fn selected_memory_setting_locative_lead_in(setting: &str) -> Option<String> {
    let normalized = normalize_prompt_text(setting);
    let (prefix, _) = strip_selected_memory_setting_descriptive_lead_in(&normalized)?;
    let prefix = strip_selected_memory_leading_bridge(prefix).unwrap_or(prefix);
    let prefix = normalize_prompt_text(prefix);
    (!prefix.is_empty()).then_some(prefix)
}

fn strip_selected_memory_setting_descriptive_lead_in(setting: &str) -> Option<(&str, &str)> {
    let normalized = setting.trim();
    let split_at = normalized.find('的')?;
    let (prefix, suffix_with_marker) = normalized.split_at(split_at);
    let suffix = suffix_with_marker.strip_prefix('的')?;
    let prefix = prefix.trim();
    let suffix = suffix.trim();
    (!prefix.is_empty() && !suffix.is_empty()).then_some((prefix, suffix))
}

fn selected_memory_context_variants(value: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(value);
    if normalized.is_empty() {
        return Vec::new();
    }

    let mut variants = vec![normalized.clone()];
    if let Some(stripped) = strip_selected_memory_subject_role_prefix(&normalized) {
        variants.push(stripped.to_string());
        if let Some(bridge) = strip_selected_memory_leading_bridge(stripped) {
            variants.push(bridge.to_string());
        }
    }
    if let Some(stripped) = strip_selected_memory_leading_bridge(&normalized) {
        variants.push(stripped.to_string());
    }
    variants.sort();
    variants.dedup();
    variants
}

fn strip_selected_memory_subject_role_prefix(value: &str) -> Option<&str> {
    ACTION_SUBJECT_PREFIXES.iter().find_map(|prefix| {
        value.strip_prefix(prefix).map(|stripped| {
            stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            })
        })
    })
}

fn strip_selected_memory_prefix_candidate<'a>(
    fragment: &'a str,
    candidate: &str,
) -> Option<&'a str> {
    fragment.strip_prefix(candidate).or_else(|| {
        strip_selected_memory_leading_bridge(fragment)
            .and_then(|value| value.strip_prefix(candidate))
    })
}

fn strip_selected_memory_leading_bridge(fragment: &str) -> Option<&str> {
    let trimmed = fragment.trim_start();
    PROMPT_LEADING_BRIDGES
        .into_iter()
        .find_map(|prefix| trimmed.strip_prefix(prefix))
}

fn prompt_fragments_substantially_overlap(lhs: &str, rhs: &str) -> bool {
    let lhs = normalize_prompt_text(lhs);
    let rhs = normalize_prompt_text(rhs);
    if lhs.is_empty() || rhs.is_empty() {
        return false;
    }
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
}

pub(crate) fn storyboard_prompt_seed(row: &StoryboardPromptSeedRow) -> Option<String> {
    let prompt = row
        .prompt
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let video_desc = row
        .video_desc
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let duration = row
        .duration
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let source = [prompt, video_desc, duration].join("\n");
    if source.trim().is_empty() {
        return None;
    }

    let mut hasher = Sha256::new();
    hasher.update(source.as_bytes());
    let hex = format!("{:x}", hasher.finalize());
    Some(hex[..12].to_string())
}

fn memory_matches_storyboard(content: &str, storyboard_numeric_id: i32) -> bool {
    extract_storyboard_ids(content).contains(&storyboard_numeric_id)
}

fn memory_matches_prompt_seed(content: &str, current_prompt_seed: Option<&str>) -> bool {
    match current_prompt_seed {
        Some(seed) if !seed.is_empty() => {
            extract_key_value(content, "promptSeed").as_deref() == Some(seed)
        }
        _ => true,
    }
}

fn memory_matches_prompt_seed_with_fallback(
    content: &str,
    current_prompt_seed: Option<&str>,
    allow_unseeded_fallback: bool,
) -> bool {
    if memory_matches_prompt_seed(content, current_prompt_seed) {
        return true;
    }
    allow_unseeded_fallback
        && matches!(current_prompt_seed, Some(seed) if !seed.is_empty())
        && extract_key_value(content, "promptSeed").is_none()
}

fn has_exact_prompt_seed_memory_match(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    names: &[&str],
) -> bool {
    matches!(current_prompt_seed, Some(seed) if !seed.is_empty())
        && rows.iter().any(|row| {
            names.iter().any(|name| row.name == *name)
                && memory_matches_storyboard(&row.content, storyboard_numeric_id)
                && memory_matches_prompt_seed(&row.content, current_prompt_seed)
        })
}

fn extract_storyboard_ids(content: &str) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split(',')
                .filter_map(|value| value.trim().parse::<i32>().ok())
                .filter(|value| *value > 0)
                .collect()
        })
        .unwrap_or_default()
}

fn storyboard_distance_from_memory_content(
    content: &str,
    storyboard_numeric_id: i32,
) -> Option<i32> {
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_storyboard_ids(content)
        .into_iter()
        .map(|id| (storyboard_numeric_id - id).abs())
        .min()
}

#[derive(Debug, Clone)]
struct StyleNoteSelectionContext {
    description: String,
    subject: String,
    action: String,
    shot: String,
    camera_move: String,
    mood: String,
    lighting: String,
    dialogue: String,
    sound: String,
}

#[derive(Debug, Clone)]
struct RankedStyleNote {
    note: String,
    context_note: String,
    score: i32,
    recency_idx: usize,
    source_name: String,
    storyboard_distance: Option<i32>,
    storyboard_focus: usize,
    subject_priority: usize,
}

fn build_style_note_selection_context(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> StyleNoteSelectionContext {
    let description = storyboard_row
        .and_then(|row| {
            row.video_desc
                .as_deref()
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .or_else(|| {
                    row.prompt
                        .as_deref()
                        .map(normalize_prompt_text)
                        .filter(|text| !text.is_empty())
                })
        })
        .unwrap_or_default();
    let fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    StyleNoteSelectionContext {
        description,
        subject: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.subject))
            .unwrap_or_default(),
        action: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.action))
            .unwrap_or_default(),
        shot: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.shot))
            .unwrap_or_default(),
        camera_move: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.camera_move))
            .unwrap_or_default(),
        mood: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.mood))
            .unwrap_or_default(),
        lighting: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.lighting))
            .unwrap_or_default(),
        dialogue: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.dialogue))
            .unwrap_or_default(),
        sound: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.sound))
            .unwrap_or_default(),
    }
}

fn collect_ranked_video_style_note_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    _current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
) -> Vec<RankedStyleNote> {
    let mut candidates = Vec::new();
    for (idx, row) in rows.iter().enumerate() {
        let (base_score, note, context_note) = match row.name.as_str() {
            SELECTED_VIDEO_MEMORY_NAME => {
                if !memory_row_is_neighbor_selected_style(row, storyboard_numeric_id) {
                    continue;
                }
                let note = extract_style_note_value(row);
                (120, note.clone(), note)
            }
            SCRIPT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (90, note.clone(), note)
            }
            SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                102,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            PROJECT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (70, note.clone(), note)
            }
            PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                82,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            _ => continue,
        };
        let Some(note) = note else {
            continue;
        };
        let context_note = context_note.unwrap_or_else(|| note.clone());
        let sample_count = extract_key_value(&row.content, "sampleCount")
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(1)
            .clamp(1, 8);
        candidates.push(RankedStyleNote {
            note,
            context_note,
            score: base_score + sample_count * 4,
            recency_idx: idx,
            source_name: row.name.clone(),
            storyboard_distance: (row.name == SELECTED_VIDEO_MEMORY_NAME)
                .then(|| {
                    storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                })
                .flatten(),
            storyboard_focus: role_style_storyboard_focus_score(&row.content, storyboard_row),
            subject_priority: memory_subject_match_priority(&row.content, subject_candidates),
        });
    }
    candidates
}

fn memory_row_is_neighbor_selected_style(row: &AgentMemoryRow, storyboard_numeric_id: i32) -> bool {
    let storyboard_ids = extract_storyboard_ids(&row.content);
    !storyboard_ids.is_empty() && !storyboard_ids.contains(&storyboard_numeric_id)
}

fn extract_style_note_value(row: &AgentMemoryRow) -> Option<String> {
    selected_video_style_value_from_content(&row.content)
}

fn selected_video_style_value_from_content(content: &str) -> Option<String> {
    if let Some(value) = extract_key_value(content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(content, "note")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

fn score_ranked_style_note(note: &RankedStyleNote, context: &StyleNoteSelectionContext) -> i32 {
    let mut score = note.score;
    if note.source_name == SELECTED_VIDEO_MEMORY_NAME {
        score -= neighbor_selected_style_distance_penalty(note.storyboard_distance);
        score -= neighbor_selected_character_state_mismatch_penalty(note, context);
    }
    let fragments = split_prompt_note_fragments(&note.note)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    for fragment in fragments {
        if fragment.is_empty() {
            continue;
        }
        if note.source_name == SELECTED_VIDEO_MEMORY_NAME
            && fragment.starts_with("镜头")
            && local_shot_framing_fragment(&fragment)
        {
            score -= 18;
        }
        if !context.mood.is_empty()
            && fragment.starts_with("情绪")
            && fragment.contains(&context.mood)
        {
            score += 24;
        }
        if !context.lighting.is_empty()
            && fragment.starts_with("光影")
            && fragment.contains(&context.lighting)
        {
            score += 24;
        }
        if fragment.starts_with("镜头")
            && ((!context.shot.is_empty() && fragment.contains(&context.shot))
                || (!context.camera_move.is_empty() && fragment.contains(&context.camera_move)))
        {
            score += 24;
        }
        if !context.subject.is_empty() && fragment.contains(&context.subject) {
            score += 18;
        }
        if !context.action.is_empty() && fragment.contains(&context.action) {
            score += 14;
        }
        if !context.description.is_empty() && context.description.contains(&fragment) {
            score += 12;
        }
    }
    score
}

fn neighbor_selected_style_distance_penalty(distance: Option<i32>) -> i32 {
    match distance.unwrap_or(2) {
        i32::MIN..=1 => 10,
        2 => 16,
        3 => 22,
        _ => 28,
    }
}

fn neighbor_selected_character_state_mismatch_penalty(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> i32 {
    let mut penalty = 0;
    if selected_voice_family_conflicts_with_context(&note.note, context) {
        penalty += if current_context_voice_family(context) == Some("fragile") {
            34
        } else {
            18
        };
    }
    if selected_generic_restrained_mood_lags_fragile_scene(&note.note, context) {
        penalty += 8;
    }
    penalty
}

fn selected_voice_family_conflicts_with_context(
    note: &str,
    context: &StyleNoteSelectionContext,
) -> bool {
    let Some(note_family) = style_voice_family(note) else {
        return false;
    };
    let context_voice = current_context_voice_family(context);
    matches!(context_voice, Some(context_family) if context_family != note_family)
}

fn current_context_voice_family(context: &StyleNoteSelectionContext) -> Option<&'static str> {
    [context.dialogue.as_str(), context.action.as_str()]
        .into_iter()
        .find_map(style_voice_family)
}

fn context_is_fragile_voice_turn(context: &StyleNoteSelectionContext) -> bool {
    current_context_voice_family(context) == Some("fragile")
        || [
            context.dialogue.as_str(),
            context.action.as_str(),
            context.mood.as_str(),
        ]
        .into_iter()
        .any(|field| {
            [
                "哽咽", "失声", "哑声", "发颤", "颤声", "鼻音", "抽气", "含泪", "哭",
            ]
            .iter()
            .any(|keyword| field.contains(keyword))
        })
}

fn style_voice_family(text: &str) -> Option<&'static str> {
    [
        ("哽咽", "fragile"),
        ("发哽", "fragile"),
        ("失声", "fragile"),
        ("哑声", "fragile"),
        ("颤声", "fragile"),
        ("鼻音", "fragile"),
        ("抽气", "fragile"),
        ("发颤", "fragile"),
        ("低声", "low"),
        ("压低", "low"),
        ("轻声", "light"),
        ("轻轻", "light"),
        ("呢喃", "murmur"),
        ("喃喃", "murmur"),
        ("耳语", "murmur"),
        ("短促", "clipped"),
        ("急促", "clipped"),
    ]
    .into_iter()
    .find_map(|(keyword, family)| text.contains(keyword).then_some(family))
}

fn selected_generic_restrained_mood_lags_fragile_scene(
    note: &str,
    context: &StyleNoteSelectionContext,
) -> bool {
    note.contains("情绪克制")
        && [
            context.dialogue.as_str(),
            context.action.as_str(),
            context.mood.as_str(),
        ]
        .into_iter()
        .any(|field| {
            ["哽咽", "泪", "发颤", "哭", "失声", "哑声", "鼻音", "抽气"]
                .iter()
                .any(|keyword| field.contains(keyword))
        })
        && !note.contains("哽咽")
        && !note.contains("发颤")
}

fn ranked_style_note_is_worth_recalling(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> bool {
    if style_note_selection_context_is_empty(context) {
        return true;
    }

    let evidence = score_style_note_context_evidence(note, context);
    match note.source_name.as_str() {
        SELECTED_VIDEO_MEMORY_NAME => evidence >= 1,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME => evidence >= 2,
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => evidence >= 1,
        PROJECT_VIDEO_STYLE_MEMORY_NAME => evidence >= 3,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => evidence >= 2,
        _ => false,
    }
}

fn style_note_selection_context_is_empty(context: &StyleNoteSelectionContext) -> bool {
    [
        context.description.as_str(),
        context.subject.as_str(),
        context.action.as_str(),
        context.shot.as_str(),
        context.camera_move.as_str(),
        context.mood.as_str(),
        context.lighting.as_str(),
    ]
    .into_iter()
    .all(|value| value.is_empty())
}

fn score_style_note_context_evidence(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> usize {
    let mut evidence = 0usize;
    let fragments = split_prompt_note_fragments(&note.context_note)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();

    if fragments.iter().any(|fragment| {
        fragment.starts_with("情绪") && !context.mood.is_empty() && fragment.contains(&context.mood)
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("光影")
            && !context.lighting.is_empty()
            && fragment.contains(&context.lighting)
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("镜头")
            && ((!context.shot.is_empty() && fragment.contains(&context.shot))
                || (!context.camera_move.is_empty() && fragment.contains(&context.camera_move)))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("语气")
            && ((!context.dialogue.is_empty()
                && context
                    .dialogue
                    .contains(fragment.trim_start_matches("语气")))
                || (!context.mood.is_empty() && fragment.contains(&context.mood))
                || (context_is_fragile_voice_turn(context)
                    && style_voice_family(fragment) == Some("fragile")))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("声场")
            && ((!context.sound.is_empty()
                && context.sound.contains(fragment.trim_start_matches("声场")))
                || (!context.description.is_empty()
                    && context
                        .description
                        .contains(fragment.trim_start_matches("声场"))))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            && ((!context.action.is_empty()
                && context.action.contains(fragment.trim_start_matches("表演")))
                || (!context.dialogue.is_empty()
                    && context
                        .dialogue
                        .contains(fragment.trim_start_matches("表演")))
                || (!context.mood.is_empty() && fragment.contains(&context.mood))
                || (context_is_fragile_voice_turn(context) && fragment.contains("呼吸发颤")))
    }) {
        evidence += 2;
    }
    if !context.subject.is_empty()
        && fragments
            .iter()
            .any(|fragment| fragment.contains(&context.subject))
    {
        evidence += 1;
    }
    if !context.action.is_empty()
        && fragments
            .iter()
            .any(|fragment| fragment.contains(&context.action))
    {
        evidence += 1;
    }
    if !context.description.is_empty()
        && fragments
            .iter()
            .any(|fragment| context.description.contains(fragment))
    {
        evidence += 1;
    }

    evidence
}

fn local_shot_framing_fragment(fragment: &str) -> bool {
    ["低机位", "高机位", "特写", "近景", "中景", "全景", "远景"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

fn build_script_video_style_memory(rows: &[AgentMemoryRow]) -> Option<String> {
    let notes = distinct_selected_video_style_notes(rows);
    if notes.len() < 2 {
        return None;
    }
    let distinct_subject_group_count =
        distinct_selected_video_subject_group_count(rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }));

    let mut recurring = compact_global_recurring_style_fragments(
        recurring_style_fragments(&notes),
        distinct_subject_group_count,
    );
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    if recurring.is_empty() {
        return None;
    }
    let delivery = (distinct_subject_group_count <= 1)
        .then(|| summarize_role_delivery_fragment(&notes))
        .flatten()
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS));
    let style_fragments = compact_global_visual_style_fragments(&recurring, delivery.as_deref());
    let style = clip_prompt_fragment(
        &style_fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    );
    let mut parts = vec![
        format!("sampleCount={}", notes.len()),
        format!("style={style}"),
    ];
    if let Some(delivery) = delivery.filter(|value| value != &style) {
        parts.push(format!("delivery={delivery}"));
    }
    Some(parts.join(" | "))
}

fn build_project_video_style_memory(rows: &[ScopedAgentMemoryRow]) -> Option<String> {
    let notes = distinct_project_selected_video_style_notes(rows);
    if notes.len() < 3 {
        return None;
    }
    let distinct_subject_group_count =
        distinct_selected_video_subject_group_count(rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }));

    let mut recurring = compact_global_recurring_style_fragments(
        recurring_style_fragments(&notes),
        distinct_subject_group_count,
    );
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    if recurring.is_empty() {
        return None;
    }
    let delivery = (distinct_subject_group_count <= 1)
        .then(|| summarize_role_delivery_fragment(&notes))
        .flatten()
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS));
    let style_fragments = compact_global_visual_style_fragments(&recurring, delivery.as_deref());
    let style = clip_prompt_fragment(
        &style_fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    );
    let mut parts = vec![
        format!("sampleCount={}", notes.len()),
        format!("style={style}"),
    ];
    if let Some(delivery) = delivery.filter(|value| value != &style) {
        parts.push(format!("delivery={delivery}"));
    }
    Some(parts.join(" | "))
}

fn build_script_role_video_style_memories(rows: &[AgentMemoryRow]) -> Vec<String> {
    build_role_video_style_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds")
                .map(|storyboard_id| format!("script:{storyboard_id}")),
            None,
        )
    }))
}

fn build_project_role_video_style_memories(rows: &[ScopedAgentMemoryRow]) -> Vec<String> {
    build_role_video_style_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                format!(
                    "{}:{storyboard_id}",
                    row.episodes_id
                        .map(|value| value.to_string())
                        .unwrap_or_else(|| "project".to_string())
                )
            }),
            row.episodes_id.map(|value| value.to_string()),
        )
    }))
}

fn build_script_video_observation_memory(rows: &[AgentMemoryRow]) -> Option<String> {
    build_video_observation_memory(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }),
        None,
    )
}

fn build_project_video_observation_memory(rows: &[ScopedAgentMemoryRow]) -> Option<String> {
    build_video_observation_memory(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }),
        Some(PROJECT_VIDEO_OBSERVATION_MEMORY_MAX_SAMPLES_PER_SCRIPT),
    )
}

fn build_script_role_video_observation_memories(rows: &[AgentMemoryRow]) -> Vec<String> {
    build_role_video_observation_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds")
                .map(|storyboard_id| format!("script:{storyboard_id}")),
            None,
        )
    }))
}

fn build_project_role_video_observation_memories(rows: &[ScopedAgentMemoryRow]) -> Vec<String> {
    build_role_video_observation_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                format!(
                    "{}:{storyboard_id}",
                    row.episodes_id
                        .map(|value| value.to_string())
                        .unwrap_or_else(|| "project".to_string())
                )
            }),
            row.episodes_id.map(|value| value.to_string()),
        )
    }))
}

fn build_video_observation_memory<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
) -> Option<String> {
    let samples = distinct_rejected_video_observation_samples(rows, max_samples_per_scope);
    if samples.len() < 2 {
        return None;
    }

    let fragments = summarize_observation_fragments(
        samples.iter().map(|sample| sample.avoid.as_str()),
        REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT,
    );
    if fragments.is_empty() {
        return None;
    }

    let risk_tags = summarize_observation_risk_tags(&samples);
    let mut parts = vec![format!("sampleCount={}", samples.len())];
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn build_role_video_observation_memories<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> Vec<String> {
    #[derive(Default)]
    struct RoleObservationGroup {
        primary_subject: String,
        aliases: Vec<String>,
        samples: Vec<RejectedObservationSample>,
    }

    let mut grouped = Vec::<RoleObservationGroup>::new();
    for sample in distinct_rejected_video_observation_samples(rows, None) {
        if sample.subject.is_empty() || sample.subject_aliases.is_empty() {
            continue;
        }
        if let Some(existing) = grouped.iter_mut().find(|group| {
            group.aliases.iter().any(|alias| {
                sample
                    .subject_aliases
                    .iter()
                    .any(|candidate| candidate == alias)
            })
        }) {
            if existing.primary_subject.is_empty() {
                existing.primary_subject = sample.subject.clone();
            }
            existing.aliases.extend(sample.subject_aliases.clone());
            existing.aliases.sort();
            existing.aliases.dedup();
            existing.samples.push(sample);
            continue;
        }

        grouped.push(RoleObservationGroup {
            primary_subject: sample.subject.clone(),
            aliases: sample.subject_aliases.clone(),
            samples: vec![sample],
        });
    }

    grouped
        .into_iter()
        .filter_map(|group| {
            if group.samples.len() < 2 {
                return None;
            }
            let fragments = summarize_observation_fragments(
                group.samples.iter().map(|sample| sample.avoid.as_str()),
                REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT,
            );
            if fragments.is_empty() {
                return None;
            }
            let risk_tags = summarize_observation_risk_tags(&group.samples);
            let primary_subject = clip_prompt_fragment(&group.primary_subject, 16);
            let subject_aliases = group
                .aliases
                .into_iter()
                .filter(|alias| alias != &group.primary_subject)
                .collect::<Vec<_>>();
            let mut parts = vec![
                format!("subject={primary_subject}"),
                format!("sampleCount={}", group.samples.len()),
            ];
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
            if !risk_tags.is_empty() {
                parts.push(format!("riskTags={}", risk_tags.join("/")));
            }
            parts.push(format!("avoid={}", fragments.join(", ")));
            Some(parts.join(" | "))
        })
        .collect()
}

#[derive(Debug, Clone)]
struct RejectedObservationSample {
    subject: String,
    subject_aliases: Vec<String>,
    avoid: String,
    risk_tags: Vec<String>,
}

fn distinct_rejected_video_observation_samples<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
) -> Vec<RejectedObservationSample> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut scope_counts = Vec::<(String, usize)>::new();
    let mut samples = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != REJECTED_VIDEO_NEGATIVE_MEMORY_NAME
            || rejected_video_negative_rejection_count(content)
                < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        {
            continue;
        }
        let Some(avoid) = extract_key_value(content, "avoid")
            .map(|value| compact_rejected_negative_avoid(&value))
        else {
            continue;
        };
        if avoid.is_empty() {
            continue;
        }

        if let Some(storyboard_key) = scoped_storyboard_key {
            if storyboard_keys
                .iter()
                .any(|existing| existing == &storyboard_key)
            {
                continue;
            }
            storyboard_keys.push(storyboard_key);
        } else {
            let prompt_seed = extract_key_value(content, "promptSeed").unwrap_or_default();
            let scope_key = scope_key.unwrap_or_else(|| "script".to_string());
            let sample_key = if prompt_seed.is_empty() {
                format!("{scope_key}|{avoid}")
            } else {
                format!("{scope_key}|{prompt_seed}")
            };
            if sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            if let Some(limit) = max_samples_per_scope {
                let count = scope_counts
                    .iter_mut()
                    .find(|(existing_scope, _)| existing_scope == &scope_key);
                match count {
                    Some((_, count)) if *count >= limit => continue,
                    Some((_, count)) => *count += 1,
                    None => scope_counts.push((scope_key.clone(), 1)),
                }
            }
            sample_keys.push(sample_key);
        }

        let subject = extract_key_value(content, "subject")
            .map(|value| normalize_prompt_text(&value))
            .unwrap_or_default();
        samples.push(RejectedObservationSample {
            subject,
            subject_aliases: role_memory_subject_candidates(content),
            avoid,
            risk_tags: extract_rejected_video_risk_tags(content),
        });
    }

    samples
}

fn summarize_observation_fragments<'a>(
    avoids: impl Iterator<Item = &'a str>,
    limit: usize,
) -> Vec<String> {
    let mut counts = Vec::<(String, usize, i32)>::new();
    for avoid in avoids {
        let mut seen = Vec::<String>::new();
        for fragment in ranked_rejected_negative_fragments(avoid) {
            if seen.iter().any(|existing| existing == &fragment) {
                continue;
            }
            seen.push(fragment.clone());
            if let Some((_, count, _)) = counts
                .iter_mut()
                .find(|(existing, _, _)| existing == &fragment)
            {
                *count += 1;
            } else {
                counts.push((
                    fragment.clone(),
                    1,
                    score_rejected_negative_fragment(&fragment),
                ));
            }
        }
    }
    counts.sort_by(|a, b| b.1.cmp(&a.1).then(b.2.cmp(&a.2)).then(a.0.cmp(&b.0)));

    let mut selected = Vec::new();
    for (fragment, count, _) in counts {
        if count < 2 {
            continue;
        }
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= limit {
            break;
        }
    }
    selected
}

fn summarize_observation_risk_tags(samples: &[RejectedObservationSample]) -> Vec<String> {
    let mut counts = Vec::<(String, usize)>::new();
    for sample in samples {
        let mut seen = Vec::<String>::new();
        for tag in &sample.risk_tags {
            if seen.iter().any(|existing| existing == tag) {
                continue;
            }
            seen.push(tag.clone());
            if let Some((_, count)) = counts.iter_mut().find(|(existing, _)| existing == tag) {
                *count += 1;
            } else {
                counts.push((tag.clone(), 1));
            }
        }
    }
    counts.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    counts
        .into_iter()
        .filter(|(_, count)| *count >= 2)
        .map(|(tag, _)| tag)
        .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn build_role_video_style_memories<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> Vec<String> {
    #[derive(Default)]
    struct RoleStyleGroup {
        primary_subject: String,
        aliases: Vec<String>,
        notes: Vec<String>,
    }

    let mut grouped = Vec::<RoleStyleGroup>::new();
    for (subject, aliases, note) in distinct_selected_video_style_notes_with_subject(rows) {
        if let Some(existing) = grouped.iter_mut().find(|group| {
            group
                .aliases
                .iter()
                .any(|alias| aliases.iter().any(|candidate| candidate == alias))
        }) {
            if existing.primary_subject.is_empty() {
                existing.primary_subject = subject.clone();
            }
            existing.aliases.extend(aliases);
            existing.aliases.sort();
            existing.aliases.dedup();
            existing.notes.push(note);
            continue;
        }

        grouped.push(RoleStyleGroup {
            primary_subject: subject,
            aliases,
            notes: vec![note],
        });
    }

    grouped
        .into_iter()
        .filter_map(|group| {
            if group.notes.len() < 2 {
                return None;
            }
            let recurring = compact_role_recurring_style_fragments(
                recurring_style_fragments(&group.notes),
                role_style_supplement_fragments(&group.notes),
            );
            if recurring.is_empty() {
                return None;
            }
            let style =
                clip_prompt_fragment(&recurring.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            let delivery = summarize_role_delivery_fragment(&group.notes)
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .filter(|value| value != &style);
            let primary_subject = clip_prompt_fragment(&group.primary_subject, 16);
            let subject_aliases = group
                .aliases
                .iter()
                .filter(|alias| **alias != group.primary_subject)
                .cloned()
                .collect::<Vec<_>>();
            let mut parts = vec![
                format!("subject={primary_subject}"),
                format!("sampleCount={}", group.notes.len()),
            ];
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
            parts.push(format!("style={style}"));
            if let Some(delivery) = delivery {
                parts.push(format!("delivery={delivery}"));
            }
            Some(parts.join(" | "))
        })
        .collect()
}

fn compact_global_recurring_style_fragments(
    fragments: Vec<String>,
    distinct_subject_group_count: usize,
) -> Vec<String> {
    if distinct_subject_group_count < 2 {
        return fragments;
    }

    fragments
        .into_iter()
        .filter(|fragment| {
            !fragment.starts_with("表演")
                && !fragment.starts_with("语气")
                && !fragment.starts_with("声场")
        })
        .collect()
}

fn compact_global_character_style_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_visual_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("镜头")
    });
    if has_performance_signal {
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !global_voice_fragment_is_low_gain_carryover(&voice);
            }
            if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
                return !global_mood_fragment_is_generic_restrained(&mood);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !global_motion_fragment_is_low_gain_carryover(&action);
            }
            if has_visual_signal {
                if let Some(sound) = fragment.strip_prefix("声场").map(normalize_prompt_text) {
                    return !global_sound_fragment_is_low_gain_ambience(&sound);
                }
            }
            true
        });
    }
}

fn compact_global_visual_style_fragments(
    fragments: &[String],
    delivery: Option<&str>,
) -> Vec<String> {
    if delivery.is_none() {
        return fragments.to_vec();
    }

    let filtered = fragments
        .iter()
        .filter(|fragment| {
            !fragment.starts_with("表演")
                && !fragment.starts_with("语气")
                && !fragment.starts_with("声场")
                && !(fragment.starts_with("情绪")
                    && fragment
                        .strip_prefix("情绪")
                        .map(normalize_prompt_text)
                        .is_some_and(|mood| {
                            selected_style_fragment_is_generic_restrained_mood(&mood)
                        }))
                && !(fragment.starts_with("动作")
                    && fragment
                        .strip_prefix("动作")
                        .map(normalize_prompt_text)
                        .is_some_and(|action| selected_style_fragment_is_low_gain_motion(&action)))
        })
        .cloned()
        .collect::<Vec<_>>();

    if filtered.is_empty() {
        fragments.to_vec()
    } else {
        filtered
    }
}

fn global_voice_fragment_is_low_gain_carryover(voice: &str) -> bool {
    matches!(voice, "低声克制" | "轻声克制" | "呢喃")
}

fn global_mood_fragment_is_generic_restrained(mood: &str) -> bool {
    matches!(mood, "克制" | "隐忍" | "压抑" | "沉静" | "冷静")
}

fn global_motion_fragment_is_low_gain_carryover(action: &str) -> bool {
    matches!(action, "从容克制" | "克制自然" | "自然" | "简洁平滑")
}

fn global_sound_fragment_is_low_gain_ambience(sound: &str) -> bool {
    matches!(sound, "雨声回响" | "风声回荡" | "车流闷响" | "水滴回声")
}

fn distinct_selected_video_subject_group_count<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> usize {
    let mut groups = Vec::<Vec<String>>::new();
    for (_, aliases, _) in distinct_selected_video_style_notes_with_subject(rows) {
        if groups.iter().any(|existing| {
            existing
                .iter()
                .any(|alias| aliases.iter().any(|candidate| candidate == alias))
        }) {
            continue;
        }
        groups.push(aliases);
    }
    groups.len()
}

fn compact_role_recurring_style_fragments(
    fragments: Vec<String>,
    supplements: Vec<String>,
) -> Vec<String> {
    let mut combined = Vec::new();
    for fragment in fragments.into_iter().chain(supplements) {
        if combined.iter().any(|existing| existing == &fragment) {
            continue;
        }
        combined.push(fragment);
    }
    if combined.is_empty() {
        return combined;
    }

    let has_character_signal = combined
        .iter()
        .any(|fragment| role_memory_fragment_is_character_signal(fragment));
    if !has_character_signal {
        return Vec::new();
    }

    let mut filtered = combined
        .into_iter()
        .filter(|fragment| !fragment.starts_with("镜头"))
        .collect::<Vec<_>>();
    compact_role_character_mood_redundancy(&mut filtered);
    filtered
}

fn role_memory_fragment_is_character_signal(fragment: &str) -> bool {
    ["动作", "表演", "语气", "情绪"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

fn role_style_supplement_fragments(notes: &[String]) -> Vec<String> {
    summarize_role_voice_fragment(notes).into_iter().collect()
}

fn summarize_role_delivery_fragment(notes: &[String]) -> Option<String> {
    let recurring_performance = summarize_recurring_role_performance_fragment(notes);
    let recurring_voice = summarize_role_voice_fragment(notes);

    match (recurring_performance.as_deref(), recurring_voice.as_deref()) {
        (Some(performance), Some(voice)) => {
            compact_selected_memory_delivery_style(Some(performance), Some(voice))
                .or(recurring_performance)
                .or(recurring_voice)
        }
        (Some(_), None) => recurring_performance,
        (None, Some(_)) => recurring_voice,
        (None, None) => None,
    }
}

fn summarize_role_voice_fragment(notes: &[String]) -> Option<String> {
    let recurring_performance = summarize_recurring_role_performance_fragment(notes);
    let mut variants = Vec::<(&str, usize)>::new();

    for note in notes {
        for fragment in split_prompt_note_fragments(note) {
            if !fragment.starts_with("语气") {
                continue;
            }
            if let Some(variant) = summarize_role_voice_variant(&fragment) {
                if let Some((_, count)) = variants
                    .iter_mut()
                    .find(|(existing, _)| *existing == variant)
                {
                    *count += 1;
                } else {
                    variants.push((variant, 1));
                }
            }
        }
    }

    let total_support = variants.iter().map(|(_, count)| *count).sum::<usize>();
    if total_support < 2 {
        return None;
    }

    variants.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then_with(|| role_voice_variant_priority(a.0).cmp(&role_voice_variant_priority(b.0)))
    });
    let best = variants.first()?.0;
    if recurring_performance.is_some() && role_voice_variant_is_low_gain_carryover(best) {
        return None;
    }
    Some(format!("语气{best}"))
}

fn summarize_recurring_role_performance_fragment(notes: &[String]) -> Option<String> {
    let parsed = notes
        .iter()
        .map(|note| split_prompt_note_fragments(note).collect::<Vec<_>>())
        .collect::<Vec<_>>();
    summarize_recurring_prefixed_fragment(&parsed, "表演")
}

fn role_voice_variant_is_low_gain_carryover(variant: &str) -> bool {
    matches!(variant, "低声克制" | "轻声克制" | "呢喃")
}

fn summarize_role_voice_variant(fragment: &str) -> Option<&'static str> {
    if fragment.contains("压低气息尾音发颤") {
        return Some("压低气息尾音发颤");
    }
    if fragment.contains("低声尾音发颤") || (fragment.contains("低声") && fragment.contains("尾音"))
    {
        return Some("低声尾音发颤");
    }
    if fragment.contains("轻声尾音发颤") || (fragment.contains("轻声") && fragment.contains("尾音"))
    {
        return Some("轻声尾音发颤");
    }
    if fragment.contains("哽咽克制") || fragment.contains("哽咽") {
        return Some("哽咽克制");
    }
    if fragment.contains("低声克制") || fragment.contains("低声") {
        return Some("低声克制");
    }
    if fragment.contains("轻声克制") || fragment.contains("轻声") {
        return Some("轻声克制");
    }
    if fragment.contains("呢喃克制") || fragment.contains("呢喃") {
        return Some("呢喃");
    }
    if fragment.contains("短促") {
        return Some("短促");
    }
    None
}

fn role_voice_variant_priority(variant: &str) -> usize {
    match variant {
        "压低气息尾音发颤" => 0,
        "低声尾音发颤" => 1,
        "轻声尾音发颤" => 2,
        "哽咽克制" => 3,
        "低声克制" => 4,
        "轻声克制" => 5,
        "呢喃" => 6,
        "短促" => 7,
        _ => usize::MAX,
    }
}

fn compact_role_character_mood_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let has_character_performance_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演") || fragment.starts_with("语气") || fragment.starts_with("动作")
    });
    if !has_character_performance_signal {
        return;
    }

    fragments.retain(|fragment| {
        let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
            return true;
        };
        !matches!(mood.as_str(), "克制" | "隐忍" | "压抑" | "沉静" | "冷静")
    });
}

fn distinct_selected_video_style_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    distinct_selected_video_style_notes_by_scope(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }),
        None,
    )
}

fn distinct_project_selected_video_style_notes(rows: &[ScopedAgentMemoryRow]) -> Vec<String> {
    distinct_selected_video_style_notes_by_scope(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }),
        Some(PROJECT_VIDEO_STYLE_MEMORY_MAX_SAMPLES_PER_SCRIPT),
    )
}

fn distinct_selected_video_style_notes_with_subject<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> Vec<(String, Vec<String>, String)> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut notes = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        let Some(subject) = extract_key_value(content, "subject")
            .map(|value| normalize_prompt_text(&value))
            .filter(|value| !value.is_empty())
        else {
            continue;
        };
        let aliases = role_memory_subject_candidates(content);
        let Some(note) = selected_video_style_value_from_content(content) else {
            continue;
        };
        if let Some(storyboard_key) = scoped_storyboard_key {
            let dedupe_key = format!("{subject}|{storyboard_key}");
            if storyboard_keys
                .iter()
                .any(|existing| existing == &dedupe_key)
            {
                continue;
            }
            storyboard_keys.push(dedupe_key);
        } else {
            let prompt_seed = extract_key_value(content, "promptSeed").unwrap_or_default();
            let sample_key = format!(
                "{}|{}|{}",
                subject,
                scope_key.unwrap_or_else(|| "script".to_string()),
                if prompt_seed.is_empty() {
                    note.clone()
                } else {
                    prompt_seed
                }
            );
            if sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            sample_keys.push(sample_key);
        }
        notes.push((subject, aliases, note));
    }

    notes
}

fn role_memory_subject_candidates(content: &str) -> Vec<String> {
    let mut subjects = Vec::new();
    if let Some(subject) = extract_key_value(content, "subject")
        .map(|value| normalize_prompt_text(&value))
        .filter(|value| !value.is_empty())
    {
        subjects.push(subject);
    }
    if let Some(aliases) = extract_key_value(content, "subjectAliases") {
        subjects.extend(
            aliases
                .split(['/', '／', '、', ',', '，'])
                .map(normalize_prompt_text)
                .filter(|value| !value.is_empty()),
        );
    }
    subjects.sort();
    subjects.dedup();
    subjects
}

fn distinct_selected_video_style_notes_by_scope<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
) -> Vec<String> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut scope_counts = Vec::<(String, usize)>::new();
    let mut notes = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        let Some(note) = selected_video_style_value_from_content(content) else {
            continue;
        };
        if let Some(storyboard_key) = scoped_storyboard_key {
            if storyboard_keys
                .iter()
                .any(|existing| existing == &storyboard_key)
            {
                continue;
            }
            storyboard_keys.push(storyboard_key);
        } else {
            let prompt_seed = extract_key_value(content, "promptSeed").unwrap_or_default();
            let sample_key = prompt_seed;
            if sample_key.is_empty() || sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            sample_keys.push(sample_key);
        }
        if let (Some(scope_key), Some(limit)) = (scope_key, max_samples_per_scope) {
            if let Some((_, count)) = scope_counts.iter_mut().find(|(key, _)| key == &scope_key) {
                if *count >= limit {
                    continue;
                }
                *count += 1;
            } else {
                scope_counts.push((scope_key, 1));
            }
        }
        notes.push(note);
    }

    notes
}

fn recurring_style_fragments(notes: &[String]) -> Vec<String> {
    let parsed = notes
        .iter()
        .map(|note| split_prompt_note_fragments(note).collect::<Vec<_>>())
        .collect::<Vec<_>>();
    let mut recurring = Vec::new();

    for prefix in STYLE_PROMPT_PREFIXES {
        if let Some(fragment) = summarize_recurring_prefixed_fragment(&parsed, prefix) {
            recurring.push(fragment);
        }
    }

    recurring
}

pub(crate) fn compact_video_style_prompt_note(note: &str) -> Option<String> {
    let mut fragments = Vec::new();
    let mut fallback_shot = None;

    for fragment in split_prompt_note_fragments(note) {
        if let Some(compacted) = compact_prompt_style_fragment(&fragment) {
            if fragments.iter().any(|existing| existing == &compacted) {
                continue;
            }
            fragments.push(compacted);
        } else if fragment.starts_with("镜头") && fallback_shot.is_none() {
            fallback_shot = Some(clip_prompt_fragment(
                &fragment,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
        }
    }

    compact_cross_fragment_style_redundancy(&mut fragments);

    if fragments.is_empty() {
        return fallback_shot;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_prompt_style_fragment(fragment: &str) -> Option<String> {
    if fragment.starts_with("镜头") {
        return compact_prompt_shot_style_fragment(fragment);
    }
    if fragment.starts_with("情绪") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "情绪",
            &MOOD_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("光影") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "光影",
            &LIGHTING_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("动作") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "动作",
            &MOTION_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("表演") {
        if performance_fragment_contains_voice_delivery(fragment) {
            return Some(clip_prompt_fragment(
                fragment,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
        }
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "表演",
            &PERFORMANCE_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("环境") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "环境",
            &ENVIRONMENT_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("语气") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "语气",
            &VOICE_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("声场") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "声场",
            &SOUND_STAGE_STYLE_KEYWORDS,
        ));
    }
    None
}

fn performance_fragment_contains_voice_delivery(fragment: &str) -> bool {
    fragment.starts_with("表演")
        && PERFORMANCE_STYLE_KEYWORDS
            .iter()
            .any(|keyword| fragment.contains(keyword))
        && VOICE_STYLE_KEYWORDS
            .iter()
            .any(|keyword| fragment.contains(keyword))
}

fn compact_cross_fragment_style_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let lighting_fragments = fragments
        .iter()
        .filter_map(|fragment| fragment.strip_prefix("光影"))
        .map(normalize_prompt_text)
        .collect::<Vec<_>>();
    if lighting_fragments.is_empty() {
        return;
    }

    fragments.retain(|fragment| {
        let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
            return true;
        };
        if !matches!(mood.as_str(), "冷调" | "冷色") {
            return true;
        }
        !lighting_fragments
            .iter()
            .any(|lighting| lighting_fragment_covers_generic_mood_tone(lighting, &mood))
    });

    let has_high_value_character_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment.starts_with("语气")
            || fragment.starts_with("动作")
            || fragment.starts_with("声场")
    });
    if has_high_value_character_signal {
        fragments.retain(|fragment| {
            let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
                return true;
            };
            !selected_style_fragment_is_generic_restrained_mood(&mood)
        });
    }

    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    if has_performance_signal {
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_motion(&action);
            }
            true
        });
    }

    let has_non_camera_style_signal = fragments.iter().any(|fragment| {
        !fragment.starts_with("镜头")
            && ((fragment.starts_with("情绪")
                && fragment
                    .strip_prefix("情绪")
                    .map(normalize_prompt_text)
                    .is_some_and(|mood| {
                        !selected_style_fragment_is_generic_restrained_mood(&mood)
                    }))
                || fragment.starts_with("光影")
                || fragment.starts_with("动作")
                || fragment.starts_with("表演")
                || fragment.starts_with("环境")
                || fragment.starts_with("语气")
                || fragment.starts_with("声场"))
    });
    if has_non_camera_style_signal {
        fragments.retain(|fragment| !is_local_framing_only_fragment(fragment));
    }
}

fn lighting_fragment_covers_generic_mood_tone(lighting: &str, mood: &str) -> bool {
    match mood {
        "冷调" | "冷色" => ["冷调", "冷色", "冷光"]
            .iter()
            .any(|keyword| lighting.contains(keyword)),
        _ => lighting.contains(mood),
    }
}

fn selected_style_fragment_is_generic_restrained_mood(mood: &str) -> bool {
    let normalized = normalize_prompt_text(mood);
    !normalized.is_empty()
        && normalized
            .split(['/', '／', '、', '，', ',', ' '])
            .map(normalize_prompt_text)
            .filter(|part| !part.is_empty())
            .all(|part| {
                matches!(
                    part.as_str(),
                    "克制" | "隐忍" | "压抑" | "沉静" | "沉稳" | "冷静"
                )
            })
}

fn selected_style_fragment_is_low_gain_voice(voice: &str) -> bool {
    matches!(voice, "低声克制" | "轻声克制" | "呢喃")
}

fn selected_style_fragment_is_low_gain_motion(action: &str) -> bool {
    matches!(action, "从容克制" | "克制自然" | "自然" | "简洁平滑")
}

fn compact_prefixed_style_fragment_with_keywords(
    fragment: &str,
    prefix: &str,
    keywords: &[&'static str],
) -> String {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment).trim();
    if body.is_empty() {
        return clip_prompt_fragment(fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
    }

    let compacted = compact_style_body_by_keywords(body, keywords)
        .filter(|value| value != body)
        .map(|value| format!("{prefix}{value}"))
        .unwrap_or_else(|| fragment.to_string());
    clip_prompt_fragment(&compacted, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
}

fn compact_style_body_by_keywords(body: &str, keywords: &[&'static str]) -> Option<String> {
    let mut matches = keywords
        .iter()
        .enumerate()
        .filter_map(|(priority, keyword)| {
            body.find(keyword)
                .map(|start| (start, start + keyword.len(), keyword, priority))
        })
        .collect::<Vec<_>>();
    if matches.is_empty() {
        return None;
    }
    matches.sort_by(|a, b| {
        a.0.cmp(&b.0)
            .then((b.1 - b.0).cmp(&(a.1 - a.0)))
            .then(a.3.cmp(&b.3))
    });

    let mut covered = vec![false; body.len()];
    let mut selected = Vec::new();
    let mut covered_len = 0usize;

    for (start, end, keyword, _) in matches {
        if (start..end).any(|idx| covered[idx]) {
            continue;
        }
        for idx in start..end {
            covered[idx] = true;
        }
        covered_len += end - start;
        selected.push(*keyword);
    }

    if selected.is_empty() || covered_len * 2 < body.len() {
        return None;
    }

    Some(selected.join(""))
}

fn compact_prompt_shot_style_fragment(fragment: &str) -> Option<String> {
    let matched = extract_style_keywords(fragment, "镜头", &STABLE_PROMPT_SHOT_KEYWORDS);
    if matched.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &format!("镜头{}", matched.join("")),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn style_only_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| {
            STYLE_NOTE_PREFIXES
                .iter()
                .any(|prefix| fragment.starts_with(prefix))
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    compact_video_style_prompt_note(&fragments.join("，"))
}

fn non_style_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| {
            !fragment.is_empty()
                && !STYLE_NOTE_PREFIXES
                    .iter()
                    .any(|prefix| fragment.starts_with(prefix))
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_selected_memory_residual_note(
    note: &str,
    subject: Option<&str>,
    style: Option<&str>,
    subject_is_stored: bool,
    action_hint: Option<&str>,
) -> Option<String> {
    let normalized_subject = subject
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let normalized_style = style
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let normalized_action_hint = action_hint
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let mut fragments = split_prompt_note_fragments(note)
        .filter(|fragment| !selected_memory_field_looks_silent(fragment))
        .collect::<Vec<_>>();
    if let Some(subject) = normalized_subject.as_deref() {
        if fragments.len() > 1 {
            fragments.retain(|fragment| fragment != subject);
        }
        if fragments.len() == 1 {
            let fragment = normalize_prompt_text(&fragments[0]);
            let fragment = fragment
                .strip_prefix(subject)
                .map(normalize_prompt_text)
                .unwrap_or(fragment);
            if !subject_is_stored {
                if let Some(action) = normalized_action_hint.as_deref() {
                    let action = normalize_prompt_text(action);
                    if !action.is_empty() {
                        fragments = vec![subject.to_string(), action];
                        if let Some(style) = normalized_style.as_deref() {
                            fragments = fragments
                                .into_iter()
                                .filter_map(|fragment| {
                                    trim_selected_memory_fragment_covered_by_style(&fragment, style)
                                })
                                .collect();
                        }
                        fragments.retain(|fragment| {
                            !fragment.is_empty()
                                && !low_signal_subject_pose_fragment(fragment)
                                && !low_signal_object_hold_fragment(fragment)
                        });
                        if fragments.is_empty() {
                            return None;
                        }
                        return Some(clip_prompt_fragment(
                            &fragments.join("，"),
                            VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                        ));
                    }
                }
            }
            if fragment.is_empty() || low_signal_subject_pose_fragment(&fragment) {
                return None;
            }
            fragments[0] = fragment;
        }
    }
    if let Some(style) = normalized_style.as_deref() {
        fragments = fragments
            .into_iter()
            .filter_map(|fragment| {
                trim_selected_memory_fragment_covered_by_style(&fragment, style).and_then(
                    |fragment| {
                        let fragment = normalize_prompt_text(&fragment);
                        (!fragment.is_empty()
                            && !low_signal_subject_pose_fragment(&fragment)
                            && !low_signal_object_hold_fragment(&fragment))
                        .then_some(fragment)
                    },
                )
            })
            .collect();
    }
    if subject_is_stored {
        if let Some(subject) = normalized_subject.as_deref() {
            fragments = fragments
                .into_iter()
                .filter_map(|fragment| {
                    let stripped = fragment
                        .strip_prefix(subject)
                        .map(normalize_prompt_text)
                        .unwrap_or(fragment);
                    let stripped = normalize_prompt_text(&stripped);
                    (!stripped.is_empty()
                        && !low_signal_subject_pose_fragment(&stripped)
                        && !low_signal_object_hold_fragment(&stripped))
                    .then_some(stripped)
                })
                .collect();
        }
    }
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn low_signal_subject_pose_fragment(fragment: &str) -> bool {
    LOW_SIGNAL_SUBJECT_POSE_PREFIXES
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

fn low_signal_object_hold_fragment(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    ACTION_OBJECT_PREFIX_VERBS.iter().any(|prefix| {
        normalized.starts_with(prefix)
            && normalized.chars().count() <= 6
            && ![
                "转", "冲", "跑", "推", "拉", "挡", "扑", "扑向", "回望", "回头", "走", "穿",
            ]
            .iter()
            .any(|keyword| normalized.contains(keyword))
    })
}

fn trim_selected_memory_fragment_covered_by_style(fragment: &str, style: &str) -> Option<String> {
    let mut normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }

    if style.contains("表演欲言又止") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "迟迟没有开口",
                "没有开口",
                "欲言又止",
                "话到嘴边",
                "张了张嘴",
            ],
        );
    }
    if style.contains("表演抬眼停顿") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["抬眼后停顿片刻", "抬眼停顿", "抬眼", "停顿片刻"],
        );
    }
    if style.contains("表演垂眼停顿") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["垂眼停顿", "垂眼", "低头停顿", "低头", "停顿片刻"],
        );
    }
    if style.contains("表演喉结滚动") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["喉结滚动", "喉头滚动", "喉结滑动", "喉头滑动"],
        );
    }
    if style.contains("表演指尖发颤") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["指尖发颤", "手指发颤", "指尖轻颤", "手指轻颤"],
        );
    }
    if style.contains("表演嘴角发僵") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["嘴角发僵", "嘴角僵住", "嘴角绷紧", "唇角发僵"],
        );
    }
    if style.contains("表演下颌绷紧") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["下颌绷紧", "下巴绷紧", "下颌发紧", "下巴发紧"],
        );
    }
    if style.contains("语气低声") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "低声开口",
                "低声说道",
                "低声说",
                "压低声音开口",
                "压低声音",
                "压低嗓音",
                "压低",
            ],
        );
    } else if style.contains("表演") && (style.contains("低声") || style.contains("压低")) {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "低声开口",
                "低声说道",
                "低声说",
                "压低声音开口",
                "压低声音",
                "压低嗓音",
                "压低",
            ],
        );
    } else if style.contains("语气轻声") || style.contains("语气呢喃") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "轻声开口",
                "轻声说道",
                "轻声说",
                "呢喃开口",
                "呢喃说道",
                "呢喃",
                "耳语开口",
                "耳语",
            ],
        );
    }

    normalized = normalize_prompt_text(
        normalized
            .trim_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, ',' | '，' | ';' | '；' | '.' | '。' | ':' | '：' | '、')
            })
            .trim_start_matches('后')
            .trim_start_matches('又')
            .trim_start_matches('再')
            .trim_start_matches('便')
            .trim_start_matches('才'),
    );
    if normalized.is_empty() {
        return None;
    }
    Some(normalized)
}

fn remove_fragment_phrases(fragment: &str, phrases: &[&str]) -> String {
    let mut normalized = normalize_prompt_text(fragment);
    for phrase in phrases {
        normalized = normalized.replace(phrase, "");
    }
    normalize_prompt_text(&normalized)
}

fn selected_video_style_value(row: &AgentMemoryRow) -> Option<String> {
    if let Some(value) = extract_key_value(&row.content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(&row.content, "note").and_then(|note| {
        if is_low_signal_selected_memory_note(&note) {
            return None;
        }
        compact_video_style_prompt_note(&note).or_else(|| {
            extract_key_value(&row.content, "note")
                .map(|raw| clip_prompt_fragment(&raw, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        })
    })
}

fn delivery_style_value_from_content(content: &str) -> Option<String> {
    extract_key_value(content, "delivery")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

fn summary_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let fallback = selected_video_style_value(row);
    if !matches!(
        row.name.as_str(),
        SCRIPT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_STYLE_MEMORY_NAME
    ) {
        return fallback;
    }

    let should_prefer_delivery = storyboard_row
        .and_then(|storyboard_row| {
            storyboard_row
                .video_desc
                .as_deref()
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_has_visible_speech_performance_risk(
                        &fields,
                        storyboard_row.prompt.as_deref(),
                    ) || storyboard_is_fragile_emotional_turn(&fields)
                })
        })
        .unwrap_or(false);

    if should_prefer_delivery {
        if let Some(delivery) = delivery_style_value_from_content(&row.content) {
            return Some(delivery);
        }
    }

    fallback
}

fn storyboard_is_fragile_emotional_turn(fields: &StructuredStoryboardDescription) -> bool {
    [
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .any(|field| {
        ["哽咽", "发哽", "含泪", "泪", "哭", "发颤", "颤声", "鼻音"]
            .iter()
            .any(|keyword| field.contains(keyword))
    })
}

fn role_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let fallback = selected_video_style_value(row);
    if !matches!(
        row.name.as_str(),
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME
    ) {
        return fallback;
    }

    let should_prefer_delivery = storyboard_row
        .and_then(|storyboard_row| {
            storyboard_row
                .video_desc
                .as_deref()
                .and_then(parse_structured_storyboard_description)
                .map(|fields| {
                    selected_memory_has_visible_speech_performance_risk(
                        &fields,
                        storyboard_row.prompt.as_deref(),
                    )
                })
        })
        .unwrap_or(false);

    if should_prefer_delivery {
        if let Some(delivery) = delivery_style_value_from_content(&row.content) {
            return Some(delivery);
        }
    }

    fallback
}

fn is_low_signal_selected_memory_note(note: &str) -> bool {
    let normalized = normalize_prompt_text(note)
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | '，' | ';' | '；' | '.' | '。' | ':' | '：')
        })
        .to_string();
    if normalized.is_empty() {
        return true;
    }

    matches!(
        normalized.as_str(),
        "当前镜头已确认" | "镜头已确认" | "当前分镜已确认" | "重复确认同镜头" | "同镜头重复确认"
    ) || ((normalized.contains("镜头") || normalized.contains("分镜"))
        && normalized.contains("确认")
        && normalized.chars().count() <= 10)
}

fn selected_video_memory_update_would_reduce_quality(existing: &str, incoming: &str) -> bool {
    selected_video_memory_quality_score(existing) > selected_video_memory_quality_score(incoming)
}

fn selected_video_memory_quality_score(content: &str) -> i32 {
    let mut score = 0;

    if let Some(style) = selected_video_style_value_from_content(content) {
        score += 80;
        let fragments = split_prompt_note_fragments(&style).collect::<Vec<_>>();
        score += fragments
            .iter()
            .cloned()
            .map(score_selected_video_memory_style_fragment)
            .sum::<i32>();
        score -= selected_video_memory_style_redundancy_penalty(&fragments);
    }

    if let Some(note) = extract_key_value(content, "note")
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !is_low_signal_selected_memory_note(value))
    {
        score += 20;
        score += split_prompt_note_fragments(&note)
            .map(score_selected_video_memory_note_fragment)
            .sum::<i32>();
    }

    score
}

fn selected_video_memory_style_redundancy_penalty(fragments: &[String]) -> i32 {
    if !fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"))
    {
        return 0;
    }

    fragments.iter().fold(0, |penalty, fragment| {
        if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            if selected_style_fragment_is_low_gain_voice(&voice) {
                return penalty + 8;
            }
        }
        if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
            if selected_style_fragment_is_generic_restrained_mood(&mood) {
                return penalty + 6;
            }
        }
        if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
            if selected_style_fragment_is_low_gain_motion(&action) {
                return penalty + 6;
            }
        }
        penalty
    })
}

fn score_selected_video_memory_style_fragment(fragment: String) -> i32 {
    let fragment = normalize_prompt_text(&fragment);
    if fragment.is_empty() {
        return 0;
    }

    let mut score = 6;
    if fragment.starts_with("镜头") {
        score += 8;
    }
    if fragment.starts_with("情绪") {
        score += 6;
    }
    if fragment.starts_with("光影") {
        score += 6;
    }
    if fragment.starts_with("动作") {
        score += 5;
    }
    if fragment.starts_with("表演") {
        score += 6;
    }
    if fragment.starts_with("环境") {
        score += 4;
    }
    if fragment.starts_with("语气") {
        score += 5;
    }
    if fragment.starts_with("声场") {
        score += 5;
    }
    if fragment.starts_with("场景") {
        score += 2;
    }
    score + fragment.chars().count().min(18) as i32 / 3
}

fn score_selected_video_memory_note_fragment(fragment: String) -> i32 {
    let fragment = normalize_prompt_text(&fragment);
    if fragment.is_empty() {
        return 0;
    }

    let mut score = 4;
    if STYLE_NOTE_PREFIXES
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
    {
        score += 3;
    }
    score + fragment.chars().count().min(18) as i32 / 6
}

pub(crate) fn compact_video_continuity_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            STYLE_NOTE_PREFIXES
                .iter()
                .any(|prefix| fragment.starts_with(prefix))
                || CONTINUITY_NOTE_KEYWORDS
                    .iter()
                    .any(|keyword| fragment.contains(keyword))
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn pick_recurring_prefixed_fragment(parsed_notes: &[Vec<String>], prefix: &str) -> Option<String> {
    let min_support = recurring_fragment_support_threshold(parsed_notes.len());
    let mut counts: Vec<(String, usize, usize)> = Vec::new();
    for (note_idx, fragments) in parsed_notes.iter().enumerate() {
        for fragment in fragments {
            if !fragment.starts_with(prefix) {
                continue;
            }
            if let Some(existing) = counts.iter_mut().find(|(value, _, _)| value == fragment) {
                existing.1 += 1;
                existing.2 = existing.2.min(note_idx);
            } else {
                counts.push((fragment.clone(), 1, note_idx));
            }
        }
    }

    counts
        .into_iter()
        .filter(|(_, count, _)| *count >= min_support)
        .max_by(|a, b| a.1.cmp(&b.1).then_with(|| b.2.cmp(&a.2)))
        .map(|(value, _, _)| value)
}

fn summarize_recurring_prefixed_fragment(
    parsed_notes: &[Vec<String>],
    prefix: &str,
) -> Option<String> {
    if prefix == "镜头" {
        summarize_recurring_style_keywords(parsed_notes, prefix)
            .or_else(|| summarize_recurring_stable_shot_fragment(parsed_notes))
    } else {
        pick_recurring_prefixed_fragment(parsed_notes, prefix)
            .or_else(|| summarize_recurring_style_keywords(parsed_notes, prefix))
    }
}

fn summarize_recurring_stable_shot_fragment(parsed_notes: &[Vec<String>]) -> Option<String> {
    pick_recurring_prefixed_fragment(parsed_notes, "镜头").and_then(|fragment| {
        let matched = extract_style_keywords(&fragment, "镜头", &SHOT_STYLE_KEYWORDS);
        if matched.is_empty() {
            None
        } else {
            Some(format!("镜头{}", matched.join("")))
        }
    })
}

fn summarize_recurring_style_keywords(
    parsed_notes: &[Vec<String>],
    prefix: &str,
) -> Option<String> {
    let keywords = match prefix {
        "镜头" => &SHOT_STYLE_KEYWORDS[..],
        "情绪" => &MOOD_STYLE_KEYWORDS[..],
        "光影" => &LIGHTING_STYLE_KEYWORDS[..],
        "动作" => &MOTION_STYLE_KEYWORDS[..],
        "表演" => &PERFORMANCE_STYLE_KEYWORDS[..],
        "环境" => &ENVIRONMENT_STYLE_KEYWORDS[..],
        "语气" => &VOICE_STYLE_KEYWORDS[..],
        "声场" => &SOUND_STAGE_STYLE_KEYWORDS[..],
        _ => return None,
    };
    let min_support = recurring_fragment_support_threshold(parsed_notes.len());

    let mut counts = Vec::<(&'static str, usize)>::new();
    for fragments in parsed_notes {
        let matched = fragments
            .iter()
            .filter(|fragment| fragment.starts_with(prefix))
            .flat_map(|fragment| extract_style_keywords(fragment, prefix, keywords))
            .collect::<Vec<_>>();
        for keyword in matched {
            if let Some(existing) = counts.iter_mut().find(|(value, _)| *value == keyword) {
                existing.1 += 1;
            } else {
                counts.push((keyword, 1));
            }
        }
    }

    let summary = keywords
        .iter()
        .filter(|keyword| {
            counts
                .iter()
                .any(|(value, count)| value == *keyword && *count >= min_support)
        })
        .take(match prefix {
            "镜头" => 3,
            "环境" => 1,
            "声场" => 1,
            _ => 2,
        })
        .copied()
        .collect::<Vec<_>>();
    if summary.is_empty() {
        return None;
    }

    Some(format!("{prefix}{}", summary.join("")))
}

fn recurring_fragment_support_threshold(sample_count: usize) -> usize {
    match sample_count {
        0 | 1 => usize::MAX,
        2 | 3 => 2,
        _ => (sample_count / 2) + 1,
    }
}

fn extract_style_keywords<'a>(
    fragment: &str,
    prefix: &str,
    keywords: &'a [&'static str],
) -> Vec<&'a str> {
    let value = fragment.strip_prefix(prefix).unwrap_or(fragment);
    let mut matched = Vec::new();
    for keyword in keywords {
        if !value.contains(keyword) || matched.iter().any(|existing: &&str| existing == keyword) {
            continue;
        }
        if matched
            .iter()
            .any(|existing: &&str| existing.contains(keyword) || keyword.contains(existing))
        {
            continue;
        }
        matched.push(*keyword);
    }
    matched
}

fn compact_selected_memory_environment(fields: &StructuredStoryboardDescription) -> Option<String> {
    let context = normalize_prompt_text(
        &[
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
            fields.lighting.as_str(),
        ]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join(" "),
    );
    if context.is_empty() {
        return None;
    }

    let candidates: [(&[&str], &str); 13] = [
        (&["咖啡"], "咖啡热气"),
        (&["手机", "屏幕"], "手机屏幕亮灭"),
        (&["雨", "玻璃"], "雨丝玻璃"),
        (&["窗帘"], "窗帘轻摆"),
        (&["车流"], "车流反光"),
        (&["霓虹"], "霓虹反光"),
        (&["烛火"], "烛火轻晃"),
        (&["竹"], "竹影摇动"),
        (&["水", "波"], "水波微晃"),
        (&["烟"], "烟雾流动"),
        (&["花瓣"], "花瓣飘落"),
        (&["树叶"], "树叶轻摆"),
        (&["雪"], "雪花飘落"),
    ];

    candidates.into_iter().find_map(|(tokens, cue)| {
        tokens
            .iter()
            .all(|token| context.contains(*token))
            .then_some(cue.to_string())
    })
}

fn push_rejected_negative_fragment(
    target: &mut Vec<&'static str>,
    candidate: Option<&'static str>,
) {
    let Some(candidate) = candidate else {
        return;
    };
    if target.iter().any(|existing| existing == &candidate) {
        return;
    }
    target.push(candidate);
}

fn map_rejected_shot_or_camera_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("手持") {
        return Some("avoid shaky handheld motion");
    }
    if value.contains("稳定跟拍")
        || value.contains("跟拍")
        || value.contains("推进")
        || value.contains("慢推")
    {
        return Some("avoid repeating stable follow camera");
    }
    if value.contains("低机位") || value.contains("高机位") {
        return Some("avoid extreme camera angle");
    }
    if value.contains("特写") || value.contains("近景") {
        return Some("avoid overly tight close-up framing");
    }
    None
}

fn map_rejected_mood_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("压迫") || value.contains("紧张") || value.contains("急迫") {
        return Some("avoid oppressive or frantic mood");
    }
    if value.contains("冷峻") || value.contains("冷调") || value.contains("冷色") {
        return Some("avoid overly cold emotional tone");
    }
    if value.contains("悲怆") {
        return Some("avoid heavy tragic mood");
    }
    None
}

fn map_rejected_performance_fragment(
    action: &str,
    dialogue: &str,
    mood: &str,
) -> Option<&'static str> {
    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    let has_dialogue = !dialogue.is_empty()
        && !["无台词", "沉默", "静默", "无对白"]
            .iter()
            .any(|token| dialogue.contains(token));
    let has_restrained_emotional_signal = [action.as_str(), dialogue.as_str(), mood.as_str()]
        .into_iter()
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
                    "压低声音",
                    "强忍",
                    "颤",
                    "克制",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        });
    if has_dialogue && has_restrained_emotional_signal {
        return Some("avoid blank expression or monotone delivery");
    }

    let has_silent_high_signal = [action.as_str(), mood.as_str()].into_iter().any(|value| {
        !value.is_empty()
            && [
                "欲言又止",
                "隐忍",
                "哽咽",
                "迟疑",
                "停顿",
                "犹豫",
                "强忍",
                "颤",
                "喉结",
                "嘴角发僵",
                "下颌绷紧",
                "指尖发颤",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    has_silent_high_signal.then_some("avoid blank expression or monotone delivery")
}

fn map_rejected_lighting_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("逆光") {
        return Some("avoid harsh backlight silhouette");
    }
    if value.contains("冷光") || value.contains("阴天冷光") || value.contains("冷调") {
        return Some("avoid flat cold lighting");
    }
    if value.contains("霓虹") || value.contains("反光") {
        return Some("avoid distracting neon reflections");
    }
    None
}

fn rejected_negative_memory_fragment_is_low_signal(fragment: &str) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}

async fn replace_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn replace_summary_memories(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    contents: Vec<String>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for content in contents.into_iter().take(keep_rows as usize) {
        sqlx::query(
            r#"
            INSERT INTO app_agent_memory (
              owner_user_id, numeric_project_id, episodes_id, agent_type,
              memory_type, role, name, content, summarized, create_time_ms
            )
            VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(script_numeric_id)
        .bind(name)
        .bind(content)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}

async fn replace_project_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id IS NULL
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $3
          ORDER BY create_time_ms DESC
          OFFSET $4
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn replace_project_summary_memories(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    contents: Vec<String>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for content in contents.into_iter().take(keep_rows as usize) {
        sqlx::query(
            r#"
            INSERT INTO app_agent_memory (
              owner_user_id, numeric_project_id, episodes_id, agent_type,
              memory_type, role, name, content, summarized, create_time_ms
            )
            VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(name)
        .bind(content)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        build_project_role_video_style_memories, build_project_video_style_memory,
        build_rejected_video_negative_memory, build_script_role_video_observation_memories,
        build_script_role_video_style_memories, build_script_video_observation_memory,
        build_script_video_style_memory, build_selected_video_memory,
        clear_rejected_video_negative_memory, clear_selected_video_memory,
        compact_rejected_negative_avoid, compact_selected_memory_action,
        compact_selected_memory_setting, compact_selected_memory_subject,
        compact_video_continuity_note, compact_video_style_prompt_note,
        merge_rejected_video_negative_memory, merge_selected_memory_subject_action,
        parse_structured_storyboard_description, rejected_video_negative_rejection_count,
        select_neighbor_selected_video_memory_notes,
        select_pending_rejected_video_observation_candidates,
        select_pending_rejected_video_observation_candidates_for_subject,
        select_pending_rejected_video_observation_note, select_prioritized_video_style_note,
        select_project_video_style_memory_notes,
        select_rejected_video_memory_notes_and_observation_candidates_for_subject,
        select_rejected_video_negative_memory_notes,
        select_rejected_video_negative_memory_notes_for_subject,
        select_script_video_style_memory_notes, select_selected_video_memory_notes,
        select_subject_role_video_style_memory_notes,
        select_subject_role_video_style_memory_notes_for_storyboard,
        selected_memory_subject_aliases, selected_memory_subject_identity,
        selected_video_memory_quality_score, selected_video_memory_scope,
        selected_video_memory_update_would_reduce_quality, storyboard_prompt_seed, AgentMemoryRow,
        ScopedAgentMemoryRow, SelectedVideoMemoryScope, StoryboardPromptSeedRow,
    };
    use sqlx::PgPool;
    use uuid::Uuid;

    #[test]
    fn parse_structured_storyboard_description_extracts_fields() {
        let fields = parse_structured_storyboard_description(
            "（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）",
        )
        .expect("fields");

        assert_eq!(fields.setting, "旧宅走廊");
        assert_eq!(fields.duration_seconds, Some(5));
        assert_eq!(fields.dialogue, "别回头");
        assert_eq!(fields.sound, "脚步声门响");
    }

    #[test]
    fn build_selected_video_memory_prefers_compact_structured_note() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在走廊里冲出门外".into()),
                video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("storyboardIds=12"));
        assert!(content.contains("promptSeed="));
        assert!(content.contains("style=镜头稳定跟拍，情绪急迫，光影阴天冷光"));
        assert!(content.contains("note=主角推门冲出旧宅"));
        assert!(!content.contains("快步推门冲出"));
        assert!(!content.contains("note=主角冲出旧宅，推门冲出"));
        assert!(!content.contains("note=主角冲出旧宅，镜头中景稳定跟拍"));
        assert!(!content.contains("note=主角冲出旧宅，快步推门冲出，情绪急迫"));
        assert!(!content.contains("场景旧宅走廊"));
        assert!(!content.contains("duration="));
    }

    #[test]
    fn build_selected_video_memory_drops_duplicate_subject_and_scene_fragments() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在旧宅走廊尽头停步回头".into()),
                video_desc: Some("（主角在旧宅走廊尽头停步回头、旧宅走廊尽头、主角、5秒、中景、稳定跟拍、主角在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("停步回头"), "{content}");
        assert!(!content.contains("note=主角"), "{content}");
        assert!(!content.contains("note=主角在旧宅走廊尽头停步回头，镜头中景稳定跟拍"));
        assert!(!content.contains("note=主角在旧宅走廊尽头停步回头"));
        assert!(!content.contains("场景旧宅走廊尽头"));
        assert!(content.contains("情绪压抑"));
    }

    #[test]
    fn build_selected_video_memory_trims_subject_and_pace_prefix_from_action_when_mood_exists() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("女主冲出旧宅".into()),
                video_desc: Some("（女主冲出旧宅、旧宅门厅、女主、5秒、中景、稳定跟拍、女主快步推门冲出、急迫、阴天冷光、无台词、门响脚步声、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("note=女主推门冲出旧宅"));
        assert!(!content.contains("女主快步推门冲出"), "{content}");
        assert!(
            !content.contains("note=女主冲出旧宅，快步推门冲出"),
            "{content}"
        );
    }

    #[test]
    fn build_selected_video_memory_trims_subject_action_overlap_when_identity_remains() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角冲出旧宅".into()),
                video_desc: Some("（主角冲出旧宅、旧宅门厅、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、门响脚步声、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("note=主角，推门后回望"), "{content}");
        assert!(
            !content.contains("note=主角冲出旧宅，快步推门冲出旧宅后回望"),
            "{content}"
        );
    }

    #[test]
    fn build_selected_video_memory_trims_object_prefix_from_action_when_subject_lists_prop() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角握紧匕首穿过走廊".into()),
                video_desc: Some("（主角穿过走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首转身格挡、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("note=主角穿过走廊"), "{content}");
        assert!(content.contains("转身格挡"), "{content}");
        assert!(!content.contains("握紧青铜匕首转身格挡"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_trims_subject_lead_in_from_setting_when_scene_suffix_remains() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角驻足".into()),
                video_desc: Some("（主角驻足、主角身后的门厅、主角、5秒、中景、稳定跟拍、抬眼观察、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(!content.contains("场景主角身后的门厅"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_trims_setting_lead_in_repeated_by_action_context() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在旧宅走廊尽头回头".into()),
                video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("停步回头"), "{content}");
        assert!(!content.contains("场景在旧宅走廊尽头的门厅"), "{content}");
        assert!(!content.contains("在旧宅走廊尽头停步回头"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_prefers_environment_fragment_over_raw_scene_suffix() {
        let content = build_selected_video_memory(
            18,
            &StoryboardPromptSeedRow {
                prompt: Some("女主站在窗边看着雨幕".into()),
                video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("环境雨丝玻璃"), "{content}");
        assert!(!content.contains("场景城市夜景落地窗边"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_motion_style_fragment() {
        let content = build_selected_video_memory(
            21,
            &StoryboardPromptSeedRow {
                prompt: Some("女主站在窗边压住情绪".into()),
                video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、缓缓抬眼轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A21）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("style=动作从容克制"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_voice_and_sound_style_fragments() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚看着窗外低声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("语气低声克制"), "{content}");
        assert!(content.contains("声场雨声回响"), "{content}");
        assert!(!content.contains("迟迟没有开口"), "{content}");
        assert!(!content.contains("低声开口"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_compacts_visible_speech_delivery_into_single_fragment() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚喉头滚动后低声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演喉结滚动低声克制"), "{content}");
        assert!(content.contains("声场雨声回响"), "{content}");
        assert!(!content.contains("语气低声克制"), "{content}");
        assert!(!content.contains("note="), "{content}");
    }

    #[test]
    fn build_selected_video_memory_keeps_high_signal_tail_tremble_delivery() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚抿唇后压低气息开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后压低气息说你终于来了尾音发颤、隐忍 / 克制、冷蓝窗光、你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(
            content.contains("表演喉结滚动压低气息尾音发颤"),
            "{content}"
        );
        assert!(!content.contains("语气低声克制"), "{content}");
        assert!(!content.contains("语气低声尾音发颤"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚抬眼后低声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、缓缓抬眼后停顿片刻、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(
            content.contains("style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响"),
            "{content}"
        );
        assert!(!content.contains("动作从容克制"), "{content}");
        assert!(!content.contains("情绪克制"), "{content}");
        assert!(!content.contains("语气低声克制"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_identity_silent_scene_prefers_micro_performance_only() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚在镜前停住".into()),
                video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影后停顿、克制、暖金逆光、无台词、静场留白、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("style=表演抬眼停顿"), "{content}");
        assert!(!content.contains("镜头近景"), "{content}");
        assert!(!content.contains("光影暖金逆光"), "{content}");
        assert!(!content.contains("声场静场留白"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_identity_scene_keeps_visual_carryover_when_no_micro_performance_exists(
    ) {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚在镜前沉默".into()),
                video_desc: Some("（林晚在镜前沉默、化妆镜前、林晚、4秒、近景、静止、静静看向镜中倒影、克制、暖金逆光、无台词、静场留白、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("光影暖金逆光"), "{content}");
        assert!(content.contains("声场静场留白"), "{content}");
        assert!(!content.contains("style=表演"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_skips_voice_memory_for_wide_moving_low_visibility_dialogue() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚穿过雨幕边跑边喊".into()),
                video_desc: Some("（林晚穿过雨幕、雨夜街头、林晚、4秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(!content.contains("语气"), "{content}");
        assert!(!content.contains("表演"), "{content}");
        assert!(content.contains("镜头远景手持跟拍"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_persists_subject_identity_for_role_memory() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚看着窗外低声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("subject=林晚"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_persists_subject_aliases_for_role_memory() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("晚晚看着窗外低声开口".into()),
                video_desc: Some("（晚晚站在窗边、城市夜景落地窗边、林晚/晚晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("subjectAliases="), "{content}");
        assert!(content.contains("subject=林晚"), "{content}");
        assert!(content.contains("subjectAliases=晚晚"), "{content}");
        assert!(!content.contains("subjectAliases=林晚/"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_drops_descriptive_or_prop_subject_alias_noise() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚站在窗边轻声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚站在窗边/晚晚/咖啡杯、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("subject=林晚"), "{content}");
        assert!(content.contains("subjectAliases=晚晚"), "{content}");
        assert!(!content.contains("林晚站在窗边"), "{content}");
        assert!(!content.contains("咖啡杯"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_drops_dialogue_shaped_subject_alias_noise() {
        let content = build_selected_video_memory(
            22,
            &StoryboardPromptSeedRow {
                prompt: Some("晚晚低声开口".into()),
                video_desc: Some("（晚晚低声开口、城市夜景落地窗边、林晚轻声说道/晚晚低声开口、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("subject=林晚"), "{content}");
        assert!(content.contains("subjectAliases=晚晚"), "{content}");
        assert!(!content.contains("林晚轻声说道"), "{content}");
        assert!(!content.contains("晚晚低声开口"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_performance_style_fragment() {
        let content = build_selected_video_memory(
            23,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚抬眼却没说出口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后停顿片刻迟迟没有开口、隐忍 / 克制、冷蓝窗光、无台词、雨声、A23）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演抬眼停顿"), "{content}");
        assert!(!content.contains("抬眼后停顿片刻"), "{content}");
        assert!(!content.contains("note="), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_throat_motion_performance_fragment() {
        let content = build_selected_video_memory(
            23,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚喉头滚动后低声开口".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A23）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演喉结滚动"), "{content}");
        assert!(!content.contains("喉头滚动后低声开口"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_stiff_smile_performance_fragment() {
        let content = build_selected_video_memory(
            23,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚嘴角僵住仍强撑微笑".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、嘴角僵住仍强撑微笑、压抑、冷蓝窗光、无台词、雨声、A23）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演嘴角发僵"), "{content}");
        assert!(!content.contains("嘴角僵住仍强撑微笑"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_finger_tremble_performance_fragment() {
        let content = build_selected_video_memory(
            23,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚手指轻颤着攥紧衣角".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、手指轻颤着攥紧衣角、隐忍、冷蓝窗光、无台词、雨声、A23）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演指尖发颤"), "{content}");
        assert!(!content.contains("手指轻颤着攥紧衣角"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_extracts_tight_jaw_performance_fragment() {
        let content = build_selected_video_memory(
            23,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚下颌绷紧后才慢慢转身".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、下颌绷紧后才慢慢转身、压抑、冷蓝窗光、无台词、雨声、A23）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演下颌绷紧"), "{content}");
        assert!(!content.contains("下颌绷紧后才慢慢转身"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_keeps_action_note_not_covered_by_style() {
        let content = build_selected_video_memory(
            27,
            &StoryboardPromptSeedRow {
                prompt: Some("主角推门后回望".into()),
                video_desc: Some("（主角推门后回望、旧宅门厅、主角、4秒、中景、稳定跟拍、抬眼停顿后推门回望、克制、冷蓝窗光、无台词、雨声、A27）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("表演抬眼停顿"), "{content}");
        assert!(content.contains("note=主角，推门回望"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_drops_local_framing_when_other_style_signal_exists() {
        let content = build_selected_video_memory(
            24,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚站在窗边压住情绪".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、近景、无、抬眼后停顿片刻、克制、冷蓝窗光、无台词、雨声回响、A24）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(
            content.contains("style=动作从容克制，表演抬眼停顿，光影冷蓝窗光，声场雨声回响"),
            "{content}"
        );
        assert!(!content.contains("镜头近景"), "{content}");
        assert!(!content.contains("情绪克制"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_keeps_generic_restrained_mood_without_character_signal() {
        let content = build_selected_video_memory(
            25,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚站在窗边看着雨幕".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、近景、无、站定看向窗外、克制、无、无台词、无音效、A25）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("情绪克制"), "{content}");
        assert!(!content.contains("光影无"), "{content}");
    }

    #[test]
    fn build_selected_video_memory_drops_subject_only_note_when_identity_is_stored() {
        let content = build_selected_video_memory(
            26,
            &StoryboardPromptSeedRow {
                prompt: Some("林晚站在窗边".into()),
                video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、无、克制、冷蓝窗光、无台词、雨声、A26）".into()),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("subject=林晚"), "{content}");
        assert!(
            content.contains("style=情绪克制，光影冷蓝窗光"),
            "{content}"
        );
        assert!(!content.contains("note="), "{content}");
    }

    #[test]
    fn compact_selected_memory_action_keeps_pace_prefix_when_mood_is_missing() {
        let action = compact_selected_memory_action(
            "女主缓步后退躲避",
            Some("女主后退躲避"),
            Some("女主后退躲避"),
            Some("女主"),
            None,
            "",
        )
        .expect("action");

        assert_eq!(action, "缓步后退躲避");
    }

    #[test]
    fn compact_selected_memory_action_strips_setting_prefix_when_followup_motion_remains() {
        let action = compact_selected_memory_action(
            "在旧宅走廊尽头停步回头",
            Some("主角在旧宅走廊尽头回头"),
            Some("主角在旧宅走廊尽头回头"),
            Some("主角"),
            Some("在旧宅走廊尽头的门厅"),
            "压抑",
        )
        .expect("action");

        assert_eq!(action, "停步回头");
    }

    #[test]
    fn compact_selected_memory_action_strips_subject_motion_overlap_before_followup_suffix() {
        let action = compact_selected_memory_action(
            "快步推门冲出旧宅后回望",
            Some("主角"),
            Some("主角冲出旧宅"),
            Some("主角"),
            None,
            "急迫",
        )
        .expect("action");

        assert_eq!(action, "推门后回望");
    }

    #[test]
    fn merge_selected_memory_subject_action_merges_shared_motion_tail() {
        let merged = merge_selected_memory_subject_action(Some("主角冲出旧宅"), Some("推门冲出"))
            .expect("merged");

        assert_eq!(merged, "主角推门冲出旧宅");
    }

    #[test]
    fn compact_selected_memory_subject_trims_shared_action_overlap() {
        let subject = compact_selected_memory_subject("主角冲出旧宅", "快步推门冲出旧宅后回望")
            .expect("subject");

        assert_eq!(subject, "主角");
    }

    #[test]
    fn merge_selected_memory_subject_action_skips_locative_subjects() {
        assert_eq!(
            merge_selected_memory_subject_action(Some("主角在旧宅走廊尽头回头"), Some("停步回头"),),
            None
        );
    }

    #[test]
    fn compact_selected_memory_setting_strips_prop_or_subject_lead_in() {
        let setting = compact_selected_memory_setting(
            "青铜匕首旁的供桌边",
            None,
            Some("主角/青铜匕首"),
            None,
        )
        .expect("setting");

        assert_eq!(setting, "供桌边");
    }

    #[test]
    fn compact_selected_memory_setting_strips_locative_lead_in_when_subject_or_action_covers_it() {
        let setting = compact_selected_memory_setting(
            "在旧宅走廊尽头的门厅",
            Some("主角在旧宅走廊尽头回头"),
            Some("主角"),
            Some("在旧宅走廊尽头停步回头"),
        )
        .expect("setting");

        assert_eq!(setting, "门厅");
    }

    #[test]
    fn build_rejected_video_negative_memory_extracts_short_retry_constraints() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在走廊里冲出门外".into()),
                video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("storyboardIds=12"));
        assert!(content.contains("promptSeed="));
        assert!(content.contains("subject=主角"));
        assert!(content.contains("rejectionCount=1"));
        assert!(content.contains("avoid repeating stable follow camera"));
        assert!(content.contains("avoid flat cold lighting"));
        assert!(!content.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn build_rejected_video_negative_memory_compacts_same_family_fragments() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("门厅低机位逼视".into()),
                video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、近景、低机位逼近、盯住来人、克制、暖光、、、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(
            content.contains("avoid=avoid extreme camera angle or overly tight close-up framing")
        );
        assert!(!content
            .contains("avoid=avoid overly tight close-up framing, avoid extreme camera angle"));
    }

    #[test]
    fn build_rejected_video_negative_memory_prefers_handheld_warning_for_handheld_follow_camera() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("雨巷追随".into()),
                video_desc: Some("（主角穿过雨巷、霓虹雨巷、主角、5秒、中景、手持跟拍、踩水快步穿行、克制、霓虹反光、无台词、雨声脚步声、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("avoid shaky handheld motion"));
        assert!(!content.contains("avoid repeating stable follow camera"));
    }

    #[test]
    fn build_rejected_video_negative_memory_skips_low_signal_mood_only_memory() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角停在门口".into()),
                video_desc: Some(
                    "（主角停在门口、旧宅门厅、主角、5秒、中景、固定、停步凝视、压迫、暖光、无台词、风声、A12）"
                        .into(),
                ),
                duration: Some("5".into()),
            },
        );

        assert!(content.is_none());
    }

    #[test]
    fn build_rejected_video_negative_memory_skips_repeat_follow_camera_only_memory() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角穿过走廊".into()),
                video_desc: Some(
                    "（主角穿过走廊、旧宅走廊、主角、5秒、中景、稳定跟拍、穿过走廊、平静、暖光、无台词、脚步声、A12）"
                        .into(),
                ),
                duration: Some("5".into()),
            },
        );

        assert!(content.is_none());
    }

    #[test]
    fn build_rejected_video_negative_memory_drops_cold_mood_when_cold_lighting_already_exists() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角停在楼梯口".into()),
                video_desc: Some(
                    "（主角停在楼梯口、旧宅楼梯、主角、5秒、中景、固定、停步回望、冷调、阴天冷光、无台词、风声、A12）"
                        .into(),
                ),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("avoid=avoid flat cold lighting"));
        assert!(!content.contains("avoid overly cold emotional tone"));
    }

    #[test]
    fn build_rejected_video_negative_memory_adds_performance_guard_for_restrained_dialogue_scene() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("晚晚欲言又止".into()),
                video_desc: Some(
                    "（晚晚欲言又止、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"
                        .into(),
                ),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("avoid blank expression or monotone delivery"));
    }

    #[test]
    fn build_rejected_video_negative_memory_adds_performance_guard_for_high_signal_silent_scene() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("她强忍泪意转身".into()),
                video_desc: Some(
                    "（她强忍泪意转身、病房门口、她、4秒、中景、静止、喉结滚动后慢慢转身、隐忍、冷白侧光、无台词、空调低鸣、A12）"
                        .into(),
                ),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("avoid blank expression or monotone delivery"));
    }

    #[test]
    fn build_rejected_video_negative_memory_skips_performance_guard_for_low_signal_silent_scene() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角站在门口".into()),
                video_desc: Some(
                    "（主角站在门口、旧宅门厅、主角、4秒、中景、静止、站在门口、平静、室内暖光、无台词、风声、A12）"
                        .into(),
                ),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(!content.contains("avoid blank expression or monotone delivery"));
    }

    #[test]
    fn build_rejected_video_negative_memory_persists_compact_risk_tags() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("晚晚抬眼后低声开口".into()),
                video_desc: Some(
                    "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                        .into(),
                ),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(
            content.contains("riskTags=lighting/emotion/performance/dialogue"),
            "{content}"
        );
    }

    #[test]
    fn build_rejected_video_negative_memory_persists_identity_risk_tag_for_face_visible_shot() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("晚晚回头看向镜头".into()),
                video_desc: Some(
                    "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                        .into(),
                ),
                duration: Some("4".into()),
            },
        )
        .expect("content");

        assert!(content.contains("riskTags=identity"), "{content}");
    }

    #[test]
    fn select_selected_video_memory_notes_keeps_latest_matching_storyboard() {
        let notes = select_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=9 | note=别的镜头".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
                },
                AgentMemoryRow {
                    name: "auto_scope_memory".into(),
                    content: "storyboardIds=12 | note=不应读取".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪压迫".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_prefers_older_style_over_newer_confirmation_note() {
        let notes = select_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | note=当前镜头已确认".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪压迫".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_prefers_richer_older_style_over_newer_single_axis_note() {
        let notes = select_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=情绪压迫 | note=当前镜头情绪压迫".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=情绪压迫，光影冷调逆光 | note=保持情绪压迫和冷调逆光".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪压迫，光影冷调逆光".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_skips_confirmation_note_without_style() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | note=当前镜头已确认".into(),
            }],
            12,
            None,
        );

        assert!(notes.is_empty());
    }

    #[test]
    fn selected_video_memory_update_would_reduce_quality_when_incoming_drops_style_signal() {
        assert!(selected_video_memory_update_would_reduce_quality(
            "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=主角贴墙前行",
            "storyboardIds=12 | promptSeed=seed-12 | note=当前镜头已确认"
        ));
    }

    #[test]
    fn selected_video_memory_update_would_reduce_quality_when_incoming_keeps_style_but_loses_useful_note(
    ) {
        assert!(selected_video_memory_update_would_reduce_quality(
            "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行",
            "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=当前镜头已确认"
        ));
    }

    #[test]
    fn selected_video_memory_quality_score_prefers_incoming_when_it_adds_style_signal() {
        assert!(
            selected_video_memory_quality_score(
                "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行"
            ) > selected_video_memory_quality_score(
                "storyboardIds=12 | promptSeed=seed-12 | note=主角贴墙前行"
            )
        );
        assert!(!selected_video_memory_update_would_reduce_quality(
            "storyboardIds=12 | promptSeed=seed-12 | note=主角贴墙前行",
            "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行"
        ));
    }

    #[test]
    fn selected_video_memory_quality_score_penalizes_low_gain_style_redundancy_when_performance_exists(
    ) {
        assert!(
            selected_video_memory_quality_score(
                "storyboardIds=12 | promptSeed=seed-12 | style=动作从容克制，表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，声场雨声回响"
            ) < selected_video_memory_quality_score(
                "storyboardIds=12 | promptSeed=seed-12 | style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响"
            )
        );
        assert!(!selected_video_memory_update_would_reduce_quality(
            "storyboardIds=12 | promptSeed=seed-12 | style=动作从容克制，表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，声场雨声回响",
            "storyboardIds=12 | promptSeed=seed-12 | style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响"
        ));
    }

    #[test]
    fn selected_video_memory_scope_uses_storyboard_and_prompt_seed() {
        let scope = selected_video_memory_scope(
            "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景稳定跟拍，情绪压迫",
        )
        .expect("scope");

        assert_eq!(
            scope,
            SelectedVideoMemoryScope {
                storyboard_ids: "12".to_string(),
                prompt_seed: Some("seed-12-current".to_string()),
            }
        );
    }

    #[test]
    fn selected_video_memory_scope_distinguishes_prompt_seed_variants() {
        let current = selected_video_memory_scope(
            "storyboardIds=12 | promptSeed=seed-current | note=主角回头",
        )
        .expect("current scope");
        let stale =
            selected_video_memory_scope("storyboardIds=12 | promptSeed=seed-stale | note=主角回头")
                .expect("stale scope");
        let unseeded =
            selected_video_memory_scope("storyboardIds=12 | note=主角回头").expect("unseeded");

        assert_ne!(current, stale);
        assert_ne!(current, unseeded);
        assert_ne!(stale, unseeded);
    }

    #[test]
    fn select_neighbor_selected_video_memory_notes_prefers_nearest_storyboards() {
        let notes = select_neighbor_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=5 | style=镜头中景慢推，情绪压迫，光影暖金逆光 | note=主角推门而入，镜头中景慢推，情绪压迫，光影暖金逆光".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=16 | style=镜头中景稳定跟拍，情绪冷峻，光影冷色夜景 | note=反派逼近，镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=11 | style=镜头近景稳定跟拍，情绪压迫 | note=女主贴墙前行，镜头近景稳定跟拍，情绪压迫".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | note=当前镜头已确认".into(),
                },
            ],
            12,
            2,
        );

        assert_eq!(
            notes,
            vec![
                "镜头近景稳定跟拍，情绪压迫".to_string(),
                "镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".to_string()
            ]
        );
    }

    #[test]
    fn select_prioritized_video_style_note_keeps_neighbor_selected_style_when_current_seed_differs()
    {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、压迫、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };
        let note = select_prioritized_video_style_note(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪压迫 | note=女主贴墙前行，镜头近景稳定跟拍，情绪压迫".into(),
            }],
            12,
            Some("current-seed-9999"),
            Some(&storyboard_row),
        );

        assert_eq!(note, Some("镜头稳定跟拍，情绪压迫".to_string()));
    }

    #[test]
    fn select_prioritized_video_style_note_prefers_role_summary_when_neighbor_style_is_only_adjacent_carryover(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主含泪开口".into()),
            video_desc: Some("（女主含泪开口、旧宅走廊、女主、5秒、近景、稳定跟拍、呼吸发颤后哽咽开口、克制 / 哽咽、冷调逆光、你别走、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
        let note = select_prioritized_video_style_note(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=11 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，语气轻声克制 | note=女主贴墙前行，镜头近景稳定跟拍，情绪克制，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=女主 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
                },
            ],
            12,
            Some("current-seed-9999"),
            Some(&storyboard_row),
        );

        assert_eq!(note, Some("表演呼吸发颤，语气哽咽克制".to_string()));
    }

    #[test]
    fn select_prioritized_video_style_note_prefers_role_delivery_profile_for_dialogue_scene() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主低声开口".into()),
            video_desc: Some("（女主低声开口、旧宅走廊、女主、5秒、近景、稳定跟拍、喉结滚动后低声说你先走、克制、冷调逆光、你先走、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
        let note = select_prioritized_video_style_note(
            &[AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=女主 | sampleCount=4 | style=表演喉结滚动，语气低声尾音发颤，声场雨声回响 | delivery=表演喉结滚动低声尾音发颤".into(),
            }],
            12,
            Some("current-seed-9999"),
            Some(&storyboard_row),
        );

        assert_eq!(note, Some("表演喉结滚动低声尾音发颤".to_string()));
    }

    #[test]
    fn select_prioritized_video_style_note_prefers_fragile_role_summary_for_broken_breath_turn() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主抽气后失声开口".into()),
            video_desc: Some("（女主抽气后失声开口、旧宅走廊、女主、5秒、近景、稳定跟拍、抽气后失声开口、压抑、冷调逆光、我没事、雨声回响、A13）".into()),
            duration: Some("5s".into()),
        };
        let note = select_prioritized_video_style_note(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，语气轻声克制 | note=女主贴墙前行，镜头近景稳定跟拍，情绪克制，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=女主 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
                },
            ],
            13,
            Some("current-seed-0002"),
            Some(&storyboard_row),
        );

        assert_eq!(note, Some("表演呼吸发颤，语气哽咽克制".to_string()));
    }

    #[test]
    fn select_prioritized_video_style_note_prefers_primary_subject_role_summary_when_multiple_roles_match(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚与顾承泽擦肩后强忍泪意".into()),
            video_desc: Some("（林晚与顾承泽擦肩后强忍泪意、雨夜门厅、林晚/顾承泽、5秒、近景、稳定跟拍、林晚抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A14）".into()),
            duration: Some("5s".into()),
        };
        let note = select_prioritized_video_style_note(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=13 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，光影冷调逆光 | note=顾承泽逼近后停步，镜头近景稳定跟拍，情绪克制，光影冷调逆光".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=6 | style=表演冷眼逼视，语气低声压迫 | note=表演冷眼逼视，语气低声压迫".into(),
                },
            ],
            14,
            Some("current-seed-0003"),
            Some(&storyboard_row),
        );

        assert_eq!(note, Some("表演抬眼停顿，语气轻声克制".to_string()));
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_keeps_matching_storyboard_only() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=9 | rejectionCount=3 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flat cold lighting, avoid oppressive or frantic mood"]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_skips_single_rejection_noise() {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                    .into(),
            }],
            12,
            None,
        );

        assert!(notes.is_empty());
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_keeps_two_strongest_fragments() {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting, avoid shaky handheld motion".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_combines_multiple_rows_without_extra_budget() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=4 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_prefers_matching_role() {
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | rejectionCount=3 | avoid=avoid lip-sync mismatch".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            None,
        );

        assert_eq!(notes, vec!["avoid identity drift".to_string()]);
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_prefers_primary_subject_when_multiple_roles_match(
    ) {
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            12,
            None,
            &[
                "林晚".to_string(),
                "晚晚".to_string(),
                "顾承泽".to_string(),
                "顾总".to_string(),
            ],
            None,
        );

        assert!(notes.iter().any(|note| note.contains("blank expression")));
        assert_eq!(
            notes
                .iter()
                .filter(|note| {
                    note.contains("lip-sync mismatch")
                        || note.contains("face distortion or identity drift")
                })
                .count(),
            0
        );
    }

    #[test]
    fn select_rejected_video_memory_notes_and_observation_candidates_for_subject_splits_confidence_paths(
    ) {
        let selection =
            select_rejected_video_memory_notes_and_observation_candidates_for_subject(
                &[
                    AgentMemoryRow {
                        name: "rejected_video_negative_memory".into(),
                        content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
                    },
                    AgentMemoryRow {
                        name: "rejected_video_negative_memory".into(),
                        content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                    },
                    AgentMemoryRow {
                        name: "rejected_video_negative_memory".into(),
                        content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
                    },
                ],
                12,
                None,
                &[
                    "林晚".to_string(),
                    "晚晚".to_string(),
                    "顾承泽".to_string(),
                    "顾总".to_string(),
                ],
                None,
            );

        assert_eq!(
            selection.negative_notes,
            vec!["avoid face distortion or identity drift".to_string()]
        );
        assert_eq!(
            selection.observation_notes,
            vec!["avoid blank expression or monotone delivery".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_can_fallback_to_same_role_matching_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚抬眼后低声开口".into()),
            video_desc: Some(
                "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=motion/framing | avoid=avoid shaky handheld motion".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid blank expression or monotone delivery".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_keeps_risk_fallback_when_exact_row_is_only_pending(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚抬眼后低声开口".into()),
            video_desc: Some(
                "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid blank expression or monotone delivery".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_prioritizes_matching_fragment_for_scene_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头盯住来人".into()),
            video_desc: Some(
                "（晚晚回头盯住来人、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=15 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/lighting | avoid=avoid flat cold lighting, avoid face distortion or identity drift".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid face distortion or identity drift, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_for_subject_can_fallback_to_same_role_identity_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头看向镜头".into()),
            video_desc: Some(
                "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid face distortion or identity drift".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_deduplicates_weaker_family_across_rows() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flicker".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flicker or motion jitter, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_drops_repeat_follow_when_handheld_warning_exists(
    ) {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid repeating stable follow camera"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=3 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_drops_generic_style_fillers_for_high_signal_visual_guard(
    ) {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid face distortion, identity drift, costume drift, avoid extreme camera angle, avoid flat cold lighting".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid face distortion, identity drift, costume drift".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_parses_ascii_and_cjk_delimiters() {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker；avoid flat cold lighting, avoid harsh backlight silhouette".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flicker or motion jitter, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_note_reads_single_rejection_noise() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion, avoid flat cold lighting".into(),
            }],
            12,
            None,
        );

        assert_eq!(note, Some("avoid shaky handheld motion".into()));
    }

    #[test]
    fn select_pending_rejected_video_observation_note_skips_promoted_noise() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion"
                    .into(),
            }],
            12,
            None,
        );

        assert_eq!(note, None);
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_for_subject_prefers_matching_role() {
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | rejectionCount=1 | avoid=avoid lip-sync mismatch".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            None,
        );

        assert_eq!(notes, vec!["avoid identity drift".to_string()]);
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_prefers_primary_subject_when_multiple_roles_match(
    ) {
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            12,
            None,
            &[
                "林晚".to_string(),
                "晚晚".to_string(),
                "顾承泽".to_string(),
                "顾总".to_string(),
            ],
            None,
        );

        assert_eq!(
            notes.first().map(String::as_str),
            Some("avoid blank expression or monotone delivery")
        );
        assert_eq!(
            notes
                .iter()
                .filter(|note| {
                    note.contains("lip-sync mismatch")
                        || note.contains("face distortion or identity drift")
                })
                .count(),
            0
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_can_fallback_to_same_role_matching_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚抬眼后低声开口".into()),
            video_desc: Some(
                "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=motion/framing | avoid=avoid shaky handheld motion".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid blank expression or monotone delivery".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_prioritizes_matching_fragment_for_scene_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚压住情绪低声开口".into()),
            video_desc: Some(
                "（晚晚盯着门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
            }],
            12,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec![
                "avoid blank expression or monotone delivery".to_string(),
                "avoid flat cold lighting".to_string()
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_can_fallback_to_same_role_identity_risk(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头看向镜头".into()),
            video_desc: Some(
                "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid face distortion or identity drift".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_summary_prefers_performance_guard_over_higher_sample_lighting(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚压住情绪低声开口".into()),
            video_desc: Some(
                "（晚晚盯着门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "script_video_observation_memory".into(),
                    content: "sampleCount=9 | riskTags=lighting | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=2 | riskTags=performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            12,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid blank expression or monotone delivery".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_summary_prefers_role_summary_over_project_generic_fill(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "project_video_observation_memory".into(),
                    content: "sampleCount=8 | riskTags=identity/lighting | avoid=avoid flat cold lighting, avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec![
                "avoid blank expression or monotone delivery".to_string(),
                "avoid face distortion or identity drift".to_string()
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_summary_prefers_primary_subject_role_summary_when_multiple_roles_match(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_pending_rejected_video_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=6 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch, avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | riskTags=identity/dialogue/performance | avoid=avoid blank expression or monotone delivery".into(),
                },
            ],
            15,
            None,
            &[
                "林晚".to_string(),
                "晚晚".to_string(),
                "顾承泽".to_string(),
                "顾总".to_string(),
            ],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes.first().map(String::as_str),
            Some(
                "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
            )
        );
        assert_eq!(notes.get(1).map(String::as_str), None);
    }

    #[test]
    fn merge_rejected_video_negative_memory_accumulates_rejection_count_and_deduplicates() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid flat cold lighting",
            "storyboardIds=12 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/emotion | avoid=avoid flat cold lighting, avoid oppressive or frantic mood",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("storyboardIds=12"));
        assert!(merged.contains("subject=晚晚"));
        assert!(merged.contains("subjectAliases=林晚"));
        assert!(merged.contains("riskTags=emotion/lighting/motion"));
        assert!(merged.contains("avoid=avoid shaky handheld motion, avoid flat cold lighting"));
        assert!(!merged.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_resets_when_prompt_seed_changes() {
        let incoming =
            "storyboardIds=12 | promptSeed=newseed000002 | rejectionCount=1 | avoid=avoid flat cold lighting";
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=3 | avoid=avoid shaky handheld motion, avoid oppressive or frantic mood",
            incoming,
        );

        assert_eq!(merged, incoming);
        assert_eq!(rejected_video_negative_rejection_count(&merged), 1);
        assert!(merged.contains("promptSeed=newseed000002"));
        assert!(!merged.contains("avoid shaky handheld motion"));
    }

    #[test]
    fn storyboard_prompt_seed_changes_with_storyboard_version() {
        let first = storyboard_prompt_seed(&StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里冲出门外".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            duration: Some("5".into()),
        })
        .expect("first seed");
        let second = storyboard_prompt_seed(&StoryboardPromptSeedRow {
            prompt: Some("主角在楼梯口停步回望".into()),
            video_desc: Some("（主角停在楼梯口、旧宅楼梯、主角、5秒、近景、缓慢推进、停步回望、压迫、冷调逆光、无台词、风声、A12）".into()),
            duration: Some("5".into()),
        })
        .expect("second seed");

        assert_ne!(first, second);
    }

    #[test]
    fn select_selected_video_memory_notes_skips_stale_prompt_seed() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
            }],
            12,
            Some("newseed000002"),
        );

        assert!(notes.is_empty());
    }

    #[test]
    fn select_selected_video_memory_notes_falls_back_to_unseeded_when_current_seed_has_no_match() {
        let notes = select_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content:
                        "storyboardIds=12 | promptSeed=oldseed000001 | style=镜头冷调近景，情绪压迫"
                            .into(),
                },
            ],
            12,
            Some("newseed000002"),
        );

        assert_eq!(
            notes,
            vec!["镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_note_skips_stale_prompt_seed() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
            }],
            12,
            Some("newseed000002"),
        );

        assert_eq!(note, None);
    }

    #[test]
    fn select_pending_rejected_video_observation_note_falls_back_to_unseeded_when_current_seed_has_no_match(
    ) {
        let note = select_pending_rejected_video_observation_note(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            Some("newseed000002"),
        );

        assert_eq!(note, Some("avoid flicker or motion jitter".into()));
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_falls_back_to_unseeded_when_current_seed_has_no_match(
    ) {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            Some("newseed000002"),
        );

        assert_eq!(notes, vec!["avoid flicker or motion jitter".to_string()]);
    }

    #[test]
    fn select_pending_rejected_video_observation_note_prefers_stronger_camera_warning() {
        let note = select_pending_rejected_video_observation_note(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(note, Some("avoid shaky handheld motion".into()));
    }

    #[test]
    fn select_pending_rejected_video_observation_note_skips_single_low_signal_mood_retry() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid overly cold emotional tone"
                        .into(),
            }],
            12,
            None,
        );

        assert_eq!(note, None);
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_orders_by_strength() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting".to_string(),
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_keeps_secondary_fragment_from_same_row()
    {
        let notes = select_pending_rejected_video_observation_candidates(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid shaky handheld motion"
                        .into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting".to_string(),
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_deduplicates_weaker_family_member() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid flat cold lighting".to_string(),
                "avoid flicker or motion jitter".to_string(),
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_drops_repeat_follow_when_handheld_warning_exists(
    ) {
        let notes = select_pending_rejected_video_observation_candidates(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid repeating stable follow camera"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting".to_string(),
            ]
        );
    }

    #[test]
    fn compact_rejected_negative_avoid_preserves_original_order_for_same_priority() {
        let compacted = compact_rejected_negative_avoid(
            "avoid flat cold lighting, avoid harsh backlight silhouette, avoid oppressive or frantic mood",
        );

        assert_eq!(
            compacted,
            "avoid flat cold lighting or harsh backlight silhouette, avoid oppressive or frantic mood"
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_compacts_visual_style_family() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid harsh backlight silhouette"
                        .into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flat cold lighting or harsh backlight silhouette".to_string(),]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_compacts_visual_error_family() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid warped anatomy, avoid blur, avoid flicker"
                        .into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid warped anatomy, blur, flicker".to_string(),]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_parse_mixed_delimiters() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting；avoid harsh backlight silhouette, avoid shaky handheld motion".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting or harsh backlight silhouette".to_string(),
            ]
        );
    }

    #[test]
    fn merge_rejected_video_negative_memory_compacts_family_fragments() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid harsh backlight silhouette",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid=avoid flat cold lighting or harsh backlight silhouette"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_compacts_visual_error_family_fragments() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid warped anatomy, avoid blur",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid=avoid warped anatomy, blur, flicker"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_keeps_only_top_storage_fragments() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion, avoid flat cold lighting",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid oppressive or frantic mood",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid=avoid shaky handheld motion, avoid flat cold lighting"));
        assert!(!merged.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_prioritizes_character_consistency_over_mood() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion or identity drift, avoid flat cold lighting",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid oppressive or frantic mood",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid face distortion or identity drift"));
        assert!(!merged.contains("avoid flat cold lighting"));
        assert!(!merged.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_drops_generic_style_budget_fillers_when_high_signal_visual_guard_exists(
    ) {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion, identity drift, costume drift, avoid extreme camera angle",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
        assert!(!merged.contains("avoid extreme camera angle"));
        assert!(!merged.contains("avoid flat cold lighting"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_keeps_performance_guard_when_high_signal_visual_guard_exists(
    ) {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion, identity drift, costume drift",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid blank expression or monotone delivery, avoid flat cold lighting",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
        assert!(merged.contains("avoid blank expression or monotone delivery"));
        assert!(!merged.contains("avoid flat cold lighting"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_parses_ascii_and_cjk_delimiters() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting；avoid harsh backlight silhouette",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("avoid flicker or motion jitter"));
        assert!(merged.contains("avoid flat cold lighting or harsh backlight silhouette"));
    }

    #[test]
    fn build_script_video_observation_memory_summarizes_recurring_failure_guards() {
        let summary = build_script_video_observation_memory(&[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid flat cold lighting".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=10 | rejectionCount=3 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid harsh backlight silhouette".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=11 | rejectionCount=2 | riskTags=motion | avoid=avoid shaky handheld motion".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"), "{summary}");
        assert!(summary.contains("riskTags=motion/lighting"), "{summary}");
        assert!(
            summary.contains("avoid=avoid shaky handheld motion"),
            "{summary}"
        );
        assert!(!summary.contains("harsh backlight"), "{summary}");
    }

    #[test]
    fn build_script_role_video_observation_memories_groups_subject_specific_failures() {
        let summaries = build_script_role_video_observation_memories(&[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=10 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            },
        ]);

        assert_eq!(summaries.len(), 1);
        let summary = &summaries[0];
        assert!(
            summary.contains("subject=林晚") || summary.contains("subject=晚晚"),
            "{summary}"
        );
        assert!(summary.contains("subjectAliases="), "{summary}");
        assert!(
            summary.contains("riskTags=dialogue/identity")
                || summary.contains("riskTags=identity/dialogue"),
            "{summary}"
        );
        assert!(summary.contains("avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery"), "{summary}");
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_can_fallback_to_role_observation_summary() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚低声回头".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec![
                "avoid face distortion or identity drift, avoid blank expression or monotone delivery"
                    .to_string()
            ]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_role_observation_summary_prioritizes_dialogue_guard_fragment_for_dialogue_scene(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid face distortion or identity drift, avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec![
                "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
                    .to_string()
            ]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_role_observation_summary_prioritizes_identity_guard_fragment_for_identity_scene(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头盯住镜头".into()),
            video_desc: Some(
                "（晚晚回头盯住镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid blank expression or monotone delivery, avoid face distortion or identity drift, avoid flat cold lighting".into(),
            }],
            15,
            None,
            &["晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec!["avoid face distortion or identity drift, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_role_observation_summary_prefers_primary_subject_when_multiple_roles_match(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚停住呼吸看向顾承泽".into()),
            video_desc: Some(
                "（晚晚停在落地窗边、雨夜办公室、林晚/晚晚/顾承泽、4秒、近景、慢推、抬眼停顿后低声开口、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
        let notes = select_rejected_video_negative_memory_notes_for_subject(
            &[
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=6 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch, avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_observation_memory".into(),
                    content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | riskTags=identity/dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid face distortion or identity drift".into(),
                },
            ],
            15,
            None,
            &[
                "林晚".to_string(),
                "晚晚".to_string(),
                "顾承泽".to_string(),
                "顾总".to_string(),
            ],
            Some(&storyboard_row),
        );

        assert_eq!(
            notes,
            vec![
                "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
                    .to_string()
            ]
        );
    }

    #[test]
    fn build_script_video_style_memory_extracts_recurring_style_fragments() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯 | note=女主贴墙前行，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊 | note=反派逼近，镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("镜头稳定跟拍"));
        assert!(!summary.contains("中景"));
        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影冷调逆光"));
        assert!(!summary.contains("场景旧宅走廊"));
        assert!(!summary.contains("女主"));
    }

    #[test]
    fn build_script_video_style_memory_extracts_recurring_style_fragments_from_ascii_delimiters() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"));
    }

    #[test]
    fn build_script_video_style_memory_keeps_recurring_environment_fragment() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，情绪克制，环境雨丝玻璃 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，情绪克制，环境雨丝玻璃 | note=..."
                        .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("环境雨丝玻璃"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_keeps_recurring_motion_fragment() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，动作从容克制，情绪克制 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，动作从容克制，情绪隐忍 | note=..."
                        .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("动作从容克制"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_keeps_recurring_voice_and_sound_fragments() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，语气轻声克制，声场雨声回响 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍，语气轻声克制，声场雨声回响 | note=..."
                    .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("语气轻声克制"), "{summary}");
        assert!(summary.contains("声场雨声回响"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_keeps_recurring_performance_fragment() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，表演抬眼停顿，情绪克制 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，表演抬眼停顿，情绪隐忍 | note=..."
                        .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("表演抬眼停顿"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists(
    ) {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作从容克制，声场静场留白 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍，表演呼吸发颤，语气轻声克制，情绪隐忍，动作从容克制，声场静场留白 | note=..."
                    .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("表演呼吸发颤"), "{summary}");
        assert!(summary.contains("声场静场留白"), "{summary}");
        assert!(!summary.contains("语气轻声克制"), "{summary}");
        assert!(!summary.contains("情绪克制"), "{summary}");
        assert!(!summary.contains("情绪隐忍"), "{summary}");
        assert!(!summary.contains("动作从容克制"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_drops_ambient_sound_when_visual_and_performance_fragments_exist(
    ) {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，表演喉结滚动，光影冷蓝窗光，环境雨丝玻璃，声场雨声回响 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍，表演喉结滚动，光影冷蓝窗光，环境雨丝玻璃，声场雨声回响 | note=..."
                    .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("表演喉结滚动"), "{summary}");
        assert!(summary.contains("光影冷蓝窗光"), "{summary}");
        assert!(summary.contains("环境雨丝玻璃"), "{summary}");
        assert!(!summary.contains("声场雨声回响"), "{summary}");
    }

    #[test]
    fn build_script_video_style_memory_drops_character_signature_fragments_when_subjects_mix() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景稳定跟拍，表演抬眼停顿，语气轻声克制，光影冷调逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("镜头稳定跟拍"), "{summary}");
        assert!(summary.contains("光影冷调逆光"), "{summary}");
        assert!(!summary.contains("表演抬眼停顿"), "{summary}");
        assert!(!summary.contains("语气轻声克制"), "{summary}");
    }

    #[test]
    fn build_script_role_video_style_memories_groups_persona_by_subject() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=晚晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气低声克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=24 | subject=顾承泽 | style=动作从容克制".into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec![
                "subject=林晚 | sampleCount=2 | subjectAliases=晚晚 | style=表演抬眼停顿"
                    .to_string()
            ]
        );
    }

    #[test]
    fn build_project_role_video_style_memories_keep_subjects_isolated_across_scripts() {
        let summaries = build_project_role_video_style_memories(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制"
                    .into(),
                episodes_id: Some(7),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=晚晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气低声克制"
                    .into(),
                episodes_id: Some(8),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=21 | subject=顾承泽 | style=动作从容克制".into(),
                episodes_id: Some(8),
            },
        ]);

        assert_eq!(
            summaries,
            vec![
                "subject=林晚 | sampleCount=2 | subjectAliases=晚晚 | style=表演抬眼停顿"
                    .to_string()
            ]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_prefers_most_supported_voice_variant() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，语气轻声克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，语气低声克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=24 | subject=林晚 | style=表演抬眼停顿，语气低声克制"
                    .into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=3 | style=表演抬眼停顿".to_string()]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_keep_fragile_voice_when_it_carries_emotional_turn() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=表演呼吸发颤，语气哽咽克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=表演呼吸发颤，语气哽咽克制"
                    .into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=2 | style=表演呼吸发颤，语气哽咽克制 | delivery=表演呼吸发颤哽咽克制".to_string()]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_keep_high_signal_tail_tremble_voice_variant() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声尾音发颤"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=表演抿唇停顿，语气低声尾音发颤"
                    .into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=2 | style=语气低声尾音发颤".to_string()]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_drop_camera_shell_when_character_signal_exists() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=镜头稳定跟拍，表演抬眼停顿，情绪克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=镜头近景稳定跟拍，表演抬眼停顿，情绪隐忍"
                    .into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=2 | style=表演抬眼停顿".to_string()]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_skip_camera_only_role_memory() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=镜头稳定跟拍".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=镜头近景稳定跟拍".into(),
            },
        ]);

        assert!(summaries.is_empty(), "{summaries:?}");
    }

    #[test]
    fn build_script_role_video_style_memories_skip_scene_shell_without_character_signal() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=光影冷调逆光，声场雨声回响"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=光影冷调逆光，环境雨丝玻璃"
                    .into(),
            },
        ]);

        assert!(summaries.is_empty(), "{summaries:?}");
    }

    #[test]
    fn build_script_role_video_style_memories_drop_generic_restrained_mood_when_performance_exists()
    {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，情绪克制".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，情绪隐忍".into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=2 | style=表演抬眼停顿".to_string()]
        );
    }

    #[test]
    fn build_script_role_video_style_memories_keep_distinct_intense_mood_when_performance_exists() {
        let summaries = build_script_role_video_style_memories(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，情绪冷峻压迫"
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，情绪冷峻压迫"
                    .into(),
            },
        ]);

        assert_eq!(
            summaries,
            vec!["subject=林晚 | sampleCount=2 | style=情绪冷峻压迫，表演抬眼停顿".to_string()]
        );
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_matches_subject_aliases() {
        let notes = select_subject_role_video_style_memory_notes(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制"
                        .into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=顾承泽 | sampleCount=3 | style=动作从容克制，语气低声克制"
                        .into(),
                },
            ],
            &["晚晚".to_string()],
        );

        assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_prefers_script_scope_over_project_scope() {
        let notes = select_subject_role_video_style_memory_notes(
            &[
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=5 | style=动作从容克制，语气低声克制"
                        .into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制"
                        .into(),
                },
            ],
            &["林晚".to_string()],
        );

        assert_eq!(
            notes,
            vec!["表演抬眼停顿，语气轻声克制，动作从容克制".to_string()]
        );
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_merges_project_fill_only_when_axis_is_missing()
    {
        let notes = select_subject_role_video_style_memory_notes(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制"
                        .into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=5 | style=动作从容克制，语气低声克制，光影冷蓝窗光"
                        .into(),
                },
            ],
            &["林晚".to_string()],
        );

        assert_eq!(
            notes,
            vec!["表演抬眼停顿，语气轻声克制，动作从容克制，光影冷蓝窗光".to_string()]
        );
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_skips_low_support_generic_project_fill() {
        let notes = select_subject_role_video_style_memory_notes(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制"
                        .into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=2 | style=动作从容克制，语气低声克制，光影冷蓝窗光"
                        .into(),
                },
            ],
            &["林晚".to_string()],
        );

        assert_eq!(
            notes,
            vec!["表演抬眼停顿，语气轻声克制，光影冷蓝窗光".to_string()]
        );
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_keeps_supported_generic_project_fill() {
        let notes = select_subject_role_video_style_memory_notes(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿".into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=林晚 | sampleCount=4 | style=动作从容克制，语气低声克制"
                        .into(),
                },
            ],
            &["林晚".to_string()],
        );

        assert_eq!(
            notes,
            vec!["表演抬眼停顿，动作从容克制，语气低声克制".to_string()]
        );
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_for_storyboard_drops_mismatched_soft_voice() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚抽气后失声开口".into()),
            video_desc: Some("（林晚抽气后失声开口、雨夜门厅、林晚、5秒、近景、稳定跟拍、抽气后失声开口、压抑、冷调逆光、我没事、雨声回响、A13）".into()),
            duration: Some("5s".into()),
        };

        let notes = select_subject_role_video_style_memory_notes_for_storyboard(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制".into(),
                },
            ],
            &["林晚".to_string(), "晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(notes, vec!["表演呼吸发颤，语气哽咽克制".to_string()]);
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_for_storyboard_prefers_delivery_profile_for_visible_speech(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚低声开口".into()),
            video_desc: Some("（林晚低声开口、雨夜门厅、林晚、5秒、近景、稳定跟拍、喉结滚动后低声说我没事、压抑克制、冷调逆光、我没事、雨声回响、A13）".into()),
            duration: Some("5s".into()),
        };

        let notes = select_subject_role_video_style_memory_notes_for_storyboard(
            &[AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演喉结滚动，语气低声尾音发颤，声场雨声回响 | delivery=表演喉结滚动低声尾音发颤".into(),
            }],
            &["林晚".to_string(), "晚晚".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(notes, vec!["表演喉结滚动低声尾音发颤".to_string()]);
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_for_storyboard_keeps_no_context_behavior() {
        let notes = select_subject_role_video_style_memory_notes_for_storyboard(
            &[AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            }],
            &["晚晚".to_string()],
            None,
        );

        assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
    }

    #[test]
    fn select_subject_role_video_style_memory_notes_for_storyboard_prefers_primary_subject_when_multiple_roles_match(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚与顾承泽擦肩后强忍泪意".into()),
            video_desc: Some("（林晚与顾承泽擦肩后强忍泪意、雨夜门厅、林晚/顾承泽、5秒、近景、稳定跟拍、林晚抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A13）".into()),
            duration: Some("5s".into()),
        };

        let notes = select_subject_role_video_style_memory_notes_for_storyboard(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "project_role_video_style_memory".into(),
                    content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=6 | style=表演冷眼逼视，语气低声压迫".into(),
                },
            ],
            &["林晚".to_string(), "顾承泽".to_string()],
            Some(&storyboard_row),
        );

        assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
    }

    #[test]
    fn selected_memory_subject_identity_prefers_subject_refs_name() {
        assert_eq!(
            selected_memory_subject_identity("女主站在窗边", "林晚/咖啡杯"),
            Some("林晚".to_string())
        );
    }

    #[test]
    fn selected_memory_subject_aliases_trim_descriptive_subject_and_drop_prop_refs() {
        assert_eq!(
            selected_memory_subject_aliases("林晚站在窗边", "林晚站在窗边/晚晚/咖啡杯"),
            vec!["林晚".to_string(), "晚晚".to_string()]
        );
    }

    #[test]
    fn selected_memory_subject_aliases_trim_dialogue_or_action_tails() {
        assert_eq!(
            selected_memory_subject_aliases("晚晚低声开口", "林晚轻声说道/晚晚低声开口"),
            vec!["林晚".to_string(), "晚晚".to_string()]
        );
    }

    #[test]
    fn selected_memory_subject_aliases_keep_generic_role_when_followed_by_action() {
        assert_eq!(
            selected_memory_subject_aliases("主角推门回望", "主角推门回望/门厅"),
            vec!["主角".to_string()]
        );
    }

    #[test]
    fn compact_video_style_prompt_note_trims_keyword_covered_mood_and_lighting_suffix_noise() {
        let note = compact_video_style_prompt_note("情绪紧张压迫感，光影冷调逆光颗粒")
            .expect("style note");

        assert_eq!(note, "情绪紧张压迫，光影冷调逆光");
    }

    #[test]
    fn compact_video_style_prompt_note_keeps_partial_lighting_context_when_keyword_coverage_is_weak(
    ) {
        let note =
            compact_video_style_prompt_note("情绪克制，光影潮湿路灯暖光").expect("style note");

        assert_eq!(note, "情绪克制，光影潮湿路灯暖光");
    }

    #[test]
    fn compact_video_style_prompt_note_drops_generic_cold_mood_when_lighting_already_covers_it() {
        let note = compact_video_style_prompt_note("情绪冷调，光影冷调逆光").expect("style note");

        assert_eq!(note, "光影冷调逆光");
    }

    #[test]
    fn compact_video_style_prompt_note_keeps_distinct_mood_when_lighting_is_cold() {
        let note =
            compact_video_style_prompt_note("情绪冷峻压迫，光影冷调逆光").expect("style note");

        assert_eq!(note, "情绪冷峻压迫，光影冷调逆光");
    }

    #[test]
    fn compact_video_style_prompt_note_supports_ascii_delimiters() {
        let note = compact_video_style_prompt_note("镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光")
            .expect("style note");

        assert_eq!(note, "镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光");
    }

    #[test]
    fn compact_video_style_prompt_note_drops_generic_cold_mood_when_cold_lighting_is_more_specific()
    {
        let note = compact_video_style_prompt_note("情绪冷调，光影阴天冷光").expect("style note");

        assert_eq!(note, "光影阴天冷光");
    }

    #[test]
    fn select_script_video_style_memory_notes_reads_summary_note() {
        let notes = select_script_video_style_memory_notes(&[
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | note=别的内容".into(),
            },
        ]);

        assert_eq!(
            notes,
            vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn select_script_video_style_memory_notes_for_storyboard_prefers_delivery_profile_for_dialogue_scene(
    ) {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚喉头发紧后低声开口".into()),
            video_desc: Some("（林晚喉头发紧后低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、喉结滚动后低声开口、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };
        let notes = select_script_video_style_memory_notes_for_storyboard(
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演喉结滚动低声克制".into(),
            }],
            Some(&storyboard_row),
        );

        assert_eq!(notes, vec!["表演喉结滚动低声克制".to_string()]);
    }

    #[test]
    fn build_project_video_style_memory_extracts_cross_script_recurring_style() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，场景废弃走廊 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
        assert!(!summary.contains("中景"));
        assert!(!summary.contains("场景废弃走廊"));
    }

    #[test]
    fn build_script_video_style_memory_splits_visual_style_and_delivery_for_single_subject() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光，声场雨声回响 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头中景稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光，声场雨声回响 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(
            summary.contains("style=镜头稳定跟拍，光影冷蓝窗光"),
            "{summary}"
        );
        assert!(
            summary.contains("delivery=表演喉结滚动低声尾音发颤"),
            "{summary}"
        );
        assert!(!summary.contains("style=表演"), "{summary}");
        assert!(!summary.contains("style=语气"), "{summary}");
        assert!(!summary.contains("style=声场"), "{summary}");
    }

    #[test]
    fn build_project_video_style_memory_drops_character_signature_fragments_when_subjects_mix() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头近景稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("镜头稳定跟拍"), "{summary}");
        assert!(summary.contains("情绪冷峻压迫"), "{summary}");
        assert!(!summary.contains("表演抬眼停顿"), "{summary}");
        assert!(!summary.contains("语气轻声克制"), "{summary}");
    }

    #[test]
    fn build_project_video_style_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists(
    ) {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作自然，声场静场留白 | note=..."
                    .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头近景稳定跟拍，表演呼吸发颤，语气轻声克制，情绪隐忍，动作自然，声场静场留白 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作自然，声场静场留白 | note=..."
                    .into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("表演呼吸发颤"), "{summary}");
        assert!(summary.contains("声场静场留白"), "{summary}");
        assert!(!summary.contains("语气轻声克制"), "{summary}");
        assert!(!summary.contains("情绪克制"), "{summary}");
        assert!(!summary.contains("情绪隐忍"), "{summary}");
        assert!(!summary.contains("动作自然"), "{summary}");
    }

    #[test]
    fn build_project_video_style_memory_drops_recurring_sound_when_subjects_mix() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                    .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | subject=沈砚 | subjectAliases=沈砚/阿砚 | style=镜头稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                    .into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("镜头稳定跟拍"), "{summary}");
        assert!(summary.contains("光影冷调逆光"), "{summary}");
        assert!(!summary.contains("声场雨声回响"), "{summary}");
    }

    #[test]
    fn build_project_video_style_memory_requires_majority_support_when_samples_are_dense() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头稳定跟拍，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=4 | style=镜头稳定跟拍，情绪悲怆，光影冷调逆光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=5 | style=镜头近景手持，情绪悲怆，光影暖光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=5"));
        assert!(summary.contains("style=镜头稳定跟拍，光影冷调逆光"));
        assert!(!summary.contains("情绪冷峻压迫"));
    }

    #[test]
    fn build_project_video_style_memory_prefers_latest_prompt_seed_within_each_script_storyboard() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(7),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(7),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000003 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(8),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000004 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(7),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("光影暖金逆光"));
        assert!(!summary.contains("光影冷调逆光"));
    }

    #[test]
    fn build_project_video_style_memory_caps_samples_per_script_to_reduce_single_script_bias() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=3 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=4 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=4"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
        assert!(!summary.contains("光影冷调逆光"));
        assert!(!summary.contains("光影暖金逆光"));
    }

    #[test]
    fn build_project_video_style_memory_drops_generic_cold_mood_if_lighting_already_carries_it() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("style=光影冷调逆光"));
        assert!(!summary.contains("情绪冷调"));
    }

    #[test]
    fn build_script_video_style_memory_drops_generic_cold_mood_if_specific_cold_lighting_already_carries_it(
    ) {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷调，光影阴天冷光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷调，光影阴天冷光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("style=光影阴天冷光"));
        assert!(!summary.contains("情绪冷调"));
    }

    #[test]
    fn build_script_video_style_memory_summarizes_recurring_keywords_from_variant_notes() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍，情绪紧张压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头低机位稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("style=镜头稳定跟拍"));
        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影阴天冷光"));
        assert!(!summary.contains("近景"));
        assert!(!summary.contains("低机位"));
    }

    #[test]
    fn build_script_video_style_memory_drops_recurring_local_framing_without_stable_shot_language()
    {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景，情绪紧张压迫，光影阴天冷光 | note=..."
                    .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影阴天冷光"));
        assert!(!summary.contains("镜头近景"));
    }

    #[test]
    fn build_script_video_style_memory_deduplicates_same_storyboard_prompt_seed_samples() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=重复确认同镜头".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"));
        assert!(!summary.contains("中景"));
    }

    #[test]
    fn build_script_video_style_memory_prefers_latest_prompt_seed_per_storyboard() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000003 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("光影暖金逆光"));
        assert!(!summary.contains("光影冷调逆光"));
    }

    #[test]
    fn build_script_video_style_memory_skips_low_support_keywords_when_note_pool_is_large() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=13 | style=情绪悲怆，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=14 | style=情绪悲怆，光影暖光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=4"));
        assert!(summary.contains("style=光影冷调逆光"));
        assert!(!summary.contains("情绪冷峻压迫"));
        assert!(!summary.contains("情绪悲怆"));
    }

    #[test]
    fn build_script_video_style_memory_drops_generic_cold_mood_if_lighting_already_carries_it() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷调，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷调，光影冷调逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("style=光影冷调逆光"));
        assert!(!summary.contains("情绪冷调"));
    }

    #[test]
    fn select_project_video_style_memory_notes_reads_summary_note() {
        let notes = select_project_video_style_memory_notes(&[
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪冷峻压迫 | note=镜头稳定跟拍，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=镜头近景手持 | note=镜头近景手持".into(),
            },
        ]);

        assert_eq!(notes, vec!["镜头稳定跟拍，情绪冷峻压迫".to_string()]);
    }

    #[test]
    fn select_project_video_style_memory_notes_for_storyboard_prefers_delivery_on_fragile_turn() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚终于哽咽开口".into()),
            video_desc: Some("（林晚终于哽咽开口、病房窗边、林晚、4秒、近景、缓推、呼吸发颤后哽咽开口、哽咽压抑、冷蓝窗光、我没事、静场留白、A13）".into()),
            duration: Some("4s".into()),
        };
        let notes = select_project_video_style_memory_notes_for_storyboard(
            &[AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演呼吸发颤哽咽克制".into(),
            }],
            Some(&storyboard_row),
        );

        assert_eq!(notes, vec!["表演呼吸发颤哽咽克制".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_drop_scene_fragments_from_prompt_style_memory() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=...".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn select_selected_video_memory_notes_drop_local_framing_when_other_style_fragments_exist() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                    .into(),
            }],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪冷峻压迫，光影阴天冷光".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_keep_local_framing_when_it_is_only_style_signal() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头近景 | note=...".into(),
            }],
            12,
            None,
        );

        assert_eq!(notes, vec!["镜头近景".to_string()]);
    }

    #[test]
    fn compact_video_continuity_note_keeps_only_style_and_continuity_fragments() {
        let note = compact_video_continuity_note(
            "女主推门冲出；保持冷调压迫感；镜头中景稳定跟拍；后续反派从暗处逼近",
        )
        .expect("note");

        assert_eq!(note, "保持冷调压迫感，镜头中景稳定跟拍");
        assert!(!note.contains("反派"));
    }

    #[test]
    fn compact_video_continuity_note_supports_ascii_delimiters_and_drops_unrelated_fragments() {
        let note = compact_video_continuity_note(
            "后续反派从暗处逼近, 保持冷调压迫感; 镜头中景稳定跟拍\n无关素材提示",
        )
        .expect("note");

        assert_eq!(note, "保持冷调压迫感，镜头中景稳定跟拍");
        assert!(!note.contains("反派"));
        assert!(!note.contains("素材"));
    }

    #[tokio::test]
    async fn clear_selected_video_memory_ignores_invalid_storyboard_id() {
        let pool =
            PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
        let result = clear_selected_video_memory(&pool, Uuid::nil(), 1, 2, 0).await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn clear_rejected_video_negative_memory_ignores_invalid_storyboard_id() {
        let pool =
            PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
        let result = clear_rejected_video_negative_memory(&pool, Uuid::nil(), 1, 2, 0).await;

        assert!(result.is_ok());
    }
}
