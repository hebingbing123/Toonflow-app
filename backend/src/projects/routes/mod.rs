//! 项目 REST 路由（`POST /api/v1/projects/*`）。
//!
//! 项目 CRUD 和遗留项目端点的处理器。

pub(crate) mod audit;
pub(crate) mod characters;
pub(crate) mod common;
pub(crate) mod export;
pub(crate) mod handlers;
pub(crate) mod tts;
pub(crate) mod types;
mod validation;
pub(crate) mod video_count;

#[cfg(test)]
mod validation_integration_test;

use axum::{routing::get, Router};

use crate::state::AppState;

use handlers::{
    create_project, create_project_member, delete_project_by_id, delete_project_member,
    get_project_by_id, list_project_audit, list_project_members, list_projects,
    patch_project_by_id, patch_project_member, patch_style_config, project_assets_overview_by_id,
    project_home_by_id, project_overview_by_id, project_production_overview_by_id,
    project_short_video_assembly_by_id, project_short_video_export_check_by_id,
    project_short_video_pre_assembly_by_id, project_short_video_readiness_by_id,
    project_short_video_timeline_apply_template, project_short_video_timeline_by_id,
    project_short_video_timeline_preview, project_short_video_timeline_put,
    project_short_video_timeline_reorder, project_short_video_timeline_restore,
    project_short_video_timeline_revisions, project_stats_by_id, projects_summary,
};

pub fn router() -> Router<AppState> {
    Router::new()
        // Export routes
        .route(
            "/api/v1/export/start",
            axum::routing::post(export::start_export),
        )
        .route("/api/v1/export/tasks", get(export::list_export_tasks))
        .route(
            "/api/v1/export/tasks/{task_id}",
            get(export::get_export_task),
        )
        .route(
            "/api/v1/export/cancel",
            axum::routing::post(export::cancel_export),
        )
        // TTS routes
        .route(
            "/api/v1/tts/generate",
            axum::routing::post(tts::generate_tts),
        )
        .route(
            "/api/v1/tts/batch-generate",
            axum::routing::post(tts::batch_generate_tts),
        )
        .route("/api/v1/tts/tasks", get(tts::list_tts_tasks))
        .route("/api/v1/tts/tasks/{task_id}", get(tts::get_tts_task))
        .route(
            "/api/v1/tts/cancel",
            axum::routing::post(tts::cancel_tts_task),
        )
        .route(
            "/api/v1/tts/retry",
            axum::routing::post(tts::retry_tts_task),
        )
        .route("/api/v1/tts/preview", axum::routing::post(tts::preview_tts))
        .route(
            "/api/v1/tts/emotion-presets",
            get(tts::list_emotion_presets),
        )
        .route(
            "/api/v1/tts/clone-voice",
            axum::routing::post(tts::clone_voice),
        )
        // Existing project routes
        .route("/api/v1/projects/summary", get(projects_summary))
        .route("/api/v1/projects", get(list_projects).post(create_project))
        .route(
            "/api/v1/projects/{project_id}/members",
            get(list_project_members).post(create_project_member),
        )
        .route(
            "/api/v1/projects/{project_id}/audit",
            get(list_project_audit),
        )
        .route(
            "/api/v1/projects/{project_id}/members/{user_id}",
            axum::routing::patch(patch_project_member).delete(delete_project_member),
        )
        .route(
            "/api/v1/projects/{project_id}/home",
            get(project_home_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/overview",
            get(project_overview_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/stats",
            get(project_stats_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-readiness",
            get(project_short_video_readiness_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/production-overview",
            get(project_production_overview_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/assets-overview",
            get(project_assets_overview_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-assembly",
            get(project_short_video_assembly_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-export-check",
            get(project_short_video_export_check_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-pre-assembly",
            axum::routing::post(project_short_video_pre_assembly_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline",
            get(project_short_video_timeline_by_id).put(project_short_video_timeline_put),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline/preview",
            axum::routing::post(project_short_video_timeline_preview),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline/reorder",
            axum::routing::post(project_short_video_timeline_reorder),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline/apply-template",
            axum::routing::post(project_short_video_timeline_apply_template),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline/revisions",
            get(project_short_video_timeline_revisions),
        )
        .route(
            "/api/v1/projects/{project_id}/short-video-timeline/restore",
            axum::routing::post(project_short_video_timeline_restore),
        )
        .route(
            "/api/v1/projects/{project_id}/style-config",
            axum::routing::patch(patch_style_config),
        )
        .route(
            "/api/v1/projects/{project_id}/characters",
            get(characters::list_project_characters).post(characters::create_project_character),
        )
        .route(
            "/api/v1/projects/{project_id}/characters/{character_id}",
            axum::routing::patch(characters::patch_project_character)
                .delete(characters::delete_project_character),
        )
        .route(
            "/api/v1/projects/{project_id}",
            get(get_project_by_id)
                .patch(patch_project_by_id)
                .delete(delete_project_by_id),
        )
}
