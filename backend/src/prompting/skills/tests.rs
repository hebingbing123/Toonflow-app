//! prompting/skills 单元测试。

use std::path::Path;

use super::*;

#[test]
fn skill_content_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<SkillContentBody>(r#"{"path":"a.md","content":"x","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn safe_join_rejects_parent_segment() {
    let root = Path::new("/tmp/skills-root");
    assert!(matches!(
        safe_join_under_root(root, ".."),
        Err(SkillReadError::BadPath(_))
    ));
    assert!(matches!(
        safe_join_under_root(root, "legit/../nope.md"),
        Err(SkillReadError::BadPath(_))
    ));
}

#[test]
fn safe_join_builds_under_root() {
    let root = Path::new("/tmp/skills-root");
    let p = safe_join_under_root(root, "dir/script.md").unwrap();
    assert!(p.ends_with("dir/script.md"));
}

#[test]
fn write_skill_at_updates_existing_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    std::fs::write(root.join("a.md"), "old").unwrap();
    let out = write_skill_at(root, "a.md", "new").unwrap();
    assert_eq!(out.path, "a.md");
    assert_eq!(out.content, "new");
    assert_eq!(std::fs::read_to_string(root.join("a.md")).unwrap(), "new");
}

#[test]
fn write_skill_at_rejects_missing_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    assert!(matches!(
        write_skill_at(root, "nope.md", "x"),
        Err(SkillWriteError::FileMissing)
    ));
}

#[test]
fn create_skill_at_writes_nested_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    let out = create_skill_at(root, "nested/x.md", "hi").unwrap();
    assert_eq!(out.path, "nested/x.md");
    assert_eq!(out.content, "hi");
    assert_eq!(
        std::fs::read_to_string(root.join("nested/x.md")).unwrap(),
        "hi"
    );
}

#[test]
fn create_skill_at_rejects_existing_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    std::fs::write(root.join("b.md"), "1").unwrap();
    assert!(matches!(
        create_skill_at(root, "b.md", "2"),
        Err(SkillCreateError::AlreadyExists)
    ));
}

#[test]
fn delete_skill_at_removes_file() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    std::fs::write(root.join("d.md"), "z").unwrap();
    delete_skill_at(root, "d.md").unwrap();
    assert!(!root.join("d.md").exists());
}

#[test]
fn delete_skill_at_not_found() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    assert!(matches!(
        delete_skill_at(root, "gone.md"),
        Err(SkillDeleteError::NotFound)
    ));
}

#[test]
fn read_skill_binary_smoke_fixture_is_png() {
    let got = read_skill_binary("_smoke/binary_probe.png").unwrap();
    assert_eq!(got.1, "image/png");
    assert!(got.0.starts_with(&[0x89, b'P', b'N', b'G']));
}

#[test]
fn read_skill_binary_rejects_markdown_extension() {
    assert!(matches!(
        read_skill_binary("script_execution_script.md"),
        Err(SkillReadError::BadPath(_))
    ));
}
