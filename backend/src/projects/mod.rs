//! Postgres 支持的项目 REST（`/api/v1/projects`）与手册等遗留 **`POST /api/v1/project/*`**（见 `manuals`）。

pub mod routes;

pub use routes::ProjectRow;
