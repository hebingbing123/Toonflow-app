use sqlx::types::Json as SqlxJson;
use uuid::Uuid;

use crate::error::ApiError;

use super::types::{AgentDeployConfig, AgentDeployConfigItem, AgentDeployListItem};

pub(super) fn static_agent_deploy_list() -> Vec<AgentDeployListItem> {
    vec![
        AgentDeployListItem {
            id: 1,
            model: String::new(),
            key: "scriptAgent".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "剧本Agent".into(),
            desc: "用于读取原文生成故事骨架、改编策略，建议使用具备强大文本理解和生成能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 2,
            model: String::new(),
            key: "productionAgent".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "生产Agent".into(),
            desc: "对工作流进行调度和管理，建议使用具备较强的逻辑推理和任务管理能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 3,
            model: String::new(),
            key: "universalAi".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "通用AI".into(),
            desc: "用于小说事件提取、资产提示词生成、台词提取等边缘功能，建议使用具备较强文本处理能力的模型".into(),
            disabled: false,
            icon: String::new(),
        },
        AgentDeployListItem {
            id: 4,
            model: String::new(),
            key: "ttsDubbing".into(),
            model_name: String::new(),
            vendor_id: None,
            name: "TTS配音".into(),
            desc: "根据剧本内容生成角色配音，支持多种声音风格和情绪".into(),
            disabled: true,
            icon: String::new(),
        },
    ]
}

pub(super) fn static_agent_deploy_item_by_id(id: i32) -> Option<AgentDeployListItem> {
    static_agent_deploy_list()
        .into_iter()
        .find(|item| item.id == id)
}

pub(crate) async fn load_agent_deploy_config(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<AgentDeployConfig, ApiError> {
    let row: Option<SqlxJson<AgentDeployConfig>> = sqlx::query_scalar(
        r#"
        SELECT agent_deploy_config FROM app_user_profile WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.map(|j| j.0).unwrap_or_default())
}

pub(super) async fn save_agent_deploy_config(
    pool: &sqlx::PgPool,
    uid: Uuid,
    cfg: &AgentDeployConfig,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, agent_deploy_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET agent_deploy_config = EXCLUDED.agent_deploy_config,
            updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(SqlxJson(cfg))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) fn insert_config_item(
    cfg: &mut AgentDeployConfig,
    key: String,
    model: String,
    model_name: String,
    vendor_id: Option<String>,
) {
    cfg.rows.insert(
        key,
        AgentDeployConfigItem {
            model,
            model_name,
            vendor_id,
        },
    );
}
