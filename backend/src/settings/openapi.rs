//! OpenAPI aggregate for settings, vendor HTTP, and agent memory routes.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(paths(
    crate::settings::dev::get_switch_ai_dev_tool,
    crate::settings::dev::put_switch_ai_dev_tool,
    crate::settings::about::post_check_update,
    crate::settings::about::post_download_app,
    crate::settings::help_hub::get_help_hub_links,
    crate::settings::outbound_webhooks::post_outbound_webhook_create,
    crate::settings::outbound_webhooks::get_outbound_webhook_list,
    crate::settings::outbound_webhooks::delete_outbound_webhook,
    crate::settings::outbound_webhooks::post_outbound_webhook_test,
    crate::settings::danger::post_delete_all_data,
    crate::settings::danger::post_clear_database,
    crate::settings::memory_config::get_memory_config,
    crate::settings::memory_config::post_memory_config,
    crate::settings::memory_config::post_clear_agent_memories_type_field_alias,
    crate::settings::agent_deploy::post_agent_deploy_list,
    crate::settings::agent_deploy::post_deploy_agent_model,
    crate::settings::agent_deploy::post_agent_set_key,
    crate::settings::vendors::handlers::summary::get_vendors_summary,
    crate::settings::vendors::handlers::model_test::post_vendor_model_test,
    crate::settings::vendors::handlers::vendor_manage::post_add_vendor,
    crate::settings::vendors::handlers::vendor_manage::post_update_vendor,
    crate::settings::vendors::handlers::vendor_manage::post_delete_vendor,
    crate::settings::vendors::handlers::vendor_manage::post_enable_vendor,
    crate::settings::vendors::handlers::vendor_manage::post_update_vendor_code,
    crate::settings::vendors::handlers::vendor_manage::post_vendor_code_from_link,
    crate::settings::vendors::handlers::credential::post_store_credential,
    crate::settings::vendors::handlers::credential::get_credential,
    crate::settings::vendors::handlers::credential::delete_credential,
    crate::settings::agent_memory::query_memory,
    crate::settings::agent_memory::clear_memory,
    crate::settings::agent_memory::append_memory,
))]
pub struct SettingsOpenApi;
