//! 将请求体规范化为 `StoryboardInsertDraft` 列表。

use super::super::common::{
    normalize_storyboard_duration, normalize_storyboard_prompt, StoryboardInsertDraft,
};
use super::types::StoryboardInfoInput;
use crate::error::{bad_request_i18n, ApiError};

pub(super) fn prepare_storyboard_insert(
    prompt: &str,
    duration: Option<i32>,
) -> Result<StoryboardInsertDraft, ApiError> {
    Ok(StoryboardInsertDraft {
        prompt: normalize_storyboard_prompt(prompt)?,
        duration: normalize_storyboard_duration(duration)?,
    })
}

pub(super) fn prepare_batch_storyboard_inserts(
    storyboards: &[StoryboardInfoInput],
) -> Result<Vec<StoryboardInsertDraft>, ApiError> {
    if storyboards.is_empty() {
        return Err(bad_request_i18n(
            "storyboards must not be empty",
            "storyboards 不能为空",
        ));
    }

    storyboards
        .iter()
        .map(|storyboard| {
            prepare_storyboard_insert(&storyboard.prompt, storyboard.duration).map_err(|err| {
                match err {
                    ApiError::BadRequest(message) if message == "prompt must not be empty" => {
                        ApiError::BadRequest("storyboards[*].prompt must not be empty".into())
                    }
                    ApiError::BadRequest(message) if message == "prompt 不能为空" => {
                        ApiError::BadRequest("storyboards[*].prompt 不能为空".into())
                    }
                    ApiError::BadRequest(message)
                        if message == "duration must be a positive integer" =>
                    {
                        ApiError::BadRequest(
                            "storyboards[*].duration must be a positive integer".into(),
                        )
                    }
                    ApiError::BadRequest(message) if message == "duration 必须是正整数" => {
                        ApiError::BadRequest("storyboards[*].duration 必须是正整数".into())
                    }
                    other => other,
                }
            })
        })
        .collect()
}
