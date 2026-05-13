use std::path::{Path as FsPath, PathBuf};

use tokio::fs;
use uuid::Uuid;

use crate::error::ApiError;

use super::types::LocalArtStyleCover;

pub(crate) fn art_style_cover_api_path(numeric_id: i32) -> String {
    format!("/api/v1/art-styles/numeric/{numeric_id}/cover")
}

fn art_style_cover_file_path(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
    ext: &str,
) -> PathBuf {
    root.join(owner_user_id.to_string())
        .join(format!("{numeric_id}.{ext}"))
}

fn existing_art_style_cover_paths(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
) -> [PathBuf; 3] {
    [
        art_style_cover_file_path(root, owner_user_id, numeric_id, "png"),
        art_style_cover_file_path(root, owner_user_id, numeric_id, "jpg"),
        art_style_cover_file_path(root, owner_user_id, numeric_id, "webp"),
    ]
}

pub(crate) async fn delete_local_art_style_cover_files(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
) {
    for path in existing_art_style_cover_paths(root, owner_user_id, numeric_id) {
        let _ = fs::remove_file(path).await;
    }
}

pub(crate) async fn persist_local_art_style_cover(
    root: &FsPath,
    owner_user_id: Uuid,
    numeric_id: i32,
    cover: &LocalArtStyleCover,
) -> Result<(), ApiError> {
    let dir = root.join(owner_user_id.to_string());
    fs::create_dir_all(&dir).await.map_err(|e| {
        crate::error::bad_request_i18n(
            &format!("art style cover mkdir failed: {e}"),
            &format!("art style cover 创建目录失败：{e}"),
        )
    })?;
    delete_local_art_style_cover_files(root, owner_user_id, numeric_id).await;
    let path = art_style_cover_file_path(root, owner_user_id, numeric_id, cover.ext);
    fs::write(&path, &cover.bytes).await.map_err(|e| {
        crate::error::bad_request_i18n(
            &format!("art style cover write failed: {e}"),
            &format!("art style cover 写入失败：{e}"),
        )
    })?;
    Ok(())
}

pub(crate) fn art_style_cover_file_path_for_ext(
    root: &FsPath,
    uid: Uuid,
    numeric_id: i32,
    ext: &str,
) -> PathBuf {
    art_style_cover_file_path(root, uid, numeric_id, ext)
}
