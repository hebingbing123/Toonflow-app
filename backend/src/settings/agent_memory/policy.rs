use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::helpers::bad_request_i18n;
use crate::error::ApiError;

use super::replace_named_summary_memory_with_scope;

pub(crate) const MEMORY_POLICY_NAME: &str = "memory_budget_policy:project";

const GENERIC_LOW_SIGNAL_FRAGMENTS: [&str; 10] = [
    "待补充",
    "暂无",
    "（无记录）",
    "[摘要]",
    "风格统一",
    "情绪延续",
    "继续观察",
    "无明显问题",
    "later",
    "todo",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub(crate) enum AutomationMemoryMode {
    Off,
    Lean,
    #[default]
    Standard,
}

impl AutomationMemoryMode {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::Off => "off",
            Self::Lean => "lean",
            Self::Standard => "standard",
        }
    }

    pub(crate) fn from_str(raw: &str) -> Option<Self> {
        match raw {
            "off" => Some(Self::Off),
            "lean" => Some(Self::Lean),
            "standard" => Some(Self::Standard),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ProjectAutomationMemoryPolicy {
    pub(crate) mode: AutomationMemoryMode,
}

impl Default for ProjectAutomationMemoryPolicy {
    fn default() -> Self {
        Self {
            mode: AutomationMemoryMode::Standard,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub(crate) struct MemoryBudgetSnapshot {
    pub(crate) total_rows: i64,
    pub(crate) avg_injected_chars_last30: i64,
    pub(crate) low_value_rows: i64,
}

#[derive(Debug, Clone, Default)]
pub(crate) struct MemoryBudgetOptimizeResult {
    pub(crate) removed_rows: usize,
    pub(crate) removed_chars: usize,
    pub(crate) removed_duplicate_rows: usize,
    pub(crate) removed_low_value_rows: usize,
}

#[derive(Debug, sqlx::FromRow)]
struct MemoryGovernanceRow {
    id: Uuid,
    name: Option<String>,
    content: String,
    memory_tier: Option<String>,
    scope_signature: Option<Value>,
}

type MemoryQueryRow = (Option<String>, Option<String>, String, Option<Value>);

impl MemoryBudgetSnapshot {
    pub(crate) fn low_value_ratio_percent(&self) -> f64 {
        if self.total_rows <= 0 {
            return 0.0;
        }
        ((self.low_value_rows as f64 / self.total_rows as f64) * 10000.0).round() / 100.0
    }

    pub(crate) fn exceeds_budget(&self) -> bool {
        self.total_rows > 24
            || self.avg_injected_chars_last30 > 240
            || self.low_value_ratio_percent() >= 25.0
    }
}

fn normalize_text(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(crate) fn memory_entry_is_low_value(
    memory_tier: &str,
    name: Option<&str>,
    content: &str,
    scope_signature: Option<&Value>,
) -> bool {
    let normalized = normalize_text(content);
    if normalized.is_empty() {
        return true;
    }
    if memory_tier == "style_bible" {
        return false;
    }
    if memory_tier == "stage_summary" {
        return normalized.chars().count() < 10
            || GENERIC_LOW_SIGNAL_FRAGMENTS
                .iter()
                .any(|fragment| normalized.contains(fragment));
    }
    if memory_tier == "delta_memory" {
        return scope_signature.is_none()
            || normalized.chars().count() < 12
            || GENERIC_LOW_SIGNAL_FRAGMENTS
                .iter()
                .any(|fragment| normalized.contains(fragment));
    }
    if name == Some(MEMORY_POLICY_NAME) {
        return false;
    }
    normalized.chars().count() < 8
        || GENERIC_LOW_SIGNAL_FRAGMENTS
            .iter()
            .any(|fragment| normalized.contains(fragment))
}

pub(crate) fn automated_memory_has_reuse_value(
    memory_tier: &str,
    name: Option<&str>,
    content: &str,
    scope_signature: Option<&Value>,
) -> bool {
    if name == Some(MEMORY_POLICY_NAME) {
        return true;
    }
    if memory_tier == "style_bible" {
        return true;
    }
    !memory_entry_is_low_value(memory_tier, name, content, scope_signature)
}

pub(crate) fn policy_allows_automated_memory(
    policy: &ProjectAutomationMemoryPolicy,
    memory_tier: &str,
    name: Option<&str>,
    content: &str,
    scope_signature: Option<&Value>,
) -> bool {
    if !automated_memory_has_reuse_value(memory_tier, name, content, scope_signature) {
        return false;
    }
    match policy.mode {
        AutomationMemoryMode::Standard => true,
        AutomationMemoryMode::Lean => {
            memory_tier == "style_bible"
                || memory_tier == "stage_summary"
                || (memory_tier == "delta_memory" && scope_signature.is_some())
        }
        AutomationMemoryMode::Off => memory_tier == "style_bible" || memory_tier == "stage_summary",
    }
}

pub(crate) async fn load_project_automation_memory_policy(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    agent_type: &str,
) -> Result<ProjectAutomationMemoryPolicy, ApiError> {
    let content: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = $3
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(agent_type)
    .bind(MEMORY_POLICY_NAME)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(content
        .and_then(|content| serde_json::from_str::<ProjectAutomationMemoryPolicy>(&content).ok())
        .unwrap_or_default())
}

pub(crate) async fn save_project_automation_memory_policy(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    agent_type: &str,
    policy: &ProjectAutomationMemoryPolicy,
) -> Result<(), ApiError> {
    let content = serde_json::to_string(policy).map_err(|e| {
        bad_request_i18n(
            &format!("Failed to serialize memory policy: {}", e),
            &format!("内存策略序列化失败：{}", e),
        )
    })?;
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        None,
        agent_type,
        "assistant",
        MEMORY_POLICY_NAME,
        &content,
        "message",
        Some(&json!({ "projectId": project_id })),
        None,
    )
    .await
}

pub(crate) async fn load_project_memory_budget_snapshot(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
) -> Result<MemoryBudgetSnapshot, ApiError> {
    let rows: Vec<MemoryQueryRow> = sqlx::query_as(
        r#"
        SELECT memory_tier, name, content, scope_signature
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
        ORDER BY create_time_ms DESC
        LIMIT 120
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_rows = rows.len() as i64;
    let low_value_rows = rows
        .iter()
        .filter(|(tier, name, content, scope_signature)| {
            memory_entry_is_low_value(
                tier.as_deref().unwrap_or("message"),
                name.as_deref(),
                content,
                scope_signature.as_ref(),
            )
        })
        .count() as i64;
    let avg_injected_chars_last30 = rows
        .iter()
        .take(30)
        .map(|(_, _, content, _)| content.chars().count() as i64)
        .sum::<i64>()
        / rows.iter().take(30).count().max(1) as i64;

    Ok(MemoryBudgetSnapshot {
        total_rows,
        avg_injected_chars_last30,
        low_value_rows,
    })
}

pub(crate) async fn optimize_project_memory_budget(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
) -> Result<MemoryBudgetOptimizeResult, ApiError> {
    let snapshot =
        load_project_memory_budget_snapshot(pool, user_id, project_id, episodes_id, agent_type)
            .await?;
    if !snapshot.exceeds_budget() {
        return Ok(MemoryBudgetOptimizeResult::default());
    }

    let rows = sqlx::query_as::<_, MemoryGovernanceRow>(
        r#"
        SELECT id, name, content, memory_tier, scope_signature
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
        ORDER BY create_time_ms DESC
        LIMIT 200
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut seen = std::collections::HashSet::new();
    let mut duplicate_ids = Vec::new();
    let mut low_value_ids = Vec::new();
    let mut removed_chars = 0usize;

    for row in rows {
        let tier = row.memory_tier.as_deref().unwrap_or("message");
        let scope = row
            .scope_signature
            .as_ref()
            .and_then(|value| serde_json::to_string(value).ok())
            .unwrap_or_default();
        let key = format!(
            "{}|{}|{}|{}",
            tier,
            row.name.as_deref().unwrap_or(""),
            scope,
            normalize_text(&row.content)
        );
        if !seen.insert(key) {
            duplicate_ids.push(row.id);
            removed_chars += row.content.chars().count();
            continue;
        }
        if memory_entry_is_low_value(
            tier,
            row.name.as_deref(),
            &row.content,
            row.scope_signature.as_ref(),
        ) && tier != "style_bible"
            && row.name.as_deref() != Some(MEMORY_POLICY_NAME)
        {
            low_value_ids.push(row.id);
            removed_chars += row.content.chars().count();
        }
    }

    let mut all_ids = duplicate_ids.clone();
    for id in low_value_ids.iter().copied() {
        if !all_ids.contains(&id) {
            all_ids.push(id);
        }
    }

    if !all_ids.is_empty() {
        sqlx::query(
            r#"
            DELETE FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND episodes_id IS NOT DISTINCT FROM $3
              AND agent_type = $4
              AND id = ANY($5)
            "#,
        )
        .bind(user_id)
        .bind(project_id)
        .bind(episodes_id)
        .bind(agent_type)
        .bind(&all_ids)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(MemoryBudgetOptimizeResult {
        removed_rows: all_ids.len(),
        removed_chars,
        removed_duplicate_rows: duplicate_ids.len(),
        removed_low_value_rows: low_value_ids.len(),
    })
}

#[cfg(test)]
mod tests {
    use super::{
        automated_memory_has_reuse_value, memory_entry_is_low_value,
        policy_allows_automated_memory, AutomationMemoryMode, ProjectAutomationMemoryPolicy,
    };
    use serde_json::json;

    #[test]
    fn low_value_detector_flags_generic_delta_without_scope() {
        assert!(memory_entry_is_low_value(
            "delta_memory",
            Some("quality_precheck"),
            "继续观察",
            None
        ));
    }

    #[test]
    fn reuse_value_keeps_meaningful_stage_summary() {
        assert!(automated_memory_has_reuse_value(
            "stage_summary",
            Some("stage_summary:script"),
            "stage=script | status=completed | summary=人物动机与冲突已收紧",
            Some(&json!({"episodeId": 2}))
        ));
    }

    #[test]
    fn lean_policy_blocks_scope_free_delta_memory() {
        let policy = ProjectAutomationMemoryPolicy {
            mode: AutomationMemoryMode::Lean,
        };
        assert!(!policy_allows_automated_memory(
            &policy,
            "delta_memory",
            Some("auto_scope_memory"),
            "角色站位不要跳轴",
            None
        ));
    }

    #[test]
    fn off_policy_keeps_stage_summary_but_skips_message_like_auto_memory() {
        let policy = ProjectAutomationMemoryPolicy {
            mode: AutomationMemoryMode::Off,
        };
        assert!(policy_allows_automated_memory(
            &policy,
            "stage_summary",
            Some("stage_summary:panel"),
            "stage=storyboard_panel | status=completed | summary=角色站位已收紧",
            Some(&json!({"storyboardIds": [12]}))
        ));
        assert!(!policy_allows_automated_memory(
            &policy,
            "message",
            Some("auto_scope_memory"),
            "panel: 角色站位",
            Some(&json!({"storyboardIds": [12]}))
        ));
    }
}
