//! 异步脚本资产提取（遗留 `extractAssets`）：LLM 工具调用 + `app_asset` / `app_script_asset`。
//!
//! HTTP 立即返回（`200` + `accepted`），工作在 `tokio::spawn` 中运行（匹配遗留 Express 的 `res.send` 然后后台循环）。
//! 需要 `OPENAI_API_KEY` / `LLM_API_KEY` 和 `DATABASE_URL`。
//!
//! 子模块：`extract_job`、`tool`、`persist`、`util`。

use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::assets::resolve_owned_project_numeric_from_uuid_or_legacy_id;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

mod extract_job;
mod persist;
mod tool;
mod util;

pub(crate) const MAX_SCRIPT_IDS: usize = 100;
pub(crate) const MAX_GROUP_SIZE: usize = 20;
const DEFAULT_GROUP_SIZE: usize = 5;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExtractAssetsBody {
    /// Preferred: project primary key (`app_project.id`).
    #[serde(default)]
    pub project_uuid: Option<Uuid>,
    /// Legacy: stable project integer id (`app_project.numeric_id`).
    #[serde(default)]
    pub project_numeric_id: Option<i32>,
    pub script_numeric_ids: Vec<i32>,
    #[serde(default = "default_group_size")]
    pub group_size: usize,
}

fn default_group_size() -> usize {
    DEFAULT_GROUP_SIZE
}

#[derive(Debug, Serialize)]
pub struct ExtractAcceptedResponse {
    pub status: &'static str,
    pub message: &'static str,
}

pub fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/scripts/extract-assets",
        post(start_script_asset_extract),
    )
}

async fn start_script_asset_extract(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExtractAssetsBody>,
) -> Result<Json<ExtractAcceptedResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let project_uuid = body.project_uuid;
    let project_numeric_id_in = body.project_numeric_id;
    if project_uuid.is_none() && project_numeric_id_in.is_none() {
        return Err(ApiError::BadRequest(
            "Provide project_uuid (preferred) or legacy project_numeric_id".into(),
        ));
    }
    let mut script_ids: Vec<i32> = body
        .script_numeric_ids
        .into_iter()
        .filter(|id| *id > 0)
        .collect();
    script_ids.sort_unstable();
    script_ids.dedup();
    if script_ids.is_empty() {
        return Err(ApiError::BadRequest(
            "script_numeric_ids must be non-empty".into(),
        ));
    }
    if script_ids.len() > MAX_SCRIPT_IDS {
        return Err(ApiError::BadRequest(format!(
            "at most {MAX_SCRIPT_IDS} script_numeric_ids"
        )));
    }
    let group_size = body.group_size.clamp(1, MAX_GROUP_SIZE);

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let cfg = state.llm.as_ref().ok_or(ApiError::LlmNotConfigured)?;

    let project_numeric_id = resolve_owned_project_numeric_from_uuid_or_legacy_id(
        pool,
        uid,
        project_uuid,
        project_numeric_id_in,
    )
    .await?;

    let pool = pool.clone();
    let cfg = cfg.clone();
    let client = state.http_client.clone();

    tokio::spawn(async move {
        if let Err(e) = extract_job::run_extract_job(
            pool,
            cfg,
            client,
            uid,
            project_numeric_id,
            script_ids,
            group_size,
        )
        .await
        {
            tracing::error!(error = %e, "script_asset_extract job failed");
        }
    });

    Ok(Json(ExtractAcceptedResponse {
        status: "accepted",
        message: "asset extraction started",
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<ExtractAssetsBody>(
            r#"{"project_numeric_id":1,"script_numeric_ids":[1],"group_size":3,"x":1}"#,
        )
        .unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn extract_body_accepts_project_uuid_only() {
        let u = Uuid::from_u128(0x55);
        let b: ExtractAssetsBody = serde_json::from_str(&format!(
            r#"{{"project_uuid":"{u}","script_numeric_ids":[1,2]}}"#
        ))
        .unwrap();
        assert_eq!(b.project_uuid, Some(u));
        assert_eq!(b.project_numeric_id, None);
        assert_eq!(b.script_numeric_ids, vec![1, 2]);
    }

    #[test]
    fn extract_body_accepts_legacy_numeric_only() {
        let b: ExtractAssetsBody =
            serde_json::from_str(r#"{"project_numeric_id":7,"script_numeric_ids":[3]}"#).unwrap();
        assert!(b.project_uuid.is_none());
        assert_eq!(b.project_numeric_id, Some(7));
    }
}
