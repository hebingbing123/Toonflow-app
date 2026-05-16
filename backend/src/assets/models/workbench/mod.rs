//! 资产工作台 HTTP 请求/响应模型（`…/assets/workbench/*`）。

mod batch_generation;
mod image;
mod material;
mod mutations;
mod nested_api;
mod polling;

pub(crate) use batch_generation::{
    WorkbenchBatchGenerationAssetItem, WorkbenchBatchGenerationDataBody,
    WorkbenchBatchGenerationDataResponse,
};
pub(crate) use image::{
    WorkbenchGetImageAssetRow, WorkbenchGetImageBody, WorkbenchGetImageResponse,
    WorkbenchGetImageTempAssetItem,
};
pub(crate) use material::{
    WorkbenchGetMaterialDataResponse, WorkbenchMaterialAssetItem, WorkbenchMaterialVideoItem,
};
pub(crate) use mutations::{
    WorkbenchAddAssetsBody, WorkbenchAssetMutationResponse, WorkbenchBatchDeleteAssetsBody,
    WorkbenchDelImageBody, WorkbenchDeleteAssetsBody, WorkbenchEmptyBody, WorkbenchSaveAssetsBody,
    WorkbenchUpdateAssetsBody, WorkbenchUploadClipBody, WorkbenchUploadClipResponse,
};
pub(crate) use nested_api::{
    WorkbenchGetAssetsApiChildItem, WorkbenchGetAssetsApiDbRow, WorkbenchGetAssetsApiParentItem,
    WorkbenchGetAssetsApiResponse, WorkbenchNestedAssetsBody,
};
pub(crate) use polling::{
    WorkbenchPollingImageAssetsBody, WorkbenchPollingImageAssetsItem,
    WorkbenchPollingPromptAssetsBody, WorkbenchPollingPromptAssetsItem,
};
