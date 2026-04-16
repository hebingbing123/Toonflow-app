//! manuals/director 单元测试。

use super::*;

#[test]
fn load_director_manual_smoke() {
    let r = load_director_manual_list().expect("bundle");
    assert!(
        r.data.len() >= 2,
        "expected multiple story_skills styles, got {}",
        r.data.len()
    );
    let family = r
        .data
        .iter()
        .find(|s| s.director_manual_key == "Family_warmth")
        .expect("Family_warmth");
    assert!(!family.name.is_empty());
    let planning = family
        .data
        .iter()
        .find(|e| e.value == "director_planning_narrative")
        .expect("planning slot");
    assert!(
        planning.data.len() > 20,
        "expected md body, len {}",
        planning.data.len()
    );
}
