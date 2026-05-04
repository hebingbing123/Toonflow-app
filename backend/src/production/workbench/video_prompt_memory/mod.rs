#![allow(
    clippy::manual_contains,
    clippy::manual_find,
    clippy::map_flatten,
    clippy::needless_range_loop,
    clippy::nonminimal_bool,
    clippy::obfuscated_if_else,
    clippy::question_mark,
    clippy::type_complexity,
    clippy::unnecessary_to_owned,
    clippy::if_same_then_else
)]

mod brief;
mod observation;
mod parsing;
mod rejected;
mod selected;
mod types;

use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

// Re-export public types
pub(crate) use types::{
    AgentMemoryRow, StoryboardPromptSeedRow, StructuredStoryboardDescription,
    VideoMemoryOptimizationResult,
};

// Re-export public parsing functions
pub(crate) use parsing::{
    clip_prompt_fragment, extract_key_value, normalize_prompt_text, parse_positive_int,
    parse_structured_storyboard_description,
};

#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use selected::{
    build_selected_video_memory, clear_selected_video_memory,
    compact_selected_video_memory_for_focus, optimize_scoped_video_memory,
    persist_selected_video_memory, refresh_script_video_style_memory,
    selected_video_memory_is_low_signal, split_prompt_note_fragments,
};
#[cfg_attr(not(test), allow(unused_imports))]
use selected::{
    compact_summary_video_style_memory_for_focus, load_project_video_memory_optimization_bias,
    load_selected_video_memory_optimization_bias, plan_selected_video_memory_optimization,
    prepare_selected_video_memory_for_storage, selected_video_memory_focus_tags_from_bias,
    selected_visual_only_memory_keep_priority,
};

// Import internal types for use within this module
use types::{
    EffectiveSelectedVideoMemoryOptimizationCandidate, OptimizableAgentMemoryRow,
    OptimizationQualityFocusDbRow, RankedStyleNote, RejectedStyleSignals, ScopedAgentMemoryRow,
    SelectedVideoMemoryOptimizationBias, SelectedVideoMemoryOptimizationCandidate,
    SelectedVideoMemoryOptimizationPlan, SelectedVideoMemoryScope, StyleNoteSelectionContext,
    SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY, SELECTED_VIDEO_MEMORY_FOCUS_EMOTION,
    SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY, SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING,
};

// Import internal parsing functions
use parsing::{extract_rejected_video_risk_tags, extract_storyboard_ids};

use crate::error::ApiError;
use brief::build_video_generation_brief_memory;
use observation::{
    build_project_role_video_observation_memories_with_bias,
    build_project_video_observation_memory_with_bias,
    build_script_role_video_observation_memories_with_bias,
    build_script_video_observation_memory_with_bias,
};
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use rejected::{
    build_rejected_video_negative_memory, clear_rejected_video_negative_memory,
    persist_rejected_video_negative_memory, rejected_video_negative_rejection_count,
    select_pending_rejected_video_observation_candidates,
    select_pending_rejected_video_observation_candidates_for_subject,
    select_pending_rejected_video_observation_candidates_for_subject_with_bias,
    select_pending_rejected_video_observation_note,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias,
    select_rejected_video_negative_memory_notes,
    select_rejected_video_negative_memory_notes_for_subject,
    select_rejected_video_negative_memory_notes_for_subject_with_bias,
    VideoPromptMemorySelectionBias,
};
#[cfg_attr(not(test), allow(unused_imports))]
use rejected::{
    compact_rejected_negative_avoid,
    compact_rejected_negative_memory_fragments_for_storage_with_bias,
    memory_subject_match_priority, merge_rejected_negative_avoid_with_bias,
    merge_rejected_video_negative_memory, observation_note_covers, observation_note_is_covered,
    prepare_rejected_video_negative_memory_for_storage, ranked_rejected_negative_fragments,
    score_rejected_negative_fragment, score_rejected_video_memory_bias_for_fragment,
    selected_optimization_bias_to_rejected_selection_bias,
};

const SELECTED_VIDEO_MEMORY_NAME: &str = "selected_video_memory";
const SCRIPT_VIDEO_STYLE_MEMORY_NAME: &str = "script_video_style_memory";
const PROJECT_VIDEO_STYLE_MEMORY_NAME: &str = "project_video_style_memory";
const SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME: &str = "script_video_generation_brief_memory";
const PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME: &str = "project_video_generation_brief_memory";
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
const SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_KEEP_ROWS: i64 = 1;
const PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_KEEP_ROWS: i64 = 1;
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
const STABLE_PROMPT_SHOT_KEYWORDS: [&str; 9] = [
    "远景",
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
const SUBJECT_IDENTITY_TAIL_MARKERS: [&str; 38] = [
    "站在", "停在", "坐在", "靠在", "倚在", "走向", "看向", "看着", "望向", "望着", "强忍", "抬眼",
    "垂眼", "低头", "回头", "停步", "对峙", "冲出", "逼近", "转身", "伸手", "抬手", "扶着", "扶住",
    "捧着", "握着", "拿着", "提着", "穿过", "轻声", "低声", "压低", "呢喃", "开口", "说着", "说道",
    "说出", "说",
];
const LOW_SIGNAL_SUBJECT_POSE_PREFIXES: [&str; 14] = [
    "站在",
    "站定",
    "看向",
    "看着",
    "望向",
    "望着",
    "坐在",
    "靠在",
    "倚在",
    "留在",
    "待在",
    "在镜前",
    "看向镜中",
    "看向镜",
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

pub(crate) async fn refresh_project_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<(), ApiError> {
    let optimization_bias =
        load_project_video_memory_optimization_bias(pool, user_id, project_numeric_id).await?;
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

    let summarized = build_project_video_style_memory_with_bias(
        &selected_rows,
        &rejected_rows,
        optimization_bias,
    );
    let observation_summary = build_project_video_observation_memory_with_bias(
        &rejected_rows,
        selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
    );
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
        PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME,
        build_video_generation_brief_memory(
            summarized.as_deref(),
            observation_summary.as_deref(),
            optimization_bias,
        )
        .as_deref(),
        PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_project_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_VIDEO_OBSERVATION_MEMORY_NAME,
        observation_summary.as_deref(),
        PROJECT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_project_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME,
        build_project_role_video_observation_memories_with_bias(
            &rejected_rows,
            selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
        ),
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
        .filter(|row| {
            matches!(
                row.name.as_str(),
                SCRIPT_VIDEO_STYLE_MEMORY_NAME | SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME
            )
        })
        .filter_map(|row| contextual_style_memory_value_for_storyboard(row, storyboard_row))
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
        .filter(|row| {
            matches!(
                row.name.as_str(),
                PROJECT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME
            )
        })
        .filter_map(|row| contextual_style_memory_value_for_storyboard(row, storyboard_row))
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
            if has_script_scope
                && scope_priority > 0
                && role_style_fragments_have_high_value_signal(&merged_fragments)
                && role_style_fragment_is_low_gain_carryover(fragment.as_str())
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

fn role_style_fragment_is_low_gain_carryover(fragment: &str) -> bool {
    if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_voice(&voice);
    }
    if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
        return selected_style_fragment_is_generic_restrained_mood(&mood);
    }
    if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_motion(&action);
    }
    false
}

fn role_style_fragments_have_high_value_signal(fragments: &[String]) -> bool {
    fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment
                .strip_prefix("语气")
                .map(normalize_prompt_text)
                .is_some_and(|voice| !selected_style_fragment_is_low_gain_voice(&voice))
            || fragment
                .strip_prefix("情绪")
                .map(normalize_prompt_text)
                .is_some_and(|mood| !selected_style_fragment_is_generic_restrained_mood(&mood))
            || fragment
                .strip_prefix("动作")
                .map(normalize_prompt_text)
                .is_some_and(|action| !selected_style_fragment_is_low_gain_motion(&action))
    })
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

#[allow(dead_code)]
pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_selected_video_memory_notes_for_storyboard(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        None,
    )
}

pub(crate) fn select_selected_video_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 {
        return Vec::new();
    }
    let should_prefer_delivery = should_prefer_selected_delivery_for_storyboard(storyboard_row);
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
        if should_prefer_delivery {
            if let Some(note) = selected_video_delivery_value_from_content(&row.content) {
                if style_notes.iter().all(|existing| existing != &note) {
                    style_notes.push(note);
                }
                continue;
            }
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
        if fragment.starts_with("表演") {
            score += 10;
        } else if fragment.starts_with("语气") {
            score += 9;
        } else if fragment.starts_with("情绪") {
            score += 7;
        } else if fragment.starts_with("光影") {
            score += 5;
        } else if fragment.starts_with("镜头") {
            score += if is_local_framing_only_fragment(fragment) {
                1
            } else {
                3
            };
        } else if fragment.starts_with("声场") {
            score += 4;
        } else if fragment.starts_with("动作") {
            score += 3;
        } else {
            score += 2;
        }
    }
    if count_selected_video_style_axes(note) >= 2 {
        score += 2;
    }
    if note_contains_selected_video_delivery_signal(&fragments) {
        score += 4;
    }
    if note_contains_selected_video_emotion_signal(&fragments) {
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
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("表演")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("语气")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("声场")),
    ]
    .into_iter()
    .filter(|present| *present)
    .count()
}

fn note_contains_selected_video_delivery_signal(fragments: &[String]) -> bool {
    fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"))
}

fn note_contains_selected_video_emotion_signal(fragments: &[String]) -> bool {
    fragments
        .iter()
        .any(|fragment| fragment.starts_with("情绪") || fragment.starts_with("表演"))
}

fn is_local_framing_only_fragment(fragment: &str) -> bool {
    fragment == "镜头近景"
        || fragment == "镜头中景"
        || fragment == "镜头远景"
        || fragment == "镜头特写"
        || fragment == "镜头全景"
}

#[allow(dead_code)]
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

fn selected_video_memory_scope(content: &str) -> Option<SelectedVideoMemoryScope> {
    let storyboard_ids = extract_key_value(content, "storyboardIds")?;
    Some(SelectedVideoMemoryScope {
        storyboard_ids,
        prompt_seed: extract_key_value(content, "promptSeed"),
    })
}

#[allow(dead_code)]
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

fn selected_memory_is_strong_identity_close_up(fields: &StructuredStoryboardDescription) -> bool {
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

fn selected_memory_voice_fragment_is_redundant_with_performance(
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
        || subject_hint.is_some_and(|hint| {
            let remainder = candidate.strip_prefix(hint).map(normalize_prompt_text);
            remainder
                .as_deref()
                .is_some_and(generic_subject_role_is_followed_by_actionish_fragment)
        })
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
                let note = extract_selected_memory_style_note_for_storyboard(row, storyboard_row);
                (120, note, selected_video_style_value(row))
            }
            SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (96, note.clone(), note)
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
            PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (76, note.clone(), note)
            }
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

fn extract_selected_memory_style_note_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    if should_prefer_selected_delivery_for_storyboard(storyboard_row) {
        if let Some(delivery) = selected_video_delivery_value_from_content(&row.content) {
            return Some(delivery);
        }
    }
    selected_video_style_value(row)
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

const ROLE_STYLE_VOICE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["低声", "压低声音", "低低开口"],
    &["轻声", "轻轻开口", "轻轻说道"],
    &["呢喃", "喃喃", "喃喃道", "喃喃说"],
    &["哽咽", "带着哽意", "声音发哽"],
    &["短促", "短促开口", "短促出声"],
];

const ROLE_STYLE_PERFORMANCE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["欲言又止", "欲说还休"],
    &["抬眼", "抬眸", "抬起眼"],
    &["停顿", "顿住", "停了停"],
    &["迟疑", "犹疑", "犹豫"],
    &["回头", "回眸", "回身看"],
    &["看向", "望向", "望着", "看着", "注视"],
    &["唇线收紧", "抿唇", "嘴唇抿紧", "唇角绷紧", "嘴角绷紧"],
    &["眉心轻蹙", "蹙眉", "眉头轻蹙", "眉心微蹙"],
];

fn role_style_note_matches_shared_keyword_family(
    note: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> bool {
    let normalized_note = normalize_prompt_text(note);
    if normalized_note.is_empty() {
        return false;
    }

    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    families.iter().any(|family| {
        family
            .iter()
            .any(|keyword| normalized_note.contains(keyword))
            && normalized_fields
                .iter()
                .any(|field| family.iter().any(|keyword| field.contains(keyword)))
    })
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
                || role_style_note_matches_shared_keyword_family(
                    fragment,
                    &[context.action.as_str(), context.dialogue.as_str()],
                    ROLE_STYLE_VOICE_SHARED_KEYWORD_FAMILIES,
                )
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
                || role_style_note_matches_shared_keyword_family(
                    fragment,
                    &[context.action.as_str(), context.dialogue.as_str()],
                    ROLE_STYLE_PERFORMANCE_SHARED_KEYWORD_FAMILIES,
                )
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

#[cfg_attr(not(test), allow(dead_code))]
fn build_script_video_style_memory(
    rows: &[AgentMemoryRow],
    rejected_rows: &[AgentMemoryRow],
) -> Option<String> {
    build_script_video_style_memory_with_bias(rows, rejected_rows, None)
}

fn build_script_video_style_memory_with_bias(
    rows: &[AgentMemoryRow],
    rejected_rows: &[AgentMemoryRow],
    optimization_bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
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
    let rejected_signals = summarize_rejected_style_signals(
        rejected_rows
            .iter()
            .map(|row| (row.name.as_str(), row.content.as_str(), None)),
    );
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    let delivery = summarize_role_delivery_fragment(&notes)
        .filter(|value| {
            global_delivery_fragment_is_worth_persisting(value, distinct_subject_group_count)
        })
        .filter(|value| {
            !delivery_fragment_conflicts_with_rejected_signals(value, &rejected_signals)
        })
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
    compact_summary_video_style_memory_for_focus(&parts.join(" | "), optimization_bias)
}

#[cfg_attr(not(test), allow(dead_code))]
fn build_project_video_style_memory(
    rows: &[ScopedAgentMemoryRow],
    rejected_rows: &[ScopedAgentMemoryRow],
) -> Option<String> {
    build_project_video_style_memory_with_bias(rows, rejected_rows, None)
}

fn build_project_video_style_memory_with_bias(
    rows: &[ScopedAgentMemoryRow],
    rejected_rows: &[ScopedAgentMemoryRow],
    optimization_bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
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
    let rejected_signals = summarize_rejected_style_signals(
        rejected_rows
            .iter()
            .map(|row| (row.name.as_str(), row.content.as_str(), row.episodes_id)),
    );
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    let delivery = summarize_role_delivery_fragment(&notes)
        .filter(|value| {
            global_delivery_fragment_is_worth_persisting(value, distinct_subject_group_count)
        })
        .filter(|value| {
            !delivery_fragment_conflicts_with_rejected_signals(value, &rejected_signals)
        })
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
    compact_summary_video_style_memory_for_focus(&parts.join(" | "), optimization_bias)
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

fn summarize_rejected_style_signals<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<i32>)>,
) -> RejectedStyleSignals {
    let mut signals = RejectedStyleSignals::default();
    for (name, content, _) in rows {
        if name != REJECTED_VIDEO_NEGATIVE_MEMORY_NAME {
            continue;
        }
        let rejection_count = extract_key_value(content, "rejectionCount")
            .and_then(|value| value.parse::<usize>().ok())
            .unwrap_or(1)
            .clamp(1, 4);
        let avoid = extract_key_value(content, "avoid").unwrap_or_default();
        if avoid.is_empty() {
            continue;
        }
        let add = |slot: &mut usize| *slot = slot.saturating_add(rejection_count);
        if avoid.contains("avoid blank expression or monotone delivery")
            || avoid.contains("avoid lip-sync mismatch")
        {
            add(&mut signals.monotone_delivery);
        }
        if avoid.contains("avoid flat cold lighting") {
            add(&mut signals.cold_lighting);
        }
        if avoid.contains("avoid harsh backlight silhouette") {
            add(&mut signals.harsh_backlight);
        }
        if avoid.contains("avoid repeating stable follow camera") {
            add(&mut signals.stable_follow_camera);
        }
        if avoid.contains("avoid shaky handheld motion") {
            add(&mut signals.shaky_handheld);
        }
        if avoid.contains("avoid oppressive mood")
            || avoid.contains("avoid oppressive or frantic mood")
        {
            add(&mut signals.oppressive_mood);
        }
        if avoid.contains("avoid overly cold emotional tone")
            || avoid.contains("avoid overly cold, oppressive, or frantic mood")
        {
            add(&mut signals.cold_emotional_tone);
        }
        if avoid.contains("avoid heavy tragic mood") {
            add(&mut signals.tragic_mood);
        }
    }
    signals
}

fn style_fragment_conflicts_with_rejected_signals(
    fragment: &str,
    signals: &RejectedStyleSignals,
) -> bool {
    if fragment.is_empty() {
        return false;
    }
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }
    if signals.monotone_delivery >= 2
        && (normalized.starts_with("语气低声克制")
            || normalized.starts_with("语气轻声克制")
            || normalized.starts_with("语气呢喃")
            || normalized == "情绪克制"
            || normalized == "情绪隐忍"
            || normalized == "情绪压抑")
    {
        return true;
    }
    if signals.cold_lighting >= 2
        && normalized.starts_with("光影")
        && (normalized.contains("冷调")
            || normalized.contains("冷光")
            || normalized.contains("冷蓝")
            || normalized.contains("冷色"))
    {
        return true;
    }
    if signals.harsh_backlight >= 2
        && normalized.starts_with("光影")
        && (normalized.contains("逆光")
            || normalized.contains("背光")
            || normalized.contains("剪影"))
    {
        return true;
    }
    if signals.stable_follow_camera >= 2
        && normalized.starts_with("镜头")
        && (normalized.contains("稳定跟拍")
            || normalized.contains("跟拍")
            || normalized.contains("推进")
            || normalized.contains("慢推"))
    {
        return true;
    }
    if signals.shaky_handheld >= 2 && normalized.starts_with("镜头") && normalized.contains("手持")
    {
        return true;
    }
    if signals.oppressive_mood >= 2
        && normalized.starts_with("情绪")
        && (normalized.contains("压迫")
            || normalized.contains("紧张")
            || normalized.contains("冷峻"))
    {
        return true;
    }
    if signals.cold_emotional_tone >= 2
        && normalized.starts_with("情绪")
        && (normalized.contains("冷调")
            || normalized.contains("冷色")
            || normalized.contains("冷峻")
            || normalized.contains("冷静"))
    {
        return true;
    }
    if signals.tragic_mood >= 2 && normalized.starts_with("情绪") && normalized.contains("悲怆")
    {
        return true;
    }
    false
}

fn delivery_fragment_conflicts_with_rejected_signals(
    fragment: &str,
    signals: &RejectedStyleSignals,
) -> bool {
    style_fragment_conflicts_with_rejected_signals(fragment, signals)
        || (signals.monotone_delivery >= 2
            && normalize_prompt_text(fragment).contains("克制")
            && !normalize_prompt_text(fragment).contains("发颤")
            && !normalize_prompt_text(fragment).contains("哽咽"))
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
            let (style, delivery) = if group.notes.len() >= 2 {
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
                (style, delivery)
            } else {
                let note = group.notes.first()?;
                single_sample_role_style_memory_seed(note)?
            };
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
            if let Some(delivery) = delivery
                .filter(|delivery| role_style_memory_should_persist_delivery(&style, delivery))
            {
                parts.push(format!("delivery={delivery}"));
            }
            Some(parts.join(" | "))
        })
        .collect()
}

fn role_style_memory_should_persist_delivery(style: &str, delivery: &str) -> bool {
    let has_visual_axis = split_prompt_note_fragments(style).any(|fragment| {
        fragment.starts_with("镜头")
            || fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || fragment.starts_with("声场")
    });
    has_visual_axis
        || delivery.contains("尾音")
        || delivery.contains("发颤")
        || delivery.contains("哽咽")
}

fn single_sample_role_style_memory_seed(note: &str) -> Option<(String, Option<String>)> {
    let style = selected_video_delivery_value_from_note(note)
        .or_else(|| compact_video_style_prompt_note(note))
        .filter(|value| single_sample_role_style_seed_is_high_signal(value))?;
    let delivery = selected_video_delivery_value_from_note(note)
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| value != &style)
        .filter(|value| single_sample_role_style_seed_is_high_signal(value));
    Some((style, delivery))
}

fn single_sample_role_style_seed_is_high_signal(note: &str) -> bool {
    split_prompt_note_fragments(note).any(|fragment| {
        if fragment.starts_with("表演") {
            [
                "抬眼",
                "垂眼",
                "眼神",
                "目光",
                "喉结",
                "唇线",
                "眉心",
                "嘴角",
                "下颌",
                "呼吸",
                "停顿",
                "发颤",
                "欲言又止",
                "强忍",
                "哽咽",
            ]
            .iter()
            .filter(|keyword| fragment.contains(**keyword))
            .count()
                >= 2
        } else if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            !role_voice_variant_is_low_gain_carryover(&voice)
        } else if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
            !global_mood_fragment_is_generic_restrained(&mood)
        } else {
            false
        }
    })
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
    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_visual_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("镜头")
    });

    let filtered = fragments
        .iter()
        .filter(|fragment| {
            !fragment.starts_with("表演")
                && !fragment.starts_with("语气")
                && !(fragment.starts_with("声场")
                    && has_performance_signal
                    && has_visual_signal
                    && fragment
                        .strip_prefix("声场")
                        .map(normalize_prompt_text)
                        .is_some_and(|sound| global_sound_fragment_is_low_gain_ambience(&sound)))
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

    let delivery = match (recurring_performance.as_deref(), recurring_voice.as_deref()) {
        (Some(performance), Some(voice)) => {
            compact_selected_memory_delivery_style(Some(performance), Some(voice))
                .or(recurring_performance)
                .or(recurring_voice)
        }
        (Some(_), None) => recurring_performance,
        (None, Some(_)) => recurring_voice,
        (None, None) => None,
    };

    delivery.filter(|fragment| global_delivery_fragment_is_high_signal(fragment))
}

fn global_delivery_fragment_is_worth_persisting(
    fragment: &str,
    distinct_subject_group_count: usize,
) -> bool {
    if fragment.is_empty() {
        return false;
    }
    if distinct_subject_group_count <= 1 {
        return true;
    }
    global_delivery_fragment_is_high_signal(fragment)
        && global_delivery_fragment_is_cross_subject_worth_persisting(fragment)
}

fn global_delivery_fragment_is_cross_subject_worth_persisting(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    normalized.contains("喉结")
        || normalized.contains("唇线")
        || normalized.contains("眉心")
        || normalized.contains("下颌")
        || normalized.contains("呼吸")
        || normalized.contains("发颤")
        || normalized.contains("尾音")
        || normalized.contains("哽咽")
}

fn global_delivery_fragment_is_high_signal(fragment: &str) -> bool {
    split_prompt_note_fragments(fragment).any(|fragment| {
        if fragment.starts_with("表演") {
            let keyword_hits = [
                "抬眼",
                "垂眼",
                "眼神",
                "目光",
                "喉结",
                "唇线",
                "眉心",
                "嘴角",
                "下颌",
                "呼吸",
                "停顿",
                "发颤",
                "欲言又止",
                "强忍",
                "哽咽",
            ]
            .iter()
            .filter(|keyword| fragment.contains(**keyword))
            .count();
            let strong_signal = [
                "喉结",
                "唇线",
                "眉心",
                "下颌",
                "呼吸",
                "发颤",
                "欲言又止",
                "强忍",
                "哽咽",
            ]
            .iter()
            .any(|keyword| fragment.contains(*keyword));
            (keyword_hits >= 1 && strong_signal)
                || (keyword_hits >= 2
                    && (fragment.contains("抬眼停顿") || fragment.contains("垂眼停顿")))
        } else if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            !role_voice_variant_is_low_gain_carryover(&voice)
        } else {
            false
        }
    })
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
    if fallback_shot.as_ref().is_some_and(|fragment| {
        selected_memory_high_signal_camera_fragment(fragment)
            && !fragments
                .iter()
                .any(|existing| existing.starts_with("镜头"))
    }) {
        fragments.push(fallback_shot.clone().expect("fallback shot present"));
    }

    if fragments.is_empty() {
        return fallback_shot;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn selected_memory_high_signal_camera_fragment(fragment: &str) -> bool {
    fragment.starts_with("镜头")
        && !is_local_framing_only_fragment(fragment)
        && ["低机位", "高机位", "俯拍", "仰拍", "压迫感", "窥视感"]
            .iter()
            .any(|keyword| fragment.contains(keyword))
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
        fragment.starts_with("表演") || fragment.starts_with("语气") || fragment.starts_with("动作")
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
        let performance_fragments = fragments
            .iter()
            .filter(|fragment| fragment.starts_with("表演"))
            .cloned()
            .collect::<Vec<_>>();
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice)
                    || !performance_fragments.iter().any(|performance| {
                        selected_memory_voice_fragment_is_redundant_with_performance(
                            performance,
                            &format!("语气{voice}"),
                            None,
                        )
                    });
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
                                && !low_signal_action_residue_fragment(fragment)
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
                            && !low_signal_object_hold_fragment(&fragment)
                            && !low_signal_action_residue_fragment(&fragment))
                        .then_some(fragment)
                    },
                )
            })
            .collect();
    }
    if subject_is_stored {
        if let Some(subject) = normalized_subject.as_deref() {
            if fragments.len() > 1
                && fragments
                    .first()
                    .is_some_and(|fragment| fragment == subject)
                && fragments.get(1).is_some()
            {
                let second = normalize_prompt_text(&fragments[1]);
                let keep_subject_separate = ["后", "回望", "回头", "转身", "停步"]
                    .iter()
                    .any(|keyword| second.contains(keyword));
                if keep_subject_separate {
                    // Keep explicit subject + follow-up action for residual beats like "主角，推门后回望".
                } else {
                    fragments[1] = format!("{subject}{second}");
                    fragments.remove(0);
                }
            }
            if fragments.len() == 1
                && !fragments[0].starts_with(subject)
                && (fragments[0].contains("推门") || fragments[0].contains("冲出"))
            {
                if fragments[0].contains("回望") || fragments[0].contains("回头") {
                    fragments.insert(0, subject.to_string());
                } else {
                    fragments[0] = format!("{subject}{}", fragments[0]);
                }
            }
            let original_fragments = fragments.clone();
            fragments = fragments
                .into_iter()
                .filter_map(|fragment| {
                    if fragment == subject {
                        return Some(fragment);
                    }
                    if fragment.starts_with(subject)
                        && fragment.chars().count() > subject.chars().count() + 1
                    {
                        let stripped = fragment
                            .strip_prefix(subject)
                            .map(normalize_prompt_text)
                            .unwrap_or_else(|| normalize_prompt_text(&fragment));
                        if stripped.is_empty()
                            || low_signal_subject_pose_fragment(&stripped)
                            || low_signal_object_hold_fragment(&stripped)
                            || low_signal_action_residue_fragment(&stripped)
                        {
                            return None;
                        }
                        if original_fragments
                            .iter()
                            .any(|other| other != &fragment && other.starts_with(&stripped))
                        {
                            return Some(stripped);
                        }
                        return Some(fragment);
                    }
                    let stripped = fragment
                        .strip_prefix(subject)
                        .map(normalize_prompt_text)
                        .unwrap_or(fragment);
                    let stripped = normalize_prompt_text(&stripped);
                    (!stripped.is_empty()
                        && !low_signal_subject_pose_fragment(&stripped)
                        && !low_signal_object_hold_fragment(&stripped)
                        && !low_signal_action_residue_fragment(&stripped))
                    .then_some(stripped)
                })
                .collect();
        }
    }
    fragments = compact_selected_memory_residual_fragments(fragments);
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_selected_memory_residual_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut compacted: Vec<String> = Vec::new();
    for fragment in fragments {
        let fragment = normalize_prompt_text(
            &fragment
                .replace("推门后推门", "推门")
                .replace("回头后回头", "回头")
                .replace("转身后转身", "转身"),
        );
        if fragment.is_empty() {
            continue;
        }
        if let Some(last) = compacted.last_mut() {
            if fragment.starts_with(last.as_str())
                && fragment.chars().count() > last.chars().count()
            {
                *last = fragment;
                continue;
            }
            if last.starts_with(fragment.as_str()) {
                continue;
            }
        }
        compacted.push(fragment);
    }
    compacted
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

fn low_signal_action_residue_fragment(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "缓缓" | "慢慢" | "轻轻" | "静静" | "默默" | "片刻" | "一下" | "一下子"
    )
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
            &[
                "抬眼后停顿片刻",
                "抬眼停顿",
                "抬眼",
                "停顿片刻",
                "迟迟没有开口",
                "没有开口",
            ],
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
            .replace("后后", "后")
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

fn selected_video_delivery_value_from_note(note: &str) -> Option<String> {
    let mut performance = None;
    let mut voice = None;
    for fragment in split_prompt_note_fragments(note) {
        if performance.is_none() && fragment.starts_with("表演") {
            performance = Some(fragment);
            continue;
        }
        if voice.is_none() && fragment.starts_with("语气") {
            voice = Some(fragment);
        }
    }

    match (performance.as_deref(), voice.as_deref()) {
        (Some(performance), Some(voice)) => {
            compact_selected_memory_delivery_style(Some(performance), Some(voice))
                .or_else(|| Some(performance.to_string()))
                .or_else(|| Some(voice.to_string()))
        }
        (Some(_), None) => performance,
        (None, Some(_)) => voice,
        (None, None) => None,
    }
}

fn delivery_style_value_from_content(content: &str) -> Option<String> {
    extract_key_value(content, "delivery")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

fn selected_video_delivery_value_from_content(content: &str) -> Option<String> {
    delivery_style_value_from_content(content)
        .or_else(|| {
            extract_key_value(content, "style")
                .and_then(|value| selected_video_delivery_value_from_note(&value))
        })
        .or_else(|| {
            extract_key_value(content, "note")
                .and_then(|value| selected_video_delivery_value_from_note(&value))
        })
        .filter(|value| !value.is_empty())
}

fn should_prefer_selected_delivery_for_storyboard(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    storyboard_row
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
        .unwrap_or(false)
}

fn summary_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    if !matches!(
        row.name.as_str(),
        SCRIPT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_STYLE_MEMORY_NAME
    ) {
        return selected_video_style_value(row);
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

    extract_key_value(&row.content, "style")
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !value.is_empty())
        .or_else(|| selected_video_style_value(row))
}

fn generation_brief_style_memory_value(row: &AgentMemoryRow) -> Option<String> {
    extract_key_value(&row.content, "style")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
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

pub(crate) fn contextual_style_memory_value_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    match row.name.as_str() {
        SCRIPT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_STYLE_MEMORY_NAME => {
            summary_style_memory_value_for_storyboard(row, storyboard_row)
        }
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME | PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
            generation_brief_style_memory_value(row)
        }
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => {
            role_style_memory_value_for_storyboard(row, storyboard_row)
        }
        _ => extract_selected_memory_style_note_for_storyboard(row, storyboard_row),
    }
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

fn selected_video_memory_update_would_reduce_quality_with_bias(
    existing: &str,
    incoming: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> bool {
    selected_visual_only_memory_keep_priority(existing, bias)
        > selected_visual_only_memory_keep_priority(incoming, bias)
}

fn selected_video_memory_quality_score(content: &str) -> i32 {
    let mut score = 0;

    if let Some(raw_style) = extract_key_value(content, "style") {
        let raw_fragments = split_prompt_note_fragments(&raw_style).collect::<Vec<_>>();
        score -= selected_video_memory_style_redundancy_penalty(&raw_fragments);
    }

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
                return penalty + 36;
            }
        }
        if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
            if selected_style_fragment_is_generic_restrained_mood(&mood) {
                return penalty + 24;
            }
        }
        if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
            if selected_style_fragment_is_low_gain_motion(&action) {
                return penalty + 24;
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

    if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
        if selected_style_fragment_is_low_gain_voice(&voice) {
            return 2;
        }
    }
    if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
        if selected_style_fragment_is_generic_restrained_mood(&mood) {
            return 2;
        }
    }
    if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
        if selected_style_fragment_is_low_gain_motion(&action) {
            return 1;
        }
    }

    let mut score = 6;
    if fragment.starts_with("镜头") {
        score += 5;
    }
    if fragment.starts_with("情绪") {
        score += 7;
    }
    if fragment.starts_with("光影") {
        score += 5;
    }
    if fragment.starts_with("动作") {
        score += 3;
    }
    if fragment.starts_with("表演") {
        score += 10;
    }
    if fragment.starts_with("环境") {
        score += 4;
    }
    if fragment.starts_with("语气") {
        score += 9;
    }
    if fragment.starts_with("声场") {
        score += 4;
    }
    if fragment.starts_with("场景") {
        score += 2;
    }
    if fragment.starts_with("表演") || fragment.starts_with("语气") {
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
mod tests;
