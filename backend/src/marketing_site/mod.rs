//! 仓库根 `website/` 营销落地页：与 API 同进程、同端口提供静态文件（默认 `/`）。

use std::path::{Path, PathBuf};

mod router;

pub use router::merge_fallback;

/// 解析营销站目录；不存在或禁用时返回 `None`。
pub fn resolve_dir() -> Option<PathBuf> {
    if marketing_disabled() {
        return None;
    }

    if let Ok(raw) = std::env::var("OPENFLOW_MARKETING_SITE_DIR") {
        let dir = PathBuf::from(raw);
        return dir_if_valid(&dir);
    }

    let default = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../website");
    dir_if_valid(&default)
}

fn marketing_disabled() -> bool {
    matches!(
        std::env::var("OPENFLOW_MARKETING_SITE")
            .ok()
            .as_deref()
            .map(str::trim)
            .map(str::to_ascii_lowercase)
            .as_deref(),
        Some("0") | Some("false") | Some("off") | Some("no")
    )
}

fn dir_if_valid(dir: &Path) -> Option<PathBuf> {
    if !dir.join("index.html").is_file() {
        return None;
    }
    dir.canonicalize().ok().or_else(|| Some(dir.to_path_buf()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn dir_if_valid_requires_index_html() {
        let tmp = tempfile::tempdir().expect("tempdir");
        assert!(dir_if_valid(tmp.path()).is_none());
        fs::write(tmp.path().join("index.html"), "<!DOCTYPE html>").expect("write");
        assert!(dir_if_valid(tmp.path()).is_some());
    }
}
