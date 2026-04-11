//! Async **script asset extraction** (legacy `extractAssets`): LLM tool call + `app_asset` / `app_script_asset`.
//!
//! HTTP returns immediately (**`200`** + **`accepted`**) while work runs in **`tokio::spawn`** (matches legacy Express
//! `res.send` then background loop). Requires **`OPENAI_API_KEY`** / **`LLM_API_KEY`** and **`DATABASE_URL`**.

use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::llm::LlmConfig;
use crate::state::AppState;

const ADV_LOCK_ASSET_LEGACY_ID: i64 = 884_422_004;
const MAX_SCRIPT_IDS: usize = 100;
const MAX_GROUP_SIZE: usize = 20;
const DEFAULT_GROUP_SIZE: usize = 5;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExtractAssetsBody {
    /// Legacy **`o_project.id`** for the scripts' parent project.
    pub project_legacy_id: i32,
    pub script_legacy_ids: Vec<i32>,
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
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let cfg = state.llm.as_ref().ok_or(ApiError::LlmNotConfigured)?;

    if body.project_legacy_id <= 0 {
        return Err(ApiError::BadRequest(
            "project_legacy_id must be positive".into(),
        ));
    }
    let mut script_ids: Vec<i32> = body
        .script_legacy_ids
        .into_iter()
        .filter(|id| *id > 0)
        .collect();
    script_ids.sort_unstable();
    script_ids.dedup();
    if script_ids.is_empty() {
        return Err(ApiError::BadRequest(
            "script_legacy_ids must be non-empty".into(),
        ));
    }
    if script_ids.len() > MAX_SCRIPT_IDS {
        return Err(ApiError::BadRequest(format!(
            "at most {MAX_SCRIPT_IDS} script_legacy_ids"
        )));
    }
    let group_size = body.group_size.clamp(1, MAX_GROUP_SIZE);

    let pool = pool.clone();
    let cfg = cfg.clone();
    let client = state.http_client.clone();
    let project_legacy_id = body.project_legacy_id;

    tokio::spawn(async move {
        if let Err(e) = run_extract_job(
            pool,
            cfg,
            client,
            uid,
            project_legacy_id,
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

async fn run_extract_job(
    pool: PgPool,
    cfg: LlmConfig,
    client: reqwest::Client,
    uid: Uuid,
    project_legacy_id: i32,
    script_legacy_ids: Vec<i32>,
    group_size: usize,
) -> Result<(), String> {
    let system = load_system_prompt();

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM app_project WHERE legacy_id = $1 AND owner_user_id = $2"#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(&pool)
    .await
    .map_err(|e| e.to_string())?
    .ok_or_else(|| "project not found or not owned".to_string())?;

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 2, error_reason = NULL, updated_at = NOW()
        FROM app_project p
        WHERE s.project_id = p.id
          AND p.id = $1
          AND p.owner_user_id = $2
          AND s.legacy_id = ANY($3)
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(&script_legacy_ids)
    .execute(&pool)
    .await
    .map_err(|e| e.to_string())?;

    let script_map: Vec<(i32, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT s.legacy_id, s.name, s.content
        FROM app_script s
        WHERE s.project_id = $1 AND s.legacy_id = ANY($2)
        ORDER BY s.legacy_id
        "#,
    )
    .bind(project_uuid)
    .bind(&script_legacy_ids)
    .fetch_all(&pool)
    .await
    .map_err(|e| e.to_string())?;

    let mut map_by_legacy: std::collections::HashMap<i32, (Option<String>, Option<String>)> =
        std::collections::HashMap::new();
    for (lid, name, content) in script_map {
        map_by_legacy.insert(lid, (name, content));
    }

    for chunk in script_legacy_ids.chunks(group_size) {
        process_one_group(
            &pool,
            &cfg,
            &client,
            &system,
            project_uuid,
            uid,
            chunk,
            &map_by_legacy,
        )
        .await?;
    }

    Ok(())
}

#[allow(clippy::too_many_arguments)]
async fn process_one_group(
    pool: &PgPool,
    cfg: &LlmConfig,
    client: &reqwest::Client,
    system: &str,
    project_uuid: Uuid,
    uid: Uuid,
    chunk: &[i32],
    script_map: &std::collections::HashMap<i32, (Option<String>, Option<String>)>,
) -> Result<(), String> {
    let mut valid: Vec<(i32, String)> = Vec::new();

    for &sid in chunk {
        let Some((name, content)) = script_map.get(&sid).cloned() else {
            mark_script_failed(pool, project_uuid, uid, sid, "script not found in project").await?;
            continue;
        };
        let row: Option<(Option<i32>,)> = sqlx::query_as(
            r#"
            SELECT s.extract_state
            FROM app_script s
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE s.legacy_id = $1 AND s.project_id = $2 AND p.owner_user_id = $3
            "#,
        )
        .bind(sid)
        .bind(project_uuid)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| e.to_string())?;

        let Some((Some(2),)) = row else {
            continue;
        };

        let body = content.unwrap_or_default();
        let title = name.unwrap_or_default();
        valid.push((sid, format!("===== 【剧本ID: {sid}】{title} =====\n{body}")));
    }

    if valid.is_empty() {
        return Ok(());
    }

    let valid_ids: Vec<i32> = valid.iter().map(|(id, _)| *id).collect();

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 0, updated_at = NOW()
        FROM app_project p
        WHERE s.project_id = p.id AND p.id = $1 AND p.owner_user_id = $2
          AND s.legacy_id = ANY($3)
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(&valid_ids)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    let existing_rows: Vec<(String, String)> = sqlx::query_as(
        r#"SELECT name, asset_type FROM app_asset WHERE project_id = $1 ORDER BY name"#,
    )
    .bind(project_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| e.to_string())?;

    let existing_hint = if existing_rows.is_empty() {
        String::new()
    } else {
        format!(
            "\n\n【已有资产列表】：{}",
            existing_rows
                .iter()
                .map(|(n, t)| format!("{n}({t})"))
                .collect::<Vec<_>>()
                .join("、")
        )
    };

    let scripts_content = valid
        .iter()
        .map(|(_, block)| block.as_str())
        .collect::<Vec<_>>()
        .join("\n\n");

    let user_msg = format!(
        "{existing_hint}\n\n请根据以下{}集剧本提取对应的剧本资产（角色、场景、道具）:\n\n{scripts_content}",
        valid.len()
    );

    let parsed = match call_extract_tool(cfg, client, system, &user_msg).await {
        Ok(p) => p,
        Err(e) => {
            for sid in &valid_ids {
                mark_script_failed(pool, project_uuid, uid, *sid, &e).await?;
            }
            return Ok(());
        }
    };

    let valid_set: std::collections::HashSet<i32> = valid_ids.iter().copied().collect();
    let new_f = filter_tool_new_assets(parsed.new_assets, &valid_set);
    let ex_f = filter_tool_existing(parsed.existing_asset_refs, &valid_set);

    if new_f.is_empty() && ex_f.is_empty() {
        let msg = "AI returned no assets";
        for sid in &valid_ids {
            mark_script_failed(pool, project_uuid, uid, *sid, msg).await?;
        }
        return Ok(());
    }

    let mut tx = pool.begin().await.map_err(|e| e.to_string())?;
    if let Err(e) = persist_group(&mut tx, project_uuid, &valid_ids, &new_f, &ex_f).await {
        tx.rollback().await.ok();
        for sid in &valid_ids {
            mark_script_failed(pool, project_uuid, uid, *sid, &e.to_string()).await?;
        }
        return Ok(());
    }
    tx.commit().await.map_err(|e| e.to_string())?;

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 1, error_reason = NULL, updated_at = NOW()
        FROM app_project p
        WHERE s.project_id = p.id AND p.id = $1 AND p.owner_user_id = $2
          AND s.legacy_id = ANY($3)
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(&valid_ids)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    Ok(())
}

async fn mark_script_failed(
    pool: &PgPool,
    project_uuid: Uuid,
    uid: Uuid,
    script_legacy_id: i32,
    reason: &str,
) -> Result<(), String> {
    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = -1, error_reason = $4, updated_at = NOW()
        FROM app_project p
        WHERE s.project_id = p.id AND p.id = $1 AND p.owner_user_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(script_legacy_id)
    .bind(reason)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;
    Ok(())
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
struct ToolResultPayload {
    #[serde(default)]
    new_assets: Vec<NewAssetItem>,
    #[serde(default, alias = "existingAssetRefs")]
    existing_asset_refs: Vec<ExistingRefItem>,
}

#[derive(Debug, Deserialize)]
struct NewAssetItem {
    name: String,
    desc: String,
    #[serde(rename = "type")]
    asset_type: String,
    #[serde(default, alias = "scriptIds", alias = "scriptLegacyIds")]
    script_legacy_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
struct ExistingRefItem {
    name: String,
    #[serde(default, alias = "scriptIds", alias = "scriptLegacyIds")]
    script_legacy_ids: Vec<i32>,
}

struct NewAssetItemFiltered {
    name: String,
    desc: String,
    asset_type: String,
    script_legacy_ids: Vec<i32>,
}

struct ExistingRefItemFiltered {
    name: String,
    script_legacy_ids: Vec<i32>,
}

fn filter_tool_new_assets(
    items: Vec<NewAssetItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<NewAssetItemFiltered> {
    let mut out = Vec::new();
    let mut seen_name: std::collections::HashSet<String> = std::collections::HashSet::new();
    for mut it in items {
        let t = it.asset_type.trim().to_lowercase();
        if t != "role" && t != "tool" && t != "scene" {
            continue;
        }
        let name = it.name.trim().to_string();
        if name.is_empty() || !seen_name.insert(name.clone()) {
            continue;
        }
        it.script_legacy_ids.retain(|id| valid.contains(id));
        if it.script_legacy_ids.is_empty() {
            continue;
        }
        out.push(NewAssetItemFiltered {
            name,
            desc: it.desc,
            asset_type: t,
            script_legacy_ids: it.script_legacy_ids,
        });
    }
    out
}

fn filter_tool_existing(
    items: Vec<ExistingRefItem>,
    valid: &std::collections::HashSet<i32>,
) -> Vec<ExistingRefItemFiltered> {
    let mut out = Vec::new();
    for mut it in items {
        let name = it.name.trim().to_string();
        if name.is_empty() {
            continue;
        }
        it.script_legacy_ids.retain(|id| valid.contains(id));
        if it.script_legacy_ids.is_empty() {
            continue;
        }
        out.push(ExistingRefItemFiltered {
            name,
            script_legacy_ids: it.script_legacy_ids,
        });
    }
    out
}

fn extract_tool_schema() -> Value {
    json!({
        "type": "object",
        "required": ["new_assets", "existing_asset_refs"],
        "properties": {
            "new_assets": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "desc", "type", "script_legacy_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "desc": { "type": "string" },
                        "type": { "type": "string", "enum": ["role", "tool", "scene"] },
                        "script_legacy_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            },
            "existing_asset_refs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["name", "script_legacy_ids"],
                    "properties": {
                        "name": { "type": "string" },
                        "script_legacy_ids": {
                            "type": "array",
                            "items": { "type": "integer" }
                        }
                    },
                    "additionalProperties": false
                }
            }
        },
        "additionalProperties": false
    })
}

async fn call_extract_tool(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    system: &str,
    user: &str,
) -> Result<ToolResultPayload, String> {
    let tools = vec![json!({
        "type": "function",
        "function": {
            "name": "script_asset_extract_result",
            "description": "Return extracted assets; call exactly once with arrays (may be empty only if truly no entities).",
            "parameters": extract_tool_schema(),
        }
    })];

    let body = json!({
        "model": cfg.model,
        "stream": false,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "tools": tools,
        "tool_choice": {"type": "function", "function": {"name": "script_asset_extract_result"}},
    });

    let url = format!("{}/chat/completions", cfg.base_url);
    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", cfg.api_key))
        .header("Content-Type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("llm request: {e}"))?;

    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("llm HTTP {status}: {text}"));
    }

    let v: Value = response
        .json()
        .await
        .map_err(|e| format!("llm json: {e}"))?;
    let msg = v
        .get("choices")
        .and_then(|c| c.as_array())
        .and_then(|a| a.first())
        .and_then(|c| c.get("message"))
        .ok_or_else(|| "llm: missing choices[0].message".to_string())?;

    let tcs = msg
        .get("tool_calls")
        .and_then(|x| x.as_array())
        .filter(|a| !a.is_empty())
        .ok_or_else(|| "llm: expected tool_calls".to_string())?;

    let tc = tcs
        .first()
        .ok_or_else(|| "llm: empty tool_calls".to_string())?;
    let func = tc
        .get("function")
        .ok_or_else(|| "llm: missing function".to_string())?;
    let name = func
        .get("name")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .trim();
    if name != "script_asset_extract_result" {
        return Err(format!("llm: unexpected tool {name}"));
    }
    let args_str = func
        .get("arguments")
        .and_then(|x| x.as_str())
        .unwrap_or("{}");
    serde_json::from_str::<ToolResultPayload>(args_str)
        .map_err(|e| format!("llm: bad tool arguments: {e}"))
}

async fn persist_group(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    batch_legacy_ids: &[i32],
    new_assets: &[NewAssetItemFiltered],
    existing_refs: &[ExistingRefItemFiltered],
) -> Result<(), String> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_LEGACY_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;

    let script_rows: Vec<(Uuid, i32)> = sqlx::query_as(
        r#"SELECT id, legacy_id FROM app_script WHERE project_id = $1 AND legacy_id = ANY($2)"#,
    )
    .bind(project_uuid)
    .bind(batch_legacy_ids)
    .fetch_all(&mut **tx)
    .await
    .map_err(|e| e.to_string())?;

    let legacy_to_script: std::collections::HashMap<i32, Uuid> =
        script_rows.into_iter().map(|(id, lid)| (lid, id)).collect();

    let script_uuids: Vec<Uuid> = batch_legacy_ids
        .iter()
        .filter_map(|lid| legacy_to_script.get(lid).copied())
        .collect();

    if !script_uuids.is_empty() {
        sqlx::query(r#"DELETE FROM app_script_asset WHERE script_id = ANY($1)"#)
            .bind(&script_uuids)
            .execute(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;
    }

    let existing: Vec<(Uuid, String)> =
        sqlx::query_as(r#"SELECT id, name FROM app_asset WHERE project_id = $1"#)
            .bind(project_uuid)
            .fetch_all(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;

    let mut name_to_id: std::collections::HashMap<String, Uuid> =
        existing.into_iter().map(|(id, n)| (n, id)).collect();

    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut next_legacy: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(legacy_id), 0) FROM app_asset"#)
            .fetch_one(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;

    for na in new_assets {
        if name_to_id.contains_key(&na.name) {
            continue;
        }
        next_legacy += 1;
        let id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO app_asset (
              project_id, legacy_id, name, asset_type, description, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
            RETURNING id
            "#,
        )
        .bind(project_uuid)
        .bind(next_legacy)
        .bind(&na.name)
        .bind(&na.asset_type)
        .bind(trim_empty_opt(&na.desc))
        .bind(now_ms)
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;
        name_to_id.insert(na.name.clone(), id);
    }

    let mut pairs: Vec<(Uuid, Uuid)> = Vec::new();
    for na in new_assets {
        let Some(aid) = name_to_id.get(&na.name).copied() else {
            continue;
        };
        for lid in &na.script_legacy_ids {
            if let Some(sid) = legacy_to_script.get(lid) {
                pairs.push((*sid, aid));
            }
        }
    }
    for er in existing_refs {
        let Some(aid) = name_to_id.get(&er.name).copied() else {
            continue;
        };
        for lid in &er.script_legacy_ids {
            if let Some(sid) = legacy_to_script.get(lid) {
                pairs.push((*sid, aid));
            }
        }
    }

    pairs.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    pairs.dedup();

    for (sid, aid) in pairs {
        sqlx::query(
            r#"INSERT INTO app_script_asset (script_id, asset_id) VALUES ($1, $2)
               ON CONFLICT (script_id, asset_id) DO NOTHING"#,
        )
        .bind(sid)
        .bind(aid)
        .execute(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;
    }

    Ok(())
}

fn trim_empty_opt(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

fn load_system_prompt() -> String {
    if let Ok(p) = std::env::var("SCRIPT_ASSET_EXTRACT_PROMPT_PATH") {
        if let Ok(s) = std::fs::read_to_string(&p) {
            if !s.trim().is_empty() {
                return s;
            }
        }
        tracing::warn!(path = %p, "SCRIPT_ASSET_EXTRACT_PROMPT_PATH set but empty or unreadable");
    }
    include_str!("../../data/prompts/script_asset_extraction.default.txt").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<ExtractAssetsBody>(
            r#"{"project_legacy_id":1,"script_legacy_ids":[1],"group_size":3,"x":1}"#,
        )
        .unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn filter_new_drops_bad_type() {
        let valid: std::collections::HashSet<i32> = [1].into_iter().collect();
        let out = filter_tool_new_assets(
            vec![NewAssetItem {
                name: "A".into(),
                desc: "d".into(),
                asset_type: "wizard".into(),
                script_legacy_ids: vec![1],
            }],
            &valid,
        );
        assert!(out.is_empty());
    }
}
