use crate::error::ApiError;
use crate::production::workbench::storyboard_ops::{
    hydrate_production_storyboard_items, ProductionGetProductionDataResponse,
    ProductionStoryboardItem,
};

use super::types::{DownPreviewImageResponse, PreviewImageResponse, StoryboardPreviewData};

pub(in crate::production::workbench::storyboard) fn build_storyboard_data_response(
    mut data: Vec<ProductionStoryboardItem>,
) -> ProductionGetProductionDataResponse {
    hydrate_production_storyboard_items(&mut data);
    ProductionGetProductionDataResponse { data }
}

pub(in crate::production::workbench::storyboard) fn build_down_preview_image_response(
    storyboard_id: i32,
    preview: StoryboardPreviewData,
) -> Result<DownPreviewImageResponse, ApiError> {
    if preview.file_path.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(DownPreviewImageResponse {
        storyboard_id,
        preview_url: preview.file_path,
        message: "Preview image URL retrieved",
    })
}

pub(in crate::production::workbench::storyboard) fn build_preview_image_response(
    storyboard_id: i32,
    preview: StoryboardPreviewData,
) -> PreviewImageResponse {
    PreviewImageResponse {
        storyboard_id,
        image_url: preview.file_path,
        prompt: preview.prompt,
    }
}
