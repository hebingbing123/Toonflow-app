//! 制作工作台相关图片任务（资产批量、分镜批量、编辑流）。

mod batch_assets;
mod edit_image_flow;
mod grid_split;
mod storyboard_batch;
mod storyboard_grid;

pub(super) use batch_assets::run_production_assets_batch_generate;
pub(super) use edit_image_flow::run_production_edit_image_generate_flow;
pub(super) use storyboard_batch::run_production_storyboard_batch_generate_image;
pub(super) use storyboard_grid::run_production_storyboard_grid_generate_and_assign;
