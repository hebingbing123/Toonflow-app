use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::{json, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::storage::{
    is_unique_violation, resolve_owned_project_uuid, scripts_json_for_project, select_plan_row,
};
use super::super::types::{
    CodeDataEnvelope, GetScriptAgentPlanBody, PlanDataWithId, PlanFlatData, ScriptAgentKind,
};

pub(super) async fn post_get_plan_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetScriptAgentPlanBody>,
) -> Result<JsonResponse<Value>, ApiError> {
    let _ = matches!(body.agent_type, ScriptAgentKind::ScriptAgent);
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
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
        let wrapped = CodeDataEnvelope {
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

    let flat = CodeDataEnvelope {
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
