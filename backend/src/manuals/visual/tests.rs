//! manuals/visual 单元测试。

use super::*;

#[test]
fn load_visual_manual_smoke() {
    let r = load_visual_manual().expect("bundle");
    assert!(
        r.styles.len() >= 2,
        "expected multiple art styles, got {}",
        r.styles.len()
    );
    let anime = r
        .styles
        .iter()
        .find(|s| s.style_path == "2D_90s_japanese_anime")
        .expect("2D_90s_japanese_anime");
    assert!(!anime.name.is_empty());
    let scene = anime
        .data
        .iter()
        .find(|e| e.value == "art_scene")
        .expect("art_scene slot");
    assert!(
        scene.data.len() > 40,
        "expected art_scene md body, len {}",
        scene.data.len()
    );
}
