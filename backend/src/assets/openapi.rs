//! OpenAPI schema registration for asset REST models (stub **`ref("AssetRow")`** resolution).

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(components(schemas(
    crate::assets::models::AssetRow,
    crate::assets::models::PatchAssetBody,
    crate::assets::models::ListAssetsResponse,
    crate::assets::models::CreateAssetBody,
)))]
pub struct AssetsSchemasOpenApi;
