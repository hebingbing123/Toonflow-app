use serde_json::{json, Value};
use sqlx::types::Json as SqlxJson;

use crate::error::helpers::bad_request_i18n;
use crate::error::ApiError;
use crate::workspaces::ensure_personal_workspace;

use super::types::{
    PlatformConfigResponse, PlatformConfigToggleSet, PlatformConfigWorkspaceContext,
};

const WORKSPACE_PLATFORM_CONFIG_KEY: &str = "platform_config";
const PLAN_OVERRIDES_ENV: &str = "OPENFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON";

#[derive(Debug, Clone)]
pub(super) struct ResolvedWorkspacePlatformConfig {
    pub summary: PlatformConfigWorkspaceContext,
    pub override_toggles: Option<PlatformConfigToggleSet>,
}

pub(super) async fn load_platform_config_response(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    defaults: PlatformConfigToggleSet,
) -> Result<PlatformConfigResponse, ApiError> {
    let plan_tier = load_user_plan_tier(pool, uid).await?;
    let plan_override = load_plan_platform_config_override(&plan_tier)?;
    let user_override_raw = load_user_platform_config_raw(pool, uid).await?;
    let has_user_override = user_override_raw.is_some();
    let user_override = user_override_raw.clone().unwrap_or(defaults.clone());
    let workspace = resolve_current_workspace_platform_config(pool, uid).await?;
    let mut effective = defaults;
    if let Some(plan_override_cfg) = plan_override.clone() {
        effective = plan_override_cfg;
    }
    if let Some(workspace_override) = workspace
        .as_ref()
        .and_then(|ctx| ctx.override_toggles.clone())
    {
        effective = workspace_override;
    }
    if let Some(user_override_cfg) = user_override_raw {
        effective = merge_platform_config(effective, user_override_cfg);
    }

    let has_plan_override = plan_override.is_some();
    let has_workspace_override = workspace
        .as_ref()
        .and_then(|ctx| ctx.override_toggles.as_ref())
        .is_some();
    let scope = match (has_plan_override, has_workspace_override, has_user_override) {
        (true, true, true) => "plan+workspace+user",
        (true, true, false) => "plan+workspace",
        (true, false, true) => "plan+user",
        (true, false, false) => "plan",
        (false, true, true) => "workspace+user",
        (false, true, false) => "workspace",
        (false, false, true) => "user",
        (false, false, false) => "defaults",
    };

    Ok(PlatformConfigResponse {
        scope: scope.into(),
        schema_version: 1,
        effective,
        plan_tier,
        plan_override: plan_override.clone(),
        has_plan_override,
        user_override,
        has_user_override,
        workspace_override: workspace
            .as_ref()
            .and_then(|ctx| ctx.override_toggles.clone()),
        has_workspace_override,
        current_workspace: workspace.map(|ctx| ctx.summary),
    })
}

async fn load_user_plan_tier(pool: &sqlx::PgPool, uid: uuid::Uuid) -> Result<String, ApiError> {
    let tier: Option<String> =
        sqlx::query_scalar("SELECT plan_tier FROM public.app_user_profile WHERE user_id = $1")
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .flatten();
    Ok(tier
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "free".to_string()))
}

async fn load_user_platform_config_raw(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
) -> Result<Option<PlatformConfigToggleSet>, ApiError> {
    let row: Option<(Option<SqlxJson<PlatformConfigToggleSet>>,)> =
        sqlx::query_as(r#"SELECT platform_config FROM app_user_profile WHERE user_id = $1"#)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.and_then(|r| r.0).map(|j| j.0))
}

pub(super) async fn save_user_platform_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    cfg: &PlatformConfigToggleSet,
) -> Result<(), ApiError> {
    let cfg_json = SqlxJson(cfg.clone());
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, platform_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          platform_config = EXCLUDED.platform_config,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(cfg_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) async fn clear_user_platform_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, platform_config, updated_at)
        VALUES ($1, NULL, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          platform_config = NULL,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) async fn resolve_current_workspace_platform_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
) -> Result<Option<ResolvedWorkspacePlatformConfig>, ApiError> {
    let personal_workspace = ensure_personal_workspace(pool, uid).await?;
    let current_workspace_id: Option<uuid::Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();

    let resolved = if let Some(current_id) = current_workspace_id {
        let row: Option<(uuid::Uuid, String, String, String, Value)> = sqlx::query_as(
            r#"
            SELECT w.id, w.name, w.workspace_type::text, m.role, w.metadata
            FROM public.app_workspace w
            INNER JOIN public.app_workspace_member m ON m.workspace_id = w.id
            WHERE w.id = $1
              AND m.user_id = $2
              AND w.archived_at IS NULL
            LIMIT 1
            "#,
        )
        .bind(current_id)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if let Some((id, name, workspace_type, role, metadata)) = row {
            Some((id, name, workspace_type, role, metadata))
        } else {
            sqlx::query(
                r#"
                UPDATE public.app_user_profile
                SET current_workspace_id = $2, updated_at = NOW()
                WHERE user_id = $1
                "#,
            )
            .bind(uid)
            .bind(personal_workspace.workspace_id)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            Some((
                personal_workspace.workspace_id,
                personal_workspace.workspace_name,
                personal_workspace.workspace_type,
                "owner".to_string(),
                json!({}),
            ))
        }
    } else {
        Some((
            personal_workspace.workspace_id,
            personal_workspace.workspace_name,
            personal_workspace.workspace_type,
            "owner".to_string(),
            json!({}),
        ))
    };

    match resolved {
        Some((id, name, workspace_type, role, metadata)) => {
            Ok(Some(ResolvedWorkspacePlatformConfig {
                override_toggles: parse_workspace_platform_config(&workspace_type, metadata)?,
                summary: PlatformConfigWorkspaceContext {
                    id,
                    name,
                    workspace_type: workspace_type.clone(),
                    role: role.clone(),
                    can_manage_override: workspace_type == "enterprise"
                        && matches!(role.as_str(), "owner" | "admin"),
                },
            }))
        }
        None => Ok(None),
    }
}

pub(super) async fn save_workspace_platform_config(
    pool: &sqlx::PgPool,
    workspace_id: uuid::Uuid,
    cfg: &PlatformConfigToggleSet,
) -> Result<(), ApiError> {
    let cfg_value = serde_json::to_value(cfg).map_err(|e| {
        bad_request_i18n(
            &format!("Failed to serialize platform config: {}", e),
            &format!("平台配置序列化失败：{}", e),
        )
    })?;
    let cfg_json = SqlxJson(cfg_value);
    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET
          metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{platform_config}',
            $2::jsonb,
            true
          ),
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .bind(cfg_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) async fn clear_workspace_platform_config(
    pool: &sqlx::PgPool,
    workspace_id: uuid::Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET
          metadata = COALESCE(metadata, '{}'::jsonb) - 'platform_config',
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

fn parse_workspace_platform_config(
    workspace_type: &str,
    metadata: Value,
) -> Result<Option<PlatformConfigToggleSet>, ApiError> {
    if workspace_type != "enterprise" {
        return Ok(None);
    }
    let Some(raw) = metadata
        .as_object()
        .and_then(|obj| obj.get(WORKSPACE_PLATFORM_CONFIG_KEY))
        .cloned()
    else {
        return Ok(None);
    };

    // Enterprise workspace override must be explicit and complete; do not silently
    // default missing fields for governance-critical toggles.
    let Some(obj) = raw.as_object() else {
        return Err(bad_request_i18n(
            "workspace platform_config is invalid: expected JSON object",
            "工作区 platform_config 无效：期望 JSON 对象",
        ));
    };
    const REQUIRED_KEYS: [&str; 7] = [
        "helpHubEnabled",
        "qualityDashboardEnabled",
        "qualityRefreshControlsEnabled",
        "platformStatusEnabled",
        "workspaceActivityEnabled",
        "benchmarkPaneEnabled",
        "jobsPaneEnabled",
    ];
    for key in REQUIRED_KEYS {
        if !obj.contains_key(key) {
            return Err(bad_request_i18n(
                &format!("workspace platform_config is invalid: missing required key '{key}'"),
                &format!("工作区 platform_config 无效：缺少必需键 '{key}'"),
            ));
        }
    }

    serde_json::from_value(Value::Object(obj.clone()))
        .map(Some)
        .map_err(|e| {
            bad_request_i18n(
                &format!("workspace platform_config is invalid: {e}"),
                &format!("工作区 platform_config 无效：{e}"),
            )
        })
}

fn merge_platform_config(
    _base: PlatformConfigToggleSet,
    override_cfg: PlatformConfigToggleSet,
) -> PlatformConfigToggleSet {
    override_cfg
}

fn load_plan_platform_config_override(
    plan_tier: &str,
) -> Result<Option<PlatformConfigToggleSet>, ApiError> {
    let Ok(raw) = std::env::var(PLAN_OVERRIDES_ENV) else {
        return Ok(None);
    };
    let normalized = raw.trim();
    if normalized.is_empty() {
        return Ok(None);
    }
    let parsed: std::collections::BTreeMap<String, PlatformConfigToggleSet> =
        serde_json::from_str(normalized).map_err(|e| {
            bad_request_i18n(
                &format!("{PLAN_OVERRIDES_ENV} must be a JSON object keyed by plan tier: {e}"),
                &format!("{PLAN_OVERRIDES_ENV} 必须是按计划层级键入的 JSON 对象：{e}"),
            )
        })?;
    let normalized_tier = plan_tier.trim().to_ascii_lowercase();
    Ok(parsed
        .get(plan_tier)
        .cloned()
        .or_else(|| parsed.get(&normalized_tier).cloned())
        .or_else(|| parsed.get("default").cloned())
        .or_else(|| parsed.get("*").cloned()))
}

#[cfg(test)]
mod tests {
    use super::*;

    static PLAN_OVERRIDE_ENV_MUTEX: std::sync::OnceLock<std::sync::Mutex<()>> =
        std::sync::OnceLock::new();

    fn sample_toggle(enabled: bool) -> PlatformConfigToggleSet {
        PlatformConfigToggleSet {
            help_hub_enabled: enabled,
            quality_dashboard_enabled: enabled,
            quality_refresh_controls_enabled: enabled,
            platform_status_enabled: enabled,
            workspace_activity_enabled: enabled,
            benchmark_pane_enabled: enabled,
            jobs_pane_enabled: enabled,
        }
    }

    fn restore_plan_override_env(previous: Option<String>) {
        match previous {
            Some(value) => std::env::set_var(PLAN_OVERRIDES_ENV, value),
            None => std::env::remove_var(PLAN_OVERRIDES_ENV),
        }
    }

    #[test]
    fn load_plan_override_prefers_exact_then_lowercase_then_default_then_wildcard() {
        let _guard = PLAN_OVERRIDE_ENV_MUTEX
            .get_or_init(|| std::sync::Mutex::new(()))
            .lock()
            .expect("plan override env mutex");
        let previous = std::env::var(PLAN_OVERRIDES_ENV).ok();
        std::env::set_var(
            PLAN_OVERRIDES_ENV,
            r#"{
              "Enterprise": {
                "helpHubEnabled": false,
                "qualityDashboardEnabled": false,
                "qualityRefreshControlsEnabled": false,
                "platformStatusEnabled": false,
                "workspaceActivityEnabled": false,
                "benchmarkPaneEnabled": false,
                "jobsPaneEnabled": false
              },
              "enterprise": {
                "helpHubEnabled": true,
                "qualityDashboardEnabled": true,
                "qualityRefreshControlsEnabled": true,
                "platformStatusEnabled": true,
                "workspaceActivityEnabled": true,
                "benchmarkPaneEnabled": true,
                "jobsPaneEnabled": true
              },
              "default": {
                "helpHubEnabled": false,
                "qualityDashboardEnabled": true,
                "qualityRefreshControlsEnabled": true,
                "platformStatusEnabled": true,
                "workspaceActivityEnabled": true,
                "benchmarkPaneEnabled": true,
                "jobsPaneEnabled": true
              },
              "*": {
                "helpHubEnabled": true,
                "qualityDashboardEnabled": false,
                "qualityRefreshControlsEnabled": false,
                "platformStatusEnabled": false,
                "workspaceActivityEnabled": false,
                "benchmarkPaneEnabled": false,
                "jobsPaneEnabled": false
              }
            }"#,
        );

        let exact = load_plan_platform_config_override("Enterprise")
            .expect("load exact")
            .expect("exact override");
        assert!(!exact.help_hub_enabled);

        let lowercase = load_plan_platform_config_override("ENTERPRISE")
            .expect("load lowercase fallback")
            .expect("lowercase override");
        assert!(lowercase.help_hub_enabled);

        let default_override = load_plan_platform_config_override("pro")
            .expect("load default fallback")
            .expect("default override");
        assert!(!default_override.help_hub_enabled);
        assert!(default_override.quality_dashboard_enabled);

        std::env::set_var(
            PLAN_OVERRIDES_ENV,
            r#"{
              "*": {
                "helpHubEnabled": false,
                "qualityDashboardEnabled": false,
                "qualityRefreshControlsEnabled": false,
                "workspaceActivityEnabled": false,
                "benchmarkPaneEnabled": false,
                "jobsPaneEnabled": false
              }
            }"#,
        );
        let wildcard = load_plan_platform_config_override("starter")
            .expect("load wildcard fallback")
            .expect("wildcard override");
        assert!(!wildcard.help_hub_enabled);

        restore_plan_override_env(previous);
    }

    #[test]
    fn load_plan_override_rejects_invalid_json() {
        let _guard = PLAN_OVERRIDE_ENV_MUTEX
            .get_or_init(|| std::sync::Mutex::new(()))
            .lock()
            .expect("plan override env mutex");
        let previous = std::env::var(PLAN_OVERRIDES_ENV).ok();
        std::env::set_var(PLAN_OVERRIDES_ENV, r#"["bad"]"#);
        let err = load_plan_platform_config_override("enterprise").expect_err("invalid json");
        match err {
            ApiError::BadRequest(message) => {
                assert!(message.contains(PLAN_OVERRIDES_ENV));
            }
            other => panic!("expected bad request, got {other:?}"),
        }
        restore_plan_override_env(previous);
    }

    #[test]
    fn merge_platform_config_returns_override_layer() {
        let merged = merge_platform_config(sample_toggle(true), sample_toggle(false));
        assert!(!merged.help_hub_enabled);
        assert!(!merged.jobs_pane_enabled);
    }

    #[test]
    fn parse_workspace_platform_config_ignores_non_enterprise_workspace() {
        let parsed = parse_workspace_platform_config(
            "personal",
            serde_json::json!({
                "platform_config": {
                    "helpHubEnabled": false,
                    "qualityDashboardEnabled": false,
                    "qualityRefreshControlsEnabled": false,
                    "workspaceActivityEnabled": false,
                    "benchmarkPaneEnabled": false,
                    "jobsPaneEnabled": false
                }
            }),
        )
        .expect("parse personal workspace metadata");
        assert!(parsed.is_none());
    }

    #[test]
    fn parse_workspace_platform_config_rejects_invalid_enterprise_payload() {
        let err = parse_workspace_platform_config(
            "enterprise",
            serde_json::json!({
                "platform_config": {
                    "helpHubEnabled": false
                }
            }),
        )
        .expect_err("invalid enterprise workspace payload should fail");
        match err {
            ApiError::BadRequest(message) => {
                assert!(message.contains("workspace platform_config is invalid"));
            }
            other => panic!("expected bad request, got {other:?}"),
        }
    }
}
