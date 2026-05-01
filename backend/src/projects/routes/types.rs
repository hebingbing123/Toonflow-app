use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

/// Query parameters for `GET /api/v1/projects` pagination.
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct ListProjectsQuery {
    #[serde(default)]
    pub(super) limit: Option<i64>,
    #[serde(default)]
    pub(super) offset: Option<i64>,
}

#[derive(Debug, FromRow, Serialize)]
pub(super) struct ProjectRow {
    pub(super) id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub(super) numeric_id: i32,
    pub(super) name: Option<String>,
    pub(super) intro: Option<String>,
    pub(super) project_type: Option<String>,
    pub(super) image_model: Option<String>,
    pub(super) image_quality: Option<String>,
    pub(super) video_model: Option<String>,
    pub(super) art_style: Option<String>,
    pub(super) director_manual: Option<String>,
    pub(super) mode: Option<String>,
    pub(super) video_ratio: Option<String>,
    pub(super) create_time_ms: Option<i64>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    pub(super) art_style_pack: Option<String>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    pub(super) story_style_pack: Option<String>,
}

#[derive(Debug, FromRow, Serialize)]
pub(super) struct ScriptBrief {
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub(super) numeric_id: i32,
    pub(super) name: Option<String>,
    pub(super) extract_state: Option<i32>,
}

#[derive(Serialize)]
pub(super) struct ProjectDetailResponse {
    pub(super) project: ProjectRow,
    pub(super) scripts: Vec<ScriptBrief>,
}

/// Per-project counts for dashboards; aligns with Electron-era **`generalStatistics`** shape.
/// **`role_count`** counts **`app_asset`** rows with **`asset_type = 'role'`**; **`novel_count`** counts **`app_novel`** rows; **`video_count`** remains **`0`** until video rows exist in Postgres.
#[derive(Serialize)]
pub(super) struct ProjectStatsResponse {
    pub(super) script_count: i64,
    pub(super) storyboard_count: i64,
    pub(super) role_count: i64,
    pub(super) novel_count: i64,
    pub(super) video_count: i64,
}

/// Aggregate counts for **`owner_user_id = JWT sub`** across all owned projects (single query).
#[derive(Serialize)]
pub(super) struct ProjectsSummaryResponse {
    pub(super) project_count: i64,
    pub(super) script_count: i64,
    pub(super) storyboard_count: i64,
    pub(super) novel_count: i64,
    /// Same rule as per-project **`GET …/stats`**: **`app_asset`** with **`asset_type = 'role'`**.
    pub(super) role_count: i64,
    pub(super) art_style_count: i64,
    pub(super) asset_count: i64,
    /// Same as per-project **`GET …/stats`**: **`0`** until video rows exist in Postgres.
    pub(super) video_count: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct PatchProjectBody {
    #[serde(default)]
    pub(super) name: Option<Value>,
    #[serde(default)]
    pub(super) intro: Option<Value>,
    #[serde(default)]
    pub(super) project_type: Option<Value>,
    #[serde(default)]
    pub(super) image_model: Option<Value>,
    #[serde(default)]
    pub(super) image_quality: Option<Value>,
    #[serde(default)]
    pub(super) video_model: Option<Value>,
    #[serde(default)]
    pub(super) art_style: Option<Value>,
    #[serde(default)]
    pub(super) director_manual: Option<Value>,
    #[serde(default)]
    pub(super) mode: Option<Value>,
    #[serde(default)]
    pub(super) video_ratio: Option<Value>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    #[serde(default)]
    pub(super) art_style_pack: Option<Value>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    #[serde(default)]
    pub(super) story_style_pack: Option<Value>,
}

/// `PATCH /api/v1/projects/{id}/style-config` 请求体
#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct PatchStyleConfigBody {
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`），传 null 清除
    #[serde(default)]
    pub(super) art_style_pack: Option<String>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`），传 null 清除
    #[serde(default)]
    pub(super) story_style_pack: Option<String>,
}

/// JSON body for `POST /api/v1/projects` (snake_case; all fields optional).
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub(super) struct CreateProjectBody {
    #[serde(default)]
    pub(super) name: Option<String>,
    #[serde(default)]
    pub(super) intro: Option<String>,
    #[serde(default)]
    pub(super) project_type: Option<String>,
    #[serde(default)]
    pub(super) image_model: Option<String>,
    #[serde(default)]
    pub(super) image_quality: Option<String>,
    #[serde(default)]
    pub(super) video_model: Option<String>,
    #[serde(default)]
    pub(super) art_style: Option<String>,
    #[serde(default)]
    pub(super) director_manual: Option<String>,
    #[serde(default)]
    pub(super) mode: Option<String>,
    #[serde(default)]
    pub(super) video_ratio: Option<String>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    #[serde(default)]
    pub(super) art_style_pack: Option<String>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    #[serde(default)]
    pub(super) story_style_pack: Option<String>,
}
