use serde_json::{json, Map, Value};
use sqlx::PgExecutor;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, sqlx::FromRow, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ProjectAuditResponse {
    pub id: i64,
    pub project_id: Uuid,
    pub workspace_id: Uuid,
    pub project_numeric_id: Option<i32>,
    pub actor_user_id: Uuid,
    pub action: String,
    pub target_user_id: Option<Uuid>,
    pub details: Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListProjectAuditEnvelope {
    pub items: Vec<ProjectAuditResponse>,
    pub has_more: bool,
}

#[derive(Debug, Clone, serde::Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ListProjectAuditQuery {
    #[serde(default)]
    pub action: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
}

pub(crate) fn normalize_project_audit_action(raw: Option<String>) -> Option<String> {
    raw.and_then(|value| {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_owned())
        }
    })
}

pub(crate) fn project_field_change_details(
    changed_fields: &[&str],
    project_name_before: Option<&str>,
    project_name_after: Option<&str>,
) -> Value {
    let mut map = Map::new();
    map.insert(
        "changed_fields".into(),
        Value::Array(
            changed_fields
                .iter()
                .map(|field| Value::String((*field).to_string()))
                .collect(),
        ),
    );
    if let Some(name) = project_name_before {
        map.insert(
            "project_name_before".into(),
            Value::String(name.to_string()),
        );
    }
    if let Some(name) = project_name_after {
        map.insert("project_name_after".into(), Value::String(name.to_string()));
    }
    Value::Object(map)
}

pub(crate) struct AppendProjectAudit<'a> {
    pub project_id: Uuid,
    pub workspace_id: Uuid,
    pub project_numeric_id: Option<i32>,
    pub actor_user_id: Uuid,
    pub action: &'a str,
    pub target_user_id: Option<Uuid>,
    pub details: Value,
}

pub(crate) async fn append_project_audit<'e, E>(
    executor: E,
    entry: AppendProjectAudit<'_>,
) -> Result<(), ApiError>
where
    E: PgExecutor<'e>,
{
    sqlx::query(
        r#"
        INSERT INTO public.app_project_audit (
          project_id,
          workspace_id,
          project_numeric_id,
          actor_user_id,
          action,
          target_user_id,
          details
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(entry.project_id)
    .bind(entry.workspace_id)
    .bind(entry.project_numeric_id)
    .bind(entry.actor_user_id)
    .bind(entry.action)
    .bind(entry.target_user_id)
    .bind(entry.details)
    .execute(executor)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) fn project_acl_details(role: &str, source: &str, previous_role: Option<&str>) -> Value {
    json!({
        "role": role,
        "source": source,
        "previous_role": previous_role,
    })
}

pub(crate) fn project_deleted_details(
    project_name: Option<&str>,
    project_numeric_id: i32,
) -> Value {
    json!({
        "project_name": project_name,
        "project_numeric_id": project_numeric_id,
    })
}
