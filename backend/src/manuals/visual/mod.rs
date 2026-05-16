//! 视觉手册模块。
//!
//! 与遗留 `/api/project/getVisualManual` 和 `addVisualManual` / `editVisualManual` / `deleteVisualManual` 兼容：
//! 读/写打包的 `art_skills`（Markdown + 图片）。`GET` / `POST /api/v1/visual-manual` 列出样式；变更 `POST /api/v1/project/*-visual-manual`。
//! `image` 条目是相对于 `data/skills` 的路径（无 OSS 签名）。客户端通过 `GET /api/v1/skills/binary?path=` 加载字节（需要 JWT）。

use crate::state::AppState;
use axum::routing::{get, post};
use axum::Router;

mod handlers;
mod slots;
mod storage;
mod types;
mod validation;

pub use types::{VisualManualEntry, VisualManualResponse, VisualManualStyle};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/visual-manual",
            get(handlers::get_visual_manual).post(handlers::post_visual_manual),
        )
        .route(
            "/api/v1/project/add-visual-manual",
            post(handlers::post_add_visual_manual),
        )
        .route(
            "/api/v1/project/edit-visual-manual",
            post(handlers::post_edit_visual_manual),
        )
        .route(
            "/api/v1/project/delete-visual-manual",
            post(handlers::post_delete_visual_manual),
        )
}

#[cfg(test)]
mod tests;
