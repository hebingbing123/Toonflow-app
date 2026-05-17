use super::super::{
    normalize_video_prompt_fingerprint, recent_video_job_matches_storyboard_model,
    VIDEO_JOB_DEDUP_WINDOW_MINUTES,
};

#[test]
fn recent_video_job_matches_storyboard_model_accepts_numeric_and_string_ids() {
    let fp = normalize_video_prompt_fingerprint("A hero  walks");
    let payload = serde_json::json!({
        "storyboard_numeric_id": 42,
        "model": "seedance-pro",
        "prompt_fingerprint": fp,
    });
    assert!(recent_video_job_matches_storyboard_model(
        &payload,
        42,
        "seedance-pro",
        &fp,
    ));
    let payload_str_id = serde_json::json!({
        "storyboard_numeric_id": "42",
        "model": "seedance-pro",
        "prompt": "a hero walks",
    });
    assert!(recent_video_job_matches_storyboard_model(
        &payload_str_id,
        42,
        "seedance-pro",
        &fp,
    ));
}

#[test]
fn recent_video_job_matches_storyboard_model_rejects_mismatch() {
    let fp = normalize_video_prompt_fingerprint("scene one");
    let payload = serde_json::json!({
        "storyboard_numeric_id": 42,
        "model": "other-model",
        "prompt_fingerprint": fp,
    });
    assert!(!recent_video_job_matches_storyboard_model(
        &payload,
        42,
        "seedance-pro",
        &fp,
    ));
    assert!(!recent_video_job_matches_storyboard_model(
        &payload,
        99,
        "seedance-pro",
        &fp,
    ));
    let other_prompt = serde_json::json!({
        "storyboard_numeric_id": 42,
        "model": "seedance-pro",
        "prompt_fingerprint": normalize_video_prompt_fingerprint("different line"),
    });
    assert!(!recent_video_job_matches_storyboard_model(
        &other_prompt,
        42,
        "seedance-pro",
        &fp,
    ));
}

#[test]
fn normalize_video_prompt_fingerprint_collapses_whitespace_and_case() {
    assert_eq!(
        normalize_video_prompt_fingerprint("  Hello   World "),
        "hello world"
    );
}

#[test]
fn video_job_dedup_window_is_five_minutes() {
    assert_eq!(VIDEO_JOB_DEDUP_WINDOW_MINUTES, 5);
}
