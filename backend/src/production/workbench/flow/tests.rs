use super::storyboard_order::ordered_storyboard_numeric_ids;
use super::types::{GetFlowDataBody, SaveFlowDataBody};

#[test]
fn get_flow_data_body_rejects_unknown_fields() {
    let err =
        serde_json::from_str::<GetFlowDataBody>(r#"{"projectId":1,"episodesId":5,"extra":1}"#);
    assert!(err.is_err());
}

#[test]
fn get_flow_data_body_accepts_valid() {
    let b: GetFlowDataBody = serde_json::from_str(r#"{"projectId":1,"episodesId":5}"#).unwrap();
    assert_eq!(b.project_id, Some(1));
    assert_eq!(b.episodes_id, 5);
}

#[test]
fn save_flow_data_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<SaveFlowDataBody>(
        r#"{"projectId":1,"episodesId":5,"data":{},"extra":1}"#,
    );
    assert!(err.is_err());
}

#[test]
fn save_flow_data_body_accepts_valid() {
    let b: SaveFlowDataBody =
        serde_json::from_str(r#"{"projectId":1,"episodesId":5,"data":{"key":"value"}}"#).unwrap();
    assert_eq!(b.project_id, Some(1));
    assert_eq!(b.episodes_id, 5);
    assert!(b.data.is_object());
}

#[test]
fn ordered_storyboard_numeric_ids_rejects_non_object() {
    let err = ordered_storyboard_numeric_ids(&serde_json::json!([])).expect_err("non-object");
    match err {
        crate::error::ApiError::BadRequest(msg) => {
            assert!(msg.contains("JSON object"));
        }
        other => panic!("unexpected error: {other:?}"),
    }
}

#[test]
fn ordered_storyboard_numeric_ids_returns_none_without_storyboard_array() {
    let got = ordered_storyboard_numeric_ids(&serde_json::json!({"key":"value"}))
        .expect("object should parse");
    assert_eq!(got, None);
}

#[test]
fn ordered_storyboard_numeric_ids_extracts_positive_ids_in_order() {
    let got = ordered_storyboard_numeric_ids(&serde_json::json!({
        "storyboard": [{"id": 9}, {"id": 2}, {"id": 7}]
    }))
    .expect("valid storyboard ids");
    assert_eq!(got, Some(vec![9, 2, 7]));
}

#[test]
fn ordered_storyboard_numeric_ids_returns_none_when_any_id_is_invalid() {
    let got = ordered_storyboard_numeric_ids(&serde_json::json!({
        "storyboard": [{"id": 9}, {"id": 0}, {"id": 7}]
    }))
    .expect("object should parse");
    assert_eq!(got, None);
}
