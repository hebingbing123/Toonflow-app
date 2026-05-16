use sqlx::FromRow;

#[derive(Debug, Clone)]
pub(crate) struct LocalArtStyleCover {
    pub(crate) bytes: Vec<u8>,
    pub(crate) ext: &'static str,
}

#[derive(Debug, FromRow)]
pub(super) struct ArtStyleFileUrlRow {
    pub(super) file_url: Option<String>,
}
