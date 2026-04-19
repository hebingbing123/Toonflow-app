use super::super::common::StoryboardInsertDraft;
use super::prepare::{
    prepare_batch_storyboard_inserts, prepare_storyboard_insert, DEFAULT_STORYBOARD_DURATION,
};
use super::types::StoryboardInfoInput;
use crate::error::ApiError;

#[test]
fn prepare_storyboard_insert_trims_prompt_and_defaults_duration() {
    let prepared = prepare_storyboard_insert("  opening shot  ", None).unwrap();
    assert_eq!(
        prepared,
        StoryboardInsertDraft {
            prompt: "opening shot".to_string(),
            duration: DEFAULT_STORYBOARD_DURATION,
        }
    );
}

#[test]
fn prepare_storyboard_insert_rejects_blank_prompt() {
    let err = prepare_storyboard_insert("   ", Some(3)).unwrap_err();
    assert!(matches!(
        err,
        ApiError::BadRequest(message) if message == "prompt must not be empty"
    ));
}

#[test]
fn prepare_batch_storyboard_inserts_rejects_empty_list() {
    let err = prepare_batch_storyboard_inserts(&[]).unwrap_err();
    assert!(matches!(
        err,
        ApiError::BadRequest(message) if message == "storyboards must not be empty"
    ));
}

#[test]
fn prepare_batch_storyboard_inserts_normalizes_each_item() {
    let prepared = prepare_batch_storyboard_inserts(&[
        StoryboardInfoInput {
            prompt: "  first  ".to_string(),
            duration: None,
        },
        StoryboardInfoInput {
            prompt: "second".to_string(),
            duration: Some(8),
        },
    ])
    .unwrap();

    assert_eq!(
        prepared,
        vec![
            StoryboardInsertDraft {
                prompt: "first".to_string(),
                duration: DEFAULT_STORYBOARD_DURATION,
            },
            StoryboardInsertDraft {
                prompt: "second".to_string(),
                duration: 8,
            },
        ]
    );
}

#[test]
fn prepare_batch_storyboard_inserts_relabels_blank_prompt_error() {
    let err = prepare_batch_storyboard_inserts(&[StoryboardInfoInput {
        prompt: " ".to_string(),
        duration: Some(2),
    }])
    .unwrap_err();

    assert!(matches!(
        err,
        ApiError::BadRequest(message) if message == "storyboards[*].prompt must not be empty"
    ));
}
