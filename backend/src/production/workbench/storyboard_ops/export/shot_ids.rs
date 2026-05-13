//! 导出请求中的 `shotId` 规范化（去重、排序）。

use crate::error::{bad_request_i18n, ApiError};

use super::super::common::normalize_storyboard_ids;
use super::super::types::ExportImageShotRef;

pub(super) fn normalize_export_shot_ids(
    shot_ids: &[ExportImageShotRef],
) -> Result<Vec<i32>, ApiError> {
    if shot_ids.is_empty() {
        return Err(bad_request_i18n(
            "shotId must be a non-empty array",
            "shotId 必须是非空数组",
        ));
    }

    let storyboard_ids = shot_ids
        .iter()
        .map(|shot| {
            let trimmed = shot.id.trim();
            let parsed: i32 = trimmed.parse().map_err(|_| {
                bad_request_i18n(
                    "shotId.id must be a positive integer",
                    "shotId.id 必须是正整数",
                )
            })?;
            if parsed <= 0 {
                return Err(bad_request_i18n(
                    "shotId.id must be a positive integer",
                    "shotId.id 必须是正整数",
                ));
            }
            Ok(parsed)
        })
        .collect::<Result<Vec<_>, _>>()?;

    normalize_storyboard_ids(&storyboard_ids)
}
