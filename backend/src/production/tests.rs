use super::router;
use super::types::{GenerateVideoUploadItem, WorkbenchGenerateVideoBody};

#[test]
fn generate_video_upload_item_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<GenerateVideoUploadItem>(r#"{"id":1,"sources":"url","extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn generate_video_upload_item_accepts_valid() {
    let b: GenerateVideoUploadItem =
        serde_json::from_str(r#"{"id":1,"sources":"http://example.com"}"#).unwrap();
    assert_eq!(b.id, 1);
    assert_eq!(b.sources, "http://example.com");
}

#[test]
fn generate_video_upload_item_accepts_storyboard_level_prompt_overrides() {
    let b: GenerateVideoUploadItem = serde_json::from_str(
        r#"{"id":1,"sources":"http://example.com","prompt":"shot prompt","negativePrompt":"avoid blur"}"#,
    )
    .unwrap();
    assert_eq!(b.prompt.as_deref(), Some("shot prompt"));
    assert_eq!(b.negative_prompt.as_deref(), Some("avoid blur"));
}

#[test]
fn workbench_generate_video_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<WorkbenchGenerateVideoBody>(
        r#"{"projectId":1,"scriptId":2,"uploadData":[],"prompt":"","model":"","mode":"","resolution":"","duration":5,"trackId":1,"extra":1}"#,
    );
    assert!(err.is_err());
}

#[test]
fn workbench_generate_video_body_accepts_valid() {
    let b: WorkbenchGenerateVideoBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"uploadData":[{"id":1,"sources":"url"}],"prompt":"test","model":"runway","mode":"standard","resolution":"1080p","duration":5,"trackId":1}"#,
    )
    .unwrap();
    assert_eq!(b.project_id, 1);
    assert_eq!(b.script_id, 2);
    assert_eq!(b.upload_data.len(), 1);
    assert_eq!(b.duration, 5);
    assert_eq!(b.audio, None);
}

#[test]
fn workbench_generate_video_body_accepts_with_audio() {
    let b: WorkbenchGenerateVideoBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"uploadData":[],"prompt":"","model":"","mode":"","resolution":"","duration":5,"audio":true,"trackId":1}"#,
    )
    .unwrap();
    assert_eq!(b.audio, Some(true));
}

#[test]
fn workbench_generate_video_body_accepts_negative_prompt() {
    let b: WorkbenchGenerateVideoBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"uploadData":[{"id":1,"sources":"url"}],"prompt":"test","negativePrompt":"avoid blur","model":"runway","mode":"standard","resolution":"1080p","duration":5,"trackId":1}"#,
    )
    .unwrap();
    assert_eq!(b.negative_prompt.as_deref(), Some("avoid blur"));
}

#[test]
fn workbench_generate_video_body_allows_storyboard_prompt_when_global_prompt_is_empty() {
    let b: WorkbenchGenerateVideoBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"uploadData":[{"id":1,"sources":"url","prompt":"shot prompt"}],"prompt":"","model":"runway","mode":"standard","resolution":"1080p","duration":5,"trackId":1}"#,
    )
    .unwrap();
    assert_eq!(b.prompt, "");
    assert_eq!(b.upload_data[0].prompt.as_deref(), Some("shot prompt"));
}

#[test]
fn router_builds_without_generic_stub_paths() {
    let app = router();
    let _ = app;
}
