mod db;
mod ids;
mod normalize;
mod responses;
mod scope;
mod types;

pub(super) use db::{
    fetch_owned_storyboard_item, fetch_owned_storyboard_preview_data,
    insert_owned_storyboards_with_next_numeric_ids, list_owned_storyboard_items_by_script,
    remove_owned_storyboard_frame, update_owned_storyboard_image_url, update_owned_storyboard_info,
};
pub(super) use normalize::{normalize_storyboard_image_url, normalize_storyboard_prompt};
pub(super) use responses::{
    build_down_preview_image_response, build_preview_image_response, build_storyboard_data_response,
};
pub(super) use types::{
    DownPreviewImageResponse, PreviewImageResponse, StoryboardInsertDraft, StoryboardScopeBody,
    StoryboardScriptScopeBody,
};

use crate::error::ApiError;
use crate::production::workbench::common as workbench_common;
use crate::state::AppState;

pub(super) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    workbench_common::require_pool(state)
}

#[cfg(test)]
mod tests {
    use super::ids::storyboard_numeric_ids_from_base;
    use super::types::StoryboardPreviewData;
    use super::{
        build_down_preview_image_response, build_preview_image_response,
        build_storyboard_data_response, normalize_storyboard_image_url,
        normalize_storyboard_prompt,
    };
    use crate::error::ApiError;
    use crate::production::workbench::storyboard_ops::ProductionStoryboardItem;

    #[test]
    fn storyboard_numeric_ids_from_base_starts_after_base_id() {
        assert_eq!(storyboard_numeric_ids_from_base(41, 3), vec![42, 43, 44]);
    }

    #[test]
    fn storyboard_numeric_ids_from_base_allows_empty_batch() {
        assert!(storyboard_numeric_ids_from_base(9, 0).is_empty());
    }

    #[test]
    fn normalize_storyboard_prompt_trims_value() {
        let prompt = normalize_storyboard_prompt("  opening frame  ").unwrap();
        assert_eq!(prompt, "opening frame");
    }

    #[test]
    fn normalize_storyboard_prompt_rejects_blank_value() {
        let err = normalize_storyboard_prompt("   ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "prompt must not be empty"
        ));
    }

    #[test]
    fn normalize_storyboard_image_url_trims_value() {
        let image_url =
            normalize_storyboard_image_url("  https://example.com/frame.png  ").unwrap();
        assert_eq!(image_url, "https://example.com/frame.png");
    }

    #[test]
    fn normalize_storyboard_image_url_rejects_blank_value() {
        let err = normalize_storyboard_image_url(" ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "imageUrl must not be empty"
        ));
    }

    #[test]
    fn build_storyboard_data_response_wraps_rows() {
        let rows = vec![ProductionStoryboardItem {
            id: 7,
            script_id: Some(3),
            prompt: Some("frame".into()),
            file_path: Some("https://example.com/frame.png".into()),
            duration: Some("5".into()),
            state: Some("done".into()),
            track_id: Some(1),
            flow_id: Some(2),
            sb_index: Some(4),
        }];

        let response = build_storyboard_data_response(rows);
        assert_eq!(response.data.len(), 1);
        assert_eq!(response.data[0].id, 7);
    }

    #[test]
    fn build_down_preview_image_response_requires_preview_file_path() {
        let err = build_down_preview_image_response(
            8,
            StoryboardPreviewData {
                file_path: None,
                prompt: Some("frame".into()),
            },
        )
        .unwrap_err();

        assert!(matches!(err, ApiError::NotFound));
    }

    #[test]
    fn build_down_preview_image_response_sets_message_and_url() {
        let response = build_down_preview_image_response(
            8,
            StoryboardPreviewData {
                file_path: Some("https://example.com/preview.png".into()),
                prompt: Some("frame".into()),
            },
        )
        .unwrap();

        assert_eq!(response.storyboard_id, 8);
        assert_eq!(
            response.preview_url.as_deref(),
            Some("https://example.com/preview.png")
        );
        assert_eq!(response.message, "Preview image URL retrieved");
    }

    #[test]
    fn build_preview_image_response_copies_preview_fields() {
        let response = build_preview_image_response(
            9,
            StoryboardPreviewData {
                file_path: Some("https://example.com/image.png".into()),
                prompt: Some("frame".into()),
            },
        );

        assert_eq!(response.storyboard_id, 9);
        assert_eq!(
            response.image_url.as_deref(),
            Some("https://example.com/image.png")
        );
        assert_eq!(response.prompt.as_deref(), Some("frame"));
    }
}
