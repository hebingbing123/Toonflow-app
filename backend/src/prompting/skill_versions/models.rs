// Feature: ai-drama-quality-optimization
//! 技能文件版本管理数据模型（需求 24.1, 24.2）

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// `app_skill_versions` 表记录
#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SkillVersion {
    pub id: Uuid,
    pub file_path: String,
    pub changed_at: DateTime<Utc>,
    pub summary: Option<String>,
    pub hash_before: Option<String>,
    pub hash_after: String,
    pub changed_by: Option<Uuid>,
    pub rollback_of: Option<Uuid>,
    /// 版本对应的文件内容快照（需求 24.4：支持真正的文件内容回滚）
    /// `None` 表示旧版本记录（迁移前写入，无内容快照）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content_snapshot: Option<String>,
}

/// `GET /api/v1/skill-versions` 查询参数
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ListSkillVersionsQuery {
    /// 文件路径（相对于 `backend/data/skills/`）
    pub path: String,
    #[serde(default = "default_limit")]
    pub limit: i64,
    #[serde(default)]
    pub offset: i64,
}

fn default_limit() -> i64 {
    20
}

/// `POST /api/v1/skill-versions/rollback` 请求体
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RollbackRequest {
    /// 文件路径（相对于 `backend/data/skills/`）
    pub file_path: String,
    /// 目标版本 ID（回滚到该版本的 `hash_after` 内容）
    pub target_version_id: Uuid,
    /// 回滚摘要（可选，不超过 100 字）
    pub summary: Option<String>,
}

/// `POST /api/v1/skill-versions/rollback` 响应体
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RollbackResponse {
    /// 新创建的版本记录 ID
    pub new_version_id: Uuid,
    pub file_path: String,
    pub rolled_back_from: Uuid,
    pub rolled_back_to: Uuid,
    pub hash_after: String,
}

#[cfg(test)]
mod tests {
    use super::{ListSkillVersionsQuery, RollbackRequest, RollbackResponse};
    use serde_json::json;
    use uuid::Uuid;

    #[test]
    fn list_skill_versions_query_defaults_limit_and_offset() {
        let query: ListSkillVersionsQuery = serde_json::from_value(json!({
            "path": "story_skills/sweet_romance.md"
        }))
        .expect("deserialize query");
        assert_eq!(query.limit, 20);
        assert_eq!(query.offset, 0);
    }

    #[test]
    fn rollback_request_accepts_camel_case_payload() {
        let target_version_id = Uuid::new_v4();
        let request: RollbackRequest = serde_json::from_value(json!({
            "filePath": "story_skills/sweet_romance.md",
            "targetVersionId": target_version_id,
            "summary": "回滚到稳定版本"
        }))
        .expect("deserialize rollback request");
        assert_eq!(request.file_path, "story_skills/sweet_romance.md");
        assert_eq!(request.target_version_id, target_version_id);
        assert_eq!(request.summary.as_deref(), Some("回滚到稳定版本"));
    }

    #[test]
    fn rollback_response_serializes_camel_case_fields() {
        let response = RollbackResponse {
            new_version_id: Uuid::new_v4(),
            file_path: "story_skills/sweet_romance.md".into(),
            rolled_back_from: Uuid::new_v4(),
            rolled_back_to: Uuid::new_v4(),
            hash_after: "abc123".into(),
        };
        let value = serde_json::to_value(&response).expect("serialize rollback response");
        assert!(value.get("newVersionId").is_some());
        assert_eq!(
            value.get("filePath").and_then(serde_json::Value::as_str),
            Some("story_skills/sweet_romance.md")
        );
        assert_eq!(
            value.get("hashAfter").and_then(serde_json::Value::as_str),
            Some("abc123")
        );
    }
}
