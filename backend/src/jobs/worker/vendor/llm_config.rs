use sqlx::PgPool;
use uuid::Uuid;

use crate::llm::LlmConfig;
use crate::settings::vendors::load_user_vendor_config;
use crate::state::AppState;
use crate::vendor::catalog::llm_endpoint::build_llm_config;

use super::super::JobRunError;

pub(super) async fn vendor_probe_llm_config(
    state: &AppState,
    pool: Option<&PgPool>,
    owner_user_id: Uuid,
    vendor_numeric_id: i32,
    api_key_override: Option<String>,
    model_name: &str,
) -> Result<LlmConfig, JobRunError> {
    let vendor_id_str = vendor_numeric_id.to_string();
    let user_settings_owned = if let Some(pool) = pool {
        let user_cfg = load_user_vendor_config(pool, owner_user_id)
            .await
            .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
        user_cfg
            .get_vendor(&vendor_id_str)
            .map(|e| e.settings.clone())
    } else {
        None
    };

    build_llm_config(
        vendor_numeric_id,
        model_name.to_string(),
        user_settings_owned.as_ref(),
        api_key_override,
        state.llm.as_ref(),
    )
    .map_err(JobRunError::Failed)
}
