//! OpenAPI fragment for static model catalog routes (`/api/v1/models/*`).

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::vendor::catalog::list_models,
        crate::vendor::catalog::text_model_default,
        crate::vendor::catalog::patch_text_model_default,
        crate::vendor::catalog::model_detail,
    ),
    components(schemas(
        crate::vendor::catalog::types::ModelListEntry,
        crate::vendor::catalog::types::ModelDetailResponse,
        crate::vendor::catalog::pricing::ModelPricingPublic,
    ))
)]
pub struct VendorCatalogOpenApi;
