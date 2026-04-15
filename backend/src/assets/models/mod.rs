//! 资产 API 的请求/响应类型。

mod core;
mod workbench;

pub(crate) use core::WorkbenchOwnedAssetMetaRow;
pub(crate) use core::{
    AssetImageFileSource, AssetPatchCurrent, CornerScapeBody, CornerScapeDbRow,
    CornerScapeResponse, CreateAssetBody, CreateAssetImageBody, PatchAssetBody,
    PatchAssetImageBody,
};
pub use core::{
    AssetImageListItem, AssetImageRow, AssetRow, CornerScapeAssetItem, ListAssetImagesResponse,
    ListAssetsQuery, ListAssetsResponse,
};
pub(crate) use workbench::*;
