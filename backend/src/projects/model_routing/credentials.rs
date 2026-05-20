//! Build `LlmConfig` from a resolved catalog model id.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::llm::LlmConfig;
use crate::settings::vendors::load_user_vendor_config;
use crate::state::AppState;
use crate::vendor::catalog::llm_endpoint::build_openai_compatible_config;
use crate::vendor::catalog::lookup_detail;
use crate::vendor::user_credentials::{expand_vendor_id_candidates, load_stored_vendor_api_key};

pub async fn build_llm_config_for_model(
    state: &AppState,
    pool: &PgPool,
    actor_user_id: Uuid,
    model_id: &str,
) -> Result<LlmConfig, ApiError> {
    let detail = lookup_detail(model_id, false).ok_or_else(|| {
        ApiError::BadRequest(format!("unknown model_id for LlmConfig: {model_id}"))
    })?;

    let vendor_id = detail.vendor_id;
    let vendor_id_str = vendor_id.to_string();
    let user_cfg = load_user_vendor_config(pool, actor_user_id).await.ok();
    let user_settings = user_cfg
        .as_ref()
        .and_then(|cfg| cfg.get_vendor(&vendor_id_str))
        .map(|e| &e.settings);

    let candidates = expand_vendor_id_candidates(&vendor_id_str);
    let stored_key = load_stored_vendor_api_key(pool, actor_user_id, &candidates)
        .await
        .map_err(ApiError::DatabaseError)?;

    build_openai_compatible_config(
        vendor_id,
        detail.model_name.clone(),
        user_settings,
        stored_key,
        state.llm.as_ref(),
    )
    .map_err(ApiError::BadRequest)
}
