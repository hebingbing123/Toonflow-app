//! Legacy **`/api/scriptAgent/*`**: Postgres **`app_script_agent_plan`** + **`app_script`** sync.
//! Shapes match old **`validateFields`** bodies; success JSON follows **`{ code, data, message }`** where applicable.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

/// Same advisory lock family as [`crate::scripts`] for allocating **`app_script.legacy_id`**.
const ADV_LOCK_SCRIPT_LEGACY_ID: i64 = 884_422_002;
const MAX_PLAN_SCRIPT_ROWS: usize = 200;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
enum ScriptAgentKind {
    #[serde(rename = "scriptAgent")]
    ScriptAgent,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetScriptAgentPlanBody {
    project_id: i32,
    agent_type: ScriptAgentKind,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetPlanScriptRow {
    name: String,
    content: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetScriptAgentPlanData {
    story_skeleton: String,
    adaptation_strategy: String,
    #[serde(default)]
    script: Vec<SetPlanScriptRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SetScriptAgentPlanBody {
    project_id: i32,
    agent_type: ScriptAgentKind,
    data: SetScriptAgentPlanData,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptRow {
    id: i32,
    content: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptAgentDataPayload {
    story_skeleton: String,
    adaptation_strategy: String,
    script: Vec<UpdateScriptRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateScriptAgentDataBody {
    id: i64,
    data: UpdateScriptAgentDataPayload,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct LegacyApiSuccess<T: Serialize> {
    code: i32,
    data: T,
    message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PlanFlatData {
    story_skeleton: String,
    adaptation_strategy: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PlanDataWithId {
    data: Value,
    id: i64,
}

fn is_unique_violation(e: &sqlx::Error) -> bool {
    match e {
        sqlx::Error::Database(db) => db.code().map(|c| c == "23505").unwrap_or(false),
        _ => false,
    }
}

fn trim_opt(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

async fn resolve_owned_project_uuid(
    pool: &PgPool,
    uid: Uuid,
    project_legacy_id: i32,
) -> Result<Uuid, ApiError> {
    if project_legacy_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

async fn select_plan_row(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Uuid,
) -> Result<Option<(i64, Value)>, ApiError> {
    let row: Option<(i64, Value)> = sqlx::query_as(
        r#"
        SELECT id, plan_data
        FROM app_script_agent_plan
        WHERE owner_user_id = $1 AND project_id = $2 AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(uid)
    .bind(project_uuid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row)
}

async fn scripts_json_for_project(pool: &PgPool, project_uuid: Uuid) -> Result<Value, ApiError> {
    let rows: Vec<(i32, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT legacy_id, name, content
        FROM app_script
        WHERE project_id = $1
        ORDER BY legacy_id ASC
        "#,
    )
    .bind(project_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let arr: Vec<Value> = rows
        .into_iter()
        .map(|(id, name, content)| {
            json!({
                "id": id,
                "name": name.unwrap_or_default(),
                "content": content.unwrap_or_default(),
            })
        })
        .collect();
    Ok(Value::Array(arr))
}

async fn post_get_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetScriptAgentPlanBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let _ = matches!(body.agent_type, ScriptAgentKind::ScriptAgent);
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let project_uuid = resolve_owned_project_uuid(pool, uid, body.project_id).await?;

    fn wrap_plan_with_scripts(
        id: i64,
        mut plan_data: Value,
        scripts: Value,
    ) -> Result<JsonResponse<Value>, ApiError> {
        if let Some(obj) = plan_data.as_object_mut() {
            obj.insert("script".to_string(), scripts);
        } else {
            plan_data = json!({ "script": scripts });
        }
        let wrapped = LegacyApiSuccess {
            code: 200,
            data: PlanDataWithId {
                data: plan_data,
                id,
            },
            message: "成功",
        };
        Ok(JsonResponse(serde_json::to_value(wrapped).map_err(
            |e| ApiError::DatabaseError(format!("serialize get-plan-data: {e}")),
        )?))
    }

    if let Some((id, plan_data)) = select_plan_row(pool, uid, project_uuid).await? {
        let scripts = scripts_json_for_project(pool, project_uuid).await?;
        return wrap_plan_with_scripts(id, plan_data, scripts);
    }

    let inserted = match sqlx::query(
        r#"
        INSERT INTO app_script_agent_plan (owner_user_id, project_id, agent_key, plan_data)
        VALUES ($1, $2, 'scriptAgent', '{"storySkeleton":"","adaptationStrategy":""}'::jsonb)
        "#,
    )
    .bind(uid)
    .bind(project_uuid)
    .execute(pool)
    .await
    {
        Ok(_) => true,
        Err(e) if is_unique_violation(&e) => false,
        Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
    };

    if !inserted {
        if let Some((id, plan_data)) = select_plan_row(pool, uid, project_uuid).await? {
            let scripts = scripts_json_for_project(pool, project_uuid).await?;
            return wrap_plan_with_scripts(id, plan_data, scripts);
        }
        return Err(ApiError::DatabaseError(
            "script agent plan insert raced but row missing".into(),
        ));
    }

    let flat = LegacyApiSuccess {
        code: 200,
        data: PlanFlatData {
            story_skeleton: String::new(),
            adaptation_strategy: String::new(),
        },
        message: "成功",
    };
    Ok(JsonResponse(serde_json::to_value(flat).map_err(|e| {
        ApiError::DatabaseError(format!("serialize get-plan-data: {e}"))
    })?))
}

async fn post_set_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SetScriptAgentPlanBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let _ = matches!(body.agent_type, ScriptAgentKind::ScriptAgent);
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    if body.data.script.len() > MAX_PLAN_SCRIPT_ROWS {
        return Err(ApiError::BadRequest(format!(
            "data.script must have at most {MAX_PLAN_SCRIPT_ROWS} rows"
        )));
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_uuid: Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.project_id)
    .bind(uid)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let plan_json = json!({
        "storySkeleton": body.data.story_skeleton,
        "adaptationStrategy": body.data.adaptation_strategy,
    });

    sqlx::query(
        r#"
        INSERT INTO app_script_agent_plan (owner_user_id, project_id, agent_key, plan_data)
        VALUES ($1, $2, 'scriptAgent', $3::jsonb)
        ON CONFLICT (owner_user_id, project_id, agent_key)
        DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(project_uuid)
    .bind(plan_json.clone())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_SCRIPT_LEGACY_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in &body.data.script {
        let name = trim_opt(&row.name).ok_or_else(|| {
            ApiError::BadRequest("each data.script row must have a non-empty name".into())
        })?;
        let n_updated = sqlx::query(
            r#"
            UPDATE app_script AS s
            SET content = $1, updated_at = NOW()
            FROM (
              SELECT id FROM app_script
              WHERE project_id = $2 AND name = $3
              ORDER BY legacy_id ASC
              LIMIT 1
            ) AS pick
            WHERE s.id = pick.id
            "#,
        )
        .bind(row.content.trim())
        .bind(project_uuid)
        .bind(&name)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .rows_affected();
        if n_updated == 0 {
            let next_legacy: i32 = sqlx::query_scalar(
                r#"
                SELECT COALESCE(MAX(legacy_id), 0) + 1 FROM app_script
                "#,
            )
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let now_ms = chrono::Utc::now().timestamp_millis();
            sqlx::query(
                r#"
                INSERT INTO app_script (
                  project_id, legacy_id, name, content, extract_state, create_time_ms, metadata
                )
                VALUES ($1, $2, $3, $4, NULL, $5, '{}'::jsonb)
                "#,
            )
            .bind(project_uuid)
            .bind(next_legacy)
            .bind(&name)
            .bind(row.content.trim())
            .bind(now_ms)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                if is_unique_violation(&e) {
                    ApiError::Conflict(
                        "script name already exists for this project (concurrent insert)".into(),
                    )
                } else {
                    ApiError::DatabaseError(e.to_string())
                }
            })?;
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let ok = LegacyApiSuccess {
        code: 200,
        data: Value::Null,
        message: "成功",
    };
    Ok(JsonResponse(serde_json::to_value(ok).map_err(|e| {
        ApiError::DatabaseError(format!("serialize set-plan-data: {e}"))
    })?))
}

async fn post_update_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateScriptAgentDataBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let payload = json!({
        "storySkeleton": body.data.story_skeleton,
        "adaptationStrategy": body.data.adaptation_strategy,
        "script": body.data.script.iter().map(|r| json!({
            "id": r.id,
            "content": r.content,
        })).collect::<Vec<_>>(),
    });

    let n = sqlx::query(
        r#"
        UPDATE app_script_agent_plan
        SET plan_data = $1::jsonb, updated_at = NOW()
        WHERE id = $2 AND owner_user_id = $3
        "#,
    )
    .bind(payload)
    .bind(body.id)
    .bind(uid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .rows_affected();
    if n == 0 {
        return Err(ApiError::NotFound);
    }

    let ok = LegacyApiSuccess {
        code: 200,
        data: Value::String("更新成功".to_owned()),
        message: "成功",
    };
    Ok(JsonResponse(serde_json::to_value(ok).map_err(|e| {
        ApiError::DatabaseError(format!("serialize update-data: {e}"))
    })?))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/script-agent/get-plan-data",
            post(post_get_plan_data),
        )
        .route(
            "/api/v1/script-agent/set-plan-data",
            post(post_set_plan_data),
        )
        .route("/api/v1/script-agent/update-data", post(post_update_data))
}
