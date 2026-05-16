//! 导演手册模块（拆分自 `director.rs` 大文件）。

mod handlers;
mod storage;
mod types;

use axum::Router;

use crate::state::AppState;

const MAX_SLOT_BYTES: u64 = 2_000_000;
const MAX_README_BYTES: u64 = 256_000;
const MAX_BASE64_IMAGE_INPUT_CHARS: usize = 45_000_000;
const MAX_DECODED_IMAGE_BYTES: u64 = 25_000_000;

// 给 `backend/src/manuals/director/tests.rs` 使用（里面 `use super::*;`）。
#[cfg(test)]
use storage::load_director_manual_list;

#[cfg(test)]
mod tests;

pub fn router() -> Router<AppState> {
    handlers::router()
}
