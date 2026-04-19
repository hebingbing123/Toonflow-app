use serde::{Deserialize, Serialize};

use crate::production::{VideoItem, WorkbenchGenerateVideoBody};

pub(crate) mod generate;
pub(crate) mod list;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct VideoListResponse {
    videos: Vec<VideoItem>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct VideoListBody {
    project_id: i32,
    #[serde(default)]
    track_id: Option<i32>,
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    offset: Option<i64>,
}

#[allow(unused_imports)]
pub(crate) use generate::__path_post_workbench_generate_video;
pub(in crate::production) use generate::post_workbench_generate_video;
#[allow(unused_imports)]
pub(crate) use list::__path_post_workbench_get_video_list;
pub(in crate::production) use list::post_workbench_get_video_list;
