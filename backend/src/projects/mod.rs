//! Postgres 支持的项目 REST（`/api/v1/projects`）与手册等遗留 **`POST /api/v1/project/*`**（见 `manuals`）。

pub mod model_routing;
pub mod models;
mod openapi;
pub mod routes;
pub mod style_pack_paths;

pub use openapi::ProjectsOpenApi;
