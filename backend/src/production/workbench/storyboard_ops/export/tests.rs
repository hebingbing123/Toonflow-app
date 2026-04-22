use super::shot_ids::normalize_export_shot_ids;
use super::zip_export::build_storyboard_csv;
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
            duration: Some("5".into()),
            state: Some("已完成".into()),
            track_id: Some(3),
            sb_index: Some(9),
        },
        0,
    );
    let csv = build_storyboard_csv(&[shot]);

    assert!(csv.starts_with(
        "storyboard_id,order_index,storyboard_index,track_id,duration,state,prompt,image_filename,image_source\n"
    ));
    assert!(csv.contains("7,0,9,3,5,已完成,\"close-up, hero says \"\"go\"\"\""));
    assert!(csv.contains("storyboard-7.png"));
}
