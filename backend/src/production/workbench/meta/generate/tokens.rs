//! Constants and token lists for prompt generation.

pub(super) const VIDEO_PROMPT_MEMORY_ROW_LIMIT: i64 = 24;
pub(super) const VIDEO_PROMPT_SELECTED_MEMORY_ROW_LIMIT: usize = 6;
pub(super) const VIDEO_PROMPT_AUTO_SCOPE_MEMORY_ROW_LIMIT: usize = 6;
pub(super) const VIDEO_PROMPT_SCRIPT_STYLE_MEMORY_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_PROJECT_STYLE_MEMORY_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_ROLE_STYLE_MEMORY_ROW_LIMIT: usize = 4;
pub(super) const VIDEO_PROMPT_OBSERVATION_REJECTION_ROW_LIMIT: usize = 8;
pub(super) const VIDEO_PROMPT_OBSERVATION_SCRIPT_STYLE_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_OBSERVATION_PROJECT_STYLE_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_OBSERVATION_ROLE_STYLE_ROW_LIMIT: usize = 2;
pub(super) const VIDEO_PROMPT_OBSERVATION_SCRIPT_SUMMARY_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_OBSERVATION_PROJECT_SUMMARY_ROW_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_OBSERVATION_ROLE_SUMMARY_ROW_LIMIT: usize = 2;
pub(super) const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
pub(super) const VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT: usize = 1;
pub(super) const VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS: usize = 36;
pub(super) const VIDEO_PROMPT_LEAN_CONTINUITY_NOTE_MAX_CHARS: usize = 24;
pub(super) const VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT: usize = 6;
pub(super) const VIDEO_PROMPT_SCENE_ASSET_ROW_LIMIT: usize = 6;
pub(super) const VIDEO_PROMPT_TOOL_ASSET_ROW_LIMIT: usize = 6;
pub(super) const VIDEO_PROMPT_MULTI_ROLE_ANCHOR_LIMIT: usize = 2;
pub(super) const VIDEO_PROMPT_MULTI_SCENE_ANCHOR_LIMIT: usize = 2;
pub(super) const VIDEO_PROMPT_MULTI_TOOL_ANCHOR_LIMIT: usize = 2;
pub(super) const VIDEO_PROMPT_PERFORMANCE_ANCHOR_MAX_CHARS: usize = 48;
pub(super) const VIDEO_PROMPT_GUARDRAIL_PERFORMANCE_ANCHOR_MAX_CHARS: usize = 26;
pub(super) const VIDEO_PROMPT_ENVIRONMENT_ANCHOR_MAX_CHARS: usize = 20;
pub(super) const VIDEO_PROMPT_ENVIRONMENT_TEXTURE_ANCHOR_MAX_CHARS: usize = 20;
pub(super) const VIDEO_PROMPT_MOTION_ANCHOR_MAX_CHARS: usize = 20;

pub(super) const DIRECTOR_ENVIRONMENT_PRIMARY_TOKENS: [&str; 24] = [
    "咖啡", "手机", "屏幕", "电梯", "车灯", "车流", "霓虹", "窗帘", "雨滴", "雨丝", "玻璃", "花瓣",
    "落花", "飞絮", "轻烟", "烟雾", "流水", "水波", "竹林", "烛火", "树叶", "云层", "樱花", "雪花",
];
pub(super) const DIRECTOR_ENVIRONMENT_SECONDARY_TOKENS: [&str; 11] = [
    "窗", "雨", "花", "云", "水", "灯", "叶", "风", "雾", "烟", "雪",
];
pub(super) const DIRECTOR_ENVIRONMENT_TEXTURE_MATCH_TOKENS: [&str; 19] = [
    "雨", "灯", "光", "窗", "玻璃", "布", "衣", "袖", "裙", "帘", "带", "花", "烟", "雾", "水",
    "波", "叶", "云", "车",
];
pub(super) const STORYBOARD_ENVIRONMENT_DYNAMIC_TOKENS: [&str; 19] = [
    "热气", "亮灭", "明灭", "闪烁", "光晕", "反光", "车流", "车灯", "雨滴", "雨丝", "玻璃", "窗帘",
    "树叶", "落叶", "花瓣", "烟雾", "水波", "烛火", "轻摆",
];
pub(super) const ACTION_OBJECT_PREFIX_VERBS: [&str; 10] = [
    "握紧", "拿着", "提着", "举着", "攥着", "扶住", "抱着", "拖着", "背着", "扛着",
];
pub(super) const ACTION_SUBJECT_PREFIXES: [&str; 10] = [
    "主角", "女主", "男主", "反派", "女孩", "男孩", "女人", "男人", "老人", "孩子",
];
pub(super) const SETTING_SUBJECT_LEAD_IN_SUFFIXES: [&str; 10] = [
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
pub(super) const PROMPT_LEADING_BRIDGES: [&str; 7] = ["在", "于", "向", "朝", "往", "从", "自"];
