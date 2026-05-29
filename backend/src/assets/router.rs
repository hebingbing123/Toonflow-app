//! 资产模块路由注册。

use axum::{
    routing::{get, post, put},
    Router,
};

use crate::state::AppState;

use super::blocks;
use super::crud;
use super::crud_images;
use super::generate;
use super::workbench_query;
use super::workbench_write;

pub fn router() -> Router<AppState> {
    use blocks::handlers::{
        create_project_asset_block_for_project, get_project_asset_block_file_for_project,
        list_project_asset_blocks_for_project,
    };
    use crud::*;
    use crud_images::*;
    use workbench_query::*;
    use workbench_write::*;

    Router::new()
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/nested",
            post(post_project_workbench_nested_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/image-bundle",
            post(post_project_workbench_image_bundle),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/upload-clip",
            post(post_project_workbench_upload_clip),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/material-data",
            post(post_project_workbench_material_data),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/batch-generation-data",
            post(post_project_workbench_batch_generation_data),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/polling-image-assets",
            post(post_project_workbench_polling_image_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/polling-prompt-assets",
            post(post_project_workbench_polling_prompt_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/add-assets",
            post(post_project_workbench_add_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/update-assets",
            post(post_project_workbench_update_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/save-assets",
            post(post_project_workbench_save_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/del-assets",
            post(post_project_workbench_del_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/batch-delete",
            post(post_project_workbench_batch_delete_assets),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/workbench/del-image",
            post(post_project_workbench_del_image),
        )
        .route(
            "/api/v1/projects/{project_id}/assets",
            get(list_project_assets_for_project).post(create_project_asset_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/corner-scape",
            post(list_corner_scape_assets_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}/blocks",
            get(list_project_asset_blocks_for_project).post(create_project_asset_block_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}/blocks/{block_key}/file",
            get(get_project_asset_block_file_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}/images/{image_id}/file",
            get(get_project_asset_image_file_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}/images/{image_id}",
            get(get_project_asset_image_for_project)
                .patch(patch_project_asset_image_for_project)
                .delete(delete_project_asset_image_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}/images",
            get(list_project_asset_images_for_project).post(create_project_asset_image_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/assets/{asset_numeric_id}",
            get(get_project_asset_for_project)
                .patch(patch_project_asset_for_project)
                .delete(delete_project_asset_for_project),
        )
        .route(
            "/api/v1/projects/{project_id}/scripts/{script_numeric_id}/assets/{asset_numeric_id}",
            put(link_script_to_asset_for_project).delete(unlink_script_from_asset_for_project),
        )
        .merge(generate::router())
}
