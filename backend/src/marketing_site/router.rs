//! 将 `website/` 挂到 Axum 根路径（未匹配 API 路由时的 fallback）。

use axum::Router;
use tower_http::services::{ServeDir, ServeFile};

use super::resolve_dir;

pub fn merge_fallback(router: Router) -> Router {
    let Some(dir) = resolve_dir() else {
        return router;
    };

    tracing::info!(
        path = %dir.display(),
        "marketing site enabled (GET /, static assets under website/)"
    );

    let index = dir.join("index.html");
    let service = ServeDir::new(dir)
        .append_index_html_on_directories(true)
        .not_found_service(ServeFile::new(index));

    router.fallback_service(service)
}
