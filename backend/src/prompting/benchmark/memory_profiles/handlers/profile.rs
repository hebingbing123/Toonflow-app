//! 记忆预算档 CRUD 处理器。

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::{auth::require_user_uuid, error::ApiError, state::AppState};

use super::super::types::{
    CompressionRules, ListMemoryProfilesQuery, MemoryBudgetProfileSnapshot, MemoryProfilesResponse,
    RetentionBuckets,
};

/// 列出记忆预算档
///
/// 返回系统中已定义的记忆预算档快照列表。
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/memory-profiles",
    params(ListMemoryProfilesQuery),
    responses(
        (status = 200, description = "成功返回记忆预算档列表", body = MemoryProfilesResponse),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器内部错误")
    ),
    security(("bearer" = []))
)]
pub async fn list_memory_profiles(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListMemoryProfilesQuery>,
) -> Result<Json<MemoryProfilesResponse>, ApiError> {
    let _user_id = require_user_uuid(&state, &headers)?;
    // 当前实现返回预定义的记忆预算档
    // 未来可以从数据库或配置文件中加载

    let limit = query.limit.unwrap_or(50).min(100);
    let _offset = query.offset.unwrap_or(0);

    let mut profiles = vec![
        // Lean 档
        MemoryBudgetProfileSnapshot {
            budget_tier: "lean".to_string(),
            compression_rules: CompressionRules {
                compact_silent_low_risk: true,
                continuity_note_max_chars: Some(120),
                memory_note_max_chars: Some(80),
                style_fragment_retention: Some("best_only".to_string()),
            },
            retention_buckets: RetentionBuckets {
                project_scope_retention: Some(2),
                script_scope_retention: Some(3),
                scene_scope_retention: Some(1),
                prioritize_emotional_memory: false,
                prioritize_dialogue_performance: false,
            },
            observation_note_limit: Some(100),
            character_memory_priority: None,
            profile_version: Some("v1".to_string()),
        },
        // Expanded 档
        MemoryBudgetProfileSnapshot {
            budget_tier: "expanded".to_string(),
            compression_rules: CompressionRules {
                compact_silent_low_risk: false,
                continuity_note_max_chars: Some(200),
                memory_note_max_chars: Some(150),
                style_fragment_retention: Some("all_relevant".to_string()),
            },
            retention_buckets: RetentionBuckets {
                project_scope_retention: Some(5),
                script_scope_retention: Some(8),
                scene_scope_retention: Some(3),
                prioritize_emotional_memory: true,
                prioritize_dialogue_performance: true,
            },
            observation_note_limit: Some(300),
            character_memory_priority: Some(serde_json::json!({
                "emotional_state": "high",
                "visual_consistency": "high",
                "dialogue_style": "medium"
            })),
            profile_version: Some("v1".to_string()),
        },
    ];

    // 按查询参数过滤
    if let Some(ref tier) = query.budget_tier {
        profiles.retain(|p| p.budget_tier == *tier);
    }

    if let Some(ref version) = query.profile_version {
        profiles.retain(|p| p.profile_version.as_ref() == Some(version));
    }

    let total = profiles.len() as i64;
    profiles.truncate(limit as usize);

    Ok(Json(MemoryProfilesResponse { profiles, total }))
}

/// 创建默认记忆预算档
pub(super) fn create_default_memory_profile(tier: &str) -> MemoryBudgetProfileSnapshot {
    MemoryBudgetProfileSnapshot {
        budget_tier: tier.to_string(),
        compression_rules: CompressionRules {
            compact_silent_low_risk: true,
            continuity_note_max_chars: Some(120),
            memory_note_max_chars: Some(80),
            style_fragment_retention: Some("best_only".to_string()),
        },
        retention_buckets: RetentionBuckets {
            project_scope_retention: Some(2),
            script_scope_retention: Some(3),
            scene_scope_retention: Some(1),
            prioritize_emotional_memory: false,
            prioritize_dialogue_performance: false,
        },
        observation_note_limit: Some(100),
        character_memory_priority: None,
        profile_version: None,
    }
}
