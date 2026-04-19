use super::shot_ids::normalize_export_shot_ids;
use crate::error::ApiError;
use crate::production::workbench::storyboard_ops::types::ExportImageShotRef;

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
