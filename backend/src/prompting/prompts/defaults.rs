//! 内置提示词槽位与默认正文（`data/prompt_defaults/*.txt`）。

#[derive(Debug, Clone, Copy)]
pub(super) struct DefaultSlot {
    pub(super) numeric_id: i32,
    pub(super) name: &'static str,
    pub(super) kind: &'static str,
    pub(super) body: &'static str,
}

pub(super) const DEFAULT_SLOTS: [DefaultSlot; 3] = [
    DefaultSlot {
        numeric_id: 1,
        name: "事件提取",
        kind: "eventExtraction",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/eventExtraction.txt"
        )),
    },
    DefaultSlot {
        numeric_id: 2,
        name: "剧本资产提取",
        kind: "scriptAssetExtraction",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/scriptAssetExtraction.txt"
        )),
    },
    DefaultSlot {
        numeric_id: 3,
        name: "视频提示词生成",
        kind: "videoPromptGeneration",
        body: include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/data/prompt_defaults/videoPromptGeneration.txt"
        )),
    },
];
