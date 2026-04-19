//! 导出请求中的 `shotId` 规范化（去重、排序）。

use crate::error::ApiError;

use super::super::common::normalize_storyboard_ids;
use super::super::types::ExportImageShotRef;

pub(super) fn normalize_export_shot_ids(
    shot_ids: &[ExportImageShotRef],
) -> Result<Vec<i32>, ApiError> {
    if shot_ids.is_empty() {
        return Err(ApiError::BadRequest(
            "shotId must be a non-empty array".into(),
        ));
    }

    let storyboard_ids = shot_ids
        .iter()
        .map(|shot| {
            let trimmed = shot.id.trim();
            let parsed: i32 = trimmed
                .parse()
                .map_err(|_| ApiError::BadRequest("shotId.id must be a positive integer".into()))?;
            if parsed <= 0 {
                return Err(ApiError::BadRequest(
                    "shotId.id must be a positive integer".into(),
                ));
            }
            Ok(parsed)
        })
        .collect::<Result<Vec<_>, _>>()?;

    normalize_storyboard_ids(&storyboard_ids)
}
