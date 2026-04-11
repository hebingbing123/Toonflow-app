//! 提示词加载和持久化的小辅助函数。

pub(crate) const ADV_LOCK_ASSET_LEGACY_ID: i64 = 884_422_004;

pub(crate) fn trim_empty_opt(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

pub(crate) fn load_system_prompt() -> String {
    if let Ok(p) = std::env::var("SCRIPT_ASSET_EXTRACT_PROMPT_PATH") {
        if let Ok(s) = std::fs::read_to_string(&p) {
            if !s.trim().is_empty() {
                return s;
            }
        }
        tracing::warn!(path = %p, "SCRIPT_ASSET_EXTRACT_PROMPT_PATH set but empty or unreadable");
    }
    include_str!("../../../data/prompts/script_asset_extraction.default.txt").to_string()
}
