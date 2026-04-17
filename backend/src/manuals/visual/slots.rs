use std::collections::HashSet;

pub(super) const MAX_SLOT_BYTES: u64 = 2_000_000;
pub(super) const MAX_README_BYTES: u64 = 256_000;
pub(super) const MAX_BASE64_IMAGE_INPUT_CHARS: usize = 45_000_000;
pub(super) const MAX_DECODED_IMAGE_BYTES: u64 = 25_000_000;
pub(super) const NAME_RULE_MSG: &str = "名称不能包含路径分隔符或为纯数字";

#[derive(Debug, Clone, Copy)]
pub(super) struct ManualSlotDef {
    pub(super) label: &'static str,
    pub(super) value: &'static str,
    /// Subdirectory under each style folder, or **`None`** for root-level **`{value}.md`**.
    pub(super) sub_dir: Option<&'static str>,
}

pub(super) const MANUAL_SLOTS: [ManualSlotDef; 12] = [
    ManualSlotDef {
        label: "README",
        value: "README",
        sub_dir: None,
    },
    ManualSlotDef {
        label: "前缀",
        value: "prefix",
        sub_dir: None,
    },
    ManualSlotDef {
        label: "角色",
        value: "art_character",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "角色衍生",
        value: "art_character_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "道具",
        value: "art_prop",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "道具衍生",
        value: "art_prop_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "场景",
        value: "art_scene",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "场景衍生",
        value: "art_scene_derivative",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "分镜",
        value: "director_storyboard",
        sub_dir: Some("driector_skills"),
    },
    ManualSlotDef {
        label: "分镜视频",
        value: "art_storyboard_video",
        sub_dir: Some("art_prompt"),
    },
    ManualSlotDef {
        label: "技法-导演规划",
        value: "director_planning_style",
        sub_dir: Some("driector_skills"),
    },
    ManualSlotDef {
        label: "技法-分镜表设计",
        value: "director_storyboard_table_style",
        sub_dir: Some("driector_skills"),
    },
];

pub(super) fn valid_visual_slot_values() -> HashSet<&'static str> {
    MANUAL_SLOTS.iter().map(|s| s.value).collect()
}
