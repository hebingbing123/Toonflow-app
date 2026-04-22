use super::shot_ids::normalize_export_shot_ids;
use super::zip_export::{
    build_storyboard_csv, build_storyboard_srt, build_storyboard_voiceover_script,
};
use crate::error::ApiError;
use crate::production::workbench::storyboard_ops::types::ExportImageShotRef;
use crate::production::workbench::storyboard_ops::types::ExportImageSourceRow;

#[test]
fn normalize_export_shot_ids_rejects_empty_input() {
    let err = normalize_export_shot_ids(&[]).unwrap_err();
    assert!(
        matches!(err, ApiError::BadRequest(message) if message == "shotId must be a non-empty array")
    );
}

#[test]
fn normalize_export_shot_ids_rejects_non_positive_values() {
    let err = normalize_export_shot_ids(&[ExportImageShotRef { id: "0".into() }]).unwrap_err();
    assert!(
        matches!(err, ApiError::BadRequest(message) if message == "shotId.id must be a positive integer")
    );
}

#[test]
fn normalize_export_shot_ids_trims_sorts_and_deduplicates() {
    let ids = normalize_export_shot_ids(&[
        ExportImageShotRef { id: " 4 ".into() },
        ExportImageShotRef { id: "2".into() },
        ExportImageShotRef { id: "4".into() },
    ])
    .unwrap();

    assert_eq!(ids, vec![2, 4]);
}

#[test]
fn storyboard_csv_quotes_prompt_and_preserves_columns() {
    let shot = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 7,
            file_path: Some("https://cdn.example.com/storyboard-7.png".into()),
            prompt: Some("close-up, hero says \"go\"".into()),
            video_desc: Some("Hero: go".into()),
            duration: Some("5".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(9),
        },
        0,
    );
    let csv = build_storyboard_csv(&[shot]);

    assert!(csv.starts_with(
        "storyboard_id,order_index,storyboard_index,track_id,duration,state,prompt,subtitle_source,voiceover_ready,image_filename,image_source\n"
    ));
    assert!(
        csv.contains("7,0,9,3,5,已完成,\"close-up, hero says \"\"go\"\"\",explicit_narration,true")
    );
    assert!(csv.contains("storyboard-7.png"));
}

#[test]
fn storyboard_srt_uses_timeline_offsets_and_prompt_text() {
    let first = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 7,
            file_path: Some("https://cdn.example.com/storyboard-7.png".into()),
            prompt: Some("Opening line".into()),
            video_desc: Some("Narrator opening".into()),
            duration: Some("5".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(9),
        },
        0,
    );
    let second = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 8,
            file_path: Some("https://cdn.example.com/storyboard-8.png".into()),
            prompt: None,
            video_desc: None,
            duration: Some("6".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(10),
        },
        1,
    );

    let srt = build_storyboard_srt(&[first, second]);

    assert!(srt.contains("1\n00:00:00,000 --> 00:00:05,000\nNarrator opening"));
    assert!(srt.contains("2\n00:00:05,000 --> 00:00:11,000\nShot 8"));
}

#[test]
fn storyboard_voiceover_script_uses_narration_then_prompt_fallback() {
    let first = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 7,
            file_path: Some("https://cdn.example.com/storyboard-7.png".into()),
            prompt: Some("Opening line".into()),
            video_desc: Some("Narrator opening".into()),
            duration: Some("5".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(9),
        },
        0,
    );
    let second = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 8,
            file_path: Some("https://cdn.example.com/storyboard-8.png".into()),
            prompt: Some("Fallback prompt".into()),
            video_desc: None,
            duration: Some("6".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(10),
        },
        1,
    );

    let script = build_storyboard_voiceover_script(&[first, second]);

    assert!(script.starts_with("# Toonflow Storyboard Voiceover Script"));
    assert!(script.contains("[00:00:00,000 - 00:00:05,000] Shot 7 (sb_index=9)"));
    assert!(script.contains("source=explicit_narration · voiceover_ready=true"));
    assert!(script.contains("Narrator opening"));
    assert!(script.contains("[00:00:05,000 - 00:00:11,000] Shot 8 (sb_index=10)"));
    assert!(script.contains("source=prompt_fallback · voiceover_ready=true"));
    assert!(script.contains("Fallback prompt"));
}

#[test]
fn storyboard_voiceover_segments_carry_timeline_and_ready_counts() {
    let first = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 7,
            file_path: Some("https://cdn.example.com/storyboard-7.png".into()),
            prompt: Some("Opening line".into()),
            video_desc: Some("Narrator opening".into()),
            duration: Some("5".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(9),
        },
        0,
    );
    let second = super::zip_export::StoryboardExportManifestShot::from_row(
        &ExportImageSourceRow {
            numeric_id: 8,
            file_path: Some("https://cdn.example.com/storyboard-8.png".into()),
            prompt: None,
            video_desc: None,
            duration: Some("6".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(10),
        },
        1,
    );

    let payload = serde_json::to_value(super::zip_export::build_storyboard_voiceover_segments(&[
        first, second,
    ]))
    .expect("voiceover segments json");

    assert_eq!(
        payload["export_type"].as_str(),
        Some("storyboard_voiceover_segments")
    );
    assert_eq!(payload["shot_count"].as_u64(), Some(2));
    assert_eq!(payload["ready_count"].as_u64(), Some(1));
    assert_eq!(payload["placeholder_count"].as_u64(), Some(1));
    assert_eq!(payload["total_duration_ms"].as_u64(), Some(11_000));
    assert_eq!(payload["shots"][0]["start_ms"].as_u64(), Some(0));
    assert_eq!(payload["shots"][0]["end_ms"].as_u64(), Some(5_000));
    assert_eq!(
        payload["shots"][0]["subtitle_source"].as_str(),
        Some("explicit_narration")
    );
    assert_eq!(payload["shots"][0]["voiceover_ready"].as_bool(), Some(true));
    assert_eq!(payload["shots"][1]["start_ms"].as_u64(), Some(5_000));
    assert_eq!(payload["shots"][1]["end_ms"].as_u64(), Some(11_000));
    assert_eq!(
        payload["shots"][1]["subtitle_source"].as_str(),
        Some("placeholder")
    );
    assert_eq!(
        payload["shots"][1]["voiceover_ready"].as_bool(),
        Some(false)
    );
}
