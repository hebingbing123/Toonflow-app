//! 提供商配置模块。
//!
//! 遗留 `POST /api/setting/vendorConfig/getVendorList` 返回 SQLite `o_vendorConfig` 行（包括 `inputValues` 密钥）。
//! SaaS：`GET …/vendors/summary` 合并静态目录与来自 `app_user_profile` 的每个用户的 `vendor_config`。
//! `POST …/vendors/{add,update,delete,enable,update-code,code-from-link}` 将提供商元数据持久化到 Postgres 用户配置，
//! 但从不执行 TS、获取远程代码或存储 API 密钥。自定义/链接提供商代码仅作为元数据存储。
//! `POST …/model-test` 验证遗留请求体，入队 `settings.vendor.model_test`；
//! Worker 然后执行实时探测：文本/图片优先使用存储的提供商凭证并回退到服务器 LLM 环境，
//! 视频解析提供商特定的最小生成请求。
//! API 密钥（`inputValues`）故意不存储；使用服务器环境或 Vault。

mod dto;
mod handlers;
mod store;

pub(super) const MAX_VENDOR_MODEL_TEST_FIELD_LEN: usize = 512;

use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    handlers::router()
}

#[cfg(test)]
mod tests;
