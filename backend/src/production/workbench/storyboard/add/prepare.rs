//! 将请求体规范化为 `StoryboardInsertDraft` 列表。

use super::super::common::{normalize_storyboard_prompt, StoryboardInsertDraft};
use super::types::StoryboardInfoInput;
use crate::error::ApiError;

pub(super) const DEFAULT_STORYBOARD_DURATION: i32 = 5;

pub(super) fn prepare_storyboard_insert(
    prompt: &str,
    duration: Option<i32>,
) -> Result<StoryboardInsertDraft, ApiError> {
    Ok(StoryboardInsertDraft {
        prompt: normalize_storyboard_prompt(prompt)?,
        duration: duration.unwrap_or(DEFAULT_STORYBOARD_DURATION),
    })
}

pub(super) fn prepare_batch_storyboard_inserts(
    storyboards: &[StoryboardInfoInput],
) -> Result<Vec<StoryboardInsertDraft>, ApiError> {
    if storyboards.is_empty() {
        return Err(ApiError::BadRequest("storyboards must not be empty".into()));
    }

    storyboards
        .iter()
        .map(|storyboard| {
            prepare_storyboard_insert(&storyboard.prompt, storyboard.duration)
                .map_err(|_| ApiError::BadRequest("storyboards[*].prompt must not be empty".into()))
        })
        .collect()
}
