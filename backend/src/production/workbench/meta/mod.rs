mod common;
pub(crate) mod generate;
pub(crate) mod query;

#[allow(unused_imports)]
pub(crate) use generate::{
    __path_post_workbench_generate_video_prompt, __path_post_workbench_get_video_model_detail,
};
pub(in crate::production) use generate::{
    post_workbench_generate_video_prompt, post_workbench_get_video_model_detail,
};
#[allow(unused_imports)]
pub(crate) use query::__path_post_workbench_get_generate_data;
pub(in crate::production) use query::post_workbench_get_generate_data;
