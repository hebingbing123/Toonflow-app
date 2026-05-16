//! 用户范围的 `app_art_style` REST（遗留 `o_artStyle` 列表/获取/创建/更新/删除子集）。

mod cover;
mod handlers;
mod types;

pub use types::{
    ArtStyleRow, ArtStyleSchemasOpenApi, CreateArtStyleBody, ExtractArtStylePromptBody,
    ExtractArtStylePromptResponse, ListArtStylesResponse, PatchArtStyleBody,
};

#[cfg(test)]
pub(super) use cover::parse_uploaded_cover;

pub fn router() -> axum::Router<crate::state::AppState> {
    handlers::router()
}

#[cfg(test)]
mod tests;
