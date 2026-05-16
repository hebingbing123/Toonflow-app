//! 用户提示词模板（与遗留 SQLite `o_prompt` 和 `/api/setting/promptManage/getPrompt` / `updatePrompt` 兼容）。

use axum::{routing::get, Router};

use crate::state::AppState;

mod defaults;
mod handlers;
mod merge;
mod types;

#[cfg(test)]
mod tests;

pub use types::{PatchPromptBody, PromptTemplateJson};

// Handlers 与 utoipa `__path_*` 由 `openapi.rs` 的 `paths(...)` 引用。
#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_prompt, __path_list_prompts, __path_patch_prompt, get_prompt, list_prompts,
    patch_prompt,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/prompts", get(handlers::list_prompts))
        .route(
            "/api/v1/prompts/{numeric_id}",
            get(handlers::get_prompt).patch(handlers::patch_prompt),
        )
}
