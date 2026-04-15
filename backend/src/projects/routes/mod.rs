//! 项目 REST 路由（`POST /api/v1/projects/*`）。
//!
//! 项目 CRUD 和遗留项目端点的处理器。

mod common;
mod handlers;
mod types;

use axum::{routing::get, Router};

use crate::state::AppState;

use handlers::{
    create_project, delete_project_by_id, get_project_by_id, list_projects, patch_project_by_id,
    project_stats_by_id, projects_summary,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/projects/summary", get(projects_summary))
        .route("/api/v1/projects", get(list_projects).post(create_project))
        .route(
            "/api/v1/projects/{project_id}/stats",
            get(project_stats_by_id),
        )
        .route(
            "/api/v1/projects/{project_id}",
            get(get_project_by_id)
                .patch(patch_project_by_id)
                .delete(delete_project_by_id),
        )
}
