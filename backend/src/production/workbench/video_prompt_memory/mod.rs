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
mod continuity;
mod observation;
mod parsing;
mod rejected;
mod scope;
mod selected;
mod selected_identity;
mod selected_note;
mod selected_style;
mod storage;
mod style_build;
mod style_compact;
mod style_context;
mod style_notes;
mod style_rank;
mod style_role;
mod style_role_select;
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

#[cfg_attr(not(test), allow(unused_imports))]
use continuity::compact_selected_memory_environment;
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use continuity::compact_video_continuity_note;
#[cfg_attr(not(test), allow(unused_imports))]
use style_build::{
    build_project_role_video_style_memories, build_project_video_style_memory,
    build_project_video_style_memory_with_bias, build_script_role_video_style_memories,
    build_script_video_style_memory, build_script_video_style_memory_with_bias,
    local_shot_framing_fragment,
};
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use style_compact::compact_video_style_prompt_note;
#[cfg_attr(not(test), allow(unused_imports))]
use style_compact::{
    compact_selected_memory_residual_note, non_style_note,
    selected_style_fragment_is_generic_restrained_mood, selected_style_fragment_is_low_gain_motion,
    selected_style_fragment_is_low_gain_voice, style_only_note,
};
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use style_context::contextual_style_memory_value_for_storyboard;
#[cfg_attr(not(test), allow(unused_imports))]
use style_context::{
    delivery_style_value_from_content, generation_brief_style_memory_value,
    is_low_signal_selected_memory_note, role_style_memory_value_for_storyboard,
    selected_video_delivery_value_from_content, selected_video_delivery_value_from_note,
    selected_video_memory_quality_score,
    selected_video_memory_update_would_reduce_quality_with_bias, selected_video_style_value,
    should_prefer_selected_delivery_for_storyboard,
};
#[cfg_attr(not(test), allow(unused_imports))]
use style_notes::role_memory_subject_candidates;
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use style_rank::{
    select_neighbor_selected_video_memory_notes, select_prioritized_video_style_note,
    select_selected_video_memory_notes, select_selected_video_memory_notes_for_storyboard,
};
#[cfg_attr(not(test), allow(unused_imports))]
use style_role::role_memory_fragment_is_character_signal;
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use style_role_select::{
    select_project_video_style_memory_notes,
    select_project_video_style_memory_notes_for_storyboard, select_script_video_style_memory_notes,
    select_script_video_style_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes,
    select_subject_role_video_style_memory_notes_for_storyboard,
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
#[cfg_attr(not(test), allow(unused_imports))]
pub(crate) use scope::storyboard_prompt_seed;
use scope::{
    has_exact_prompt_seed_memory_match, memory_matches_prompt_seed_with_fallback,
    memory_matches_storyboard, selected_video_memory_scope,
    storyboard_distance_from_memory_content,
};
use selected_identity::{
    compact_selected_memory_action, compact_selected_memory_setting,
    compact_selected_memory_subject, merge_selected_memory_subject_action,
    selected_memory_identity_source,
};
pub(crate) use selected_identity::{
    selected_memory_subject_aliases, selected_memory_subject_identity,
};
use selected_note::{
    selected_memory_field_looks_silent, selected_memory_has_high_signal_visual_performance_cue,
    selected_memory_has_visible_speech_performance_risk, selected_memory_scene_has_motion_risk,
    selected_video_memory_note,
};
use selected_style::{
    compact_selected_memory_delivery_style, compact_selected_memory_motion_style,
    compact_selected_memory_performance_style, compact_selected_memory_sound_style,
    compact_selected_memory_style_fragments, compact_selected_memory_voice_style,
    selected_memory_voice_fragment_is_redundant_with_performance,
};
use storage::{
    replace_project_summary_memories, replace_project_summary_memory, replace_summary_memories,
    replace_summary_memory,
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
const STABLE_PROMPT_SHOT_KEYWORDS: [&str; 13] = [
    "远景",
    "特写稳定跟拍",
    "近景稳定跟拍",
    "中景稳定跟拍",
    "全景稳定跟拍",
    "稳定跟拍",
    "手持跟拍",
    "慢推",
    "推进",
    "拉远",
    "环绕",
    "手持",
    "跟拍",
];
const CONTINUITY_NOTE_KEYWORDS: [&str; 14] = [
    "保持",
    "延续",
    "衔接",
    "连续",
    "一致",
    "统一",
    "方向",
    "构图",
    "视线",
    "站位",
    "走位",
    "位置",
    "前后景",
    "跳轴",
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

#[cfg(test)]
mod tests;
