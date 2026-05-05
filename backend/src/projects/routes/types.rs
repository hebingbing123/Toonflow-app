use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

/// Query parameters for `GET /api/v1/projects` pagination.
#[derive(Debug, Deserialize, Default, IntoParams, ToSchema)]
#[serde(deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct ListProjectsQuery {
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
#[schema(
    title = "ProjectRow",
    description = "Project record with short video configuration fields"
)]
pub struct ProjectRow {
    pub id: Uuid,
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: Option<String>,
    pub intro: Option<String>,
    pub project_type: Option<String>,
    pub image_model: Option<String>,
    pub image_quality: Option<String>,
    pub video_model: Option<String>,
    pub art_style: Option<String>,
    pub director_manual: Option<String>,
    pub mode: Option<String>,
    pub video_ratio: Option<String>,
    pub create_time_ms: Option<i64>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    pub art_style_pack: Option<String>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    pub story_style_pack: Option<String>,
    /// 目标市场（如 domestic, overseas, both）
    #[schema(example = "domestic")]
    pub target_market: Option<String>,
    /// 目标平台数组（如 ["douyin", "bilibili", "tiktok"]）
    #[schema(example = json!(["douyin", "bilibili"]))]
    pub target_platforms: Option<Vec<String>>,
    /// 时长策略（如 short, medium, long）
    #[schema(example = "short")]
    pub duration_strategy: Option<String>,
    /// 声线配置标识
    pub voice_profile: Option<String>,
    /// 字幕样式标识
    pub subtitle_style: Option<String>,
    /// BGM 策略
    pub bgm_strategy: Option<String>,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
pub struct ScriptBrief {
    #[serde(rename = "numeric_id")]
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: Option<String>,
    pub extract_state: Option<i32>,
}

#[derive(Serialize, ToSchema)]
pub struct ProjectDetailResponse {
    pub project: ProjectRow,
    pub scripts: Vec<ScriptBrief>,
}

/// Per-project counts for dashboards; aligns with Electron-era **`generalStatistics`** shape.
/// **`role_count`** counts **`app_asset`** rows with **`asset_type = 'role'`**; **`novel_count`** counts **`app_novel`** rows; **`video_count`** remains **`0`** until video rows exist in Postgres.
#[derive(Serialize, ToSchema)]
pub struct ProjectStatsResponse {
    pub script_count: i64,
    pub storyboard_count: i64,
    pub role_count: i64,
    pub novel_count: i64,
    pub video_count: i64,
}

/// Per-storyboard short-video readiness flags plus derived **`ready_for_generation`**.
///
/// Check semantics are documented in **`backend/docs/short-video-readiness-field-gaps.md`** (Jellyfish
/// extras vs stored fields).
#[derive(Serialize, ToSchema)]
pub struct StoryboardShortVideoReadiness {
    pub storyboard_id: Uuid,
    pub storyboard_numeric_id: i32,
    pub script_numeric_id: Option<i32>,
    pub sb_index: Option<i32>,
    /// Timeline ordering present (**`app_storyboard.sb_index`**).
    pub has_basic_slot: bool,
    /// Prompt or video description text present.
    pub has_prompt_context: bool,
    /// Reference frame / key visual (**`file_path`**) present.
    pub has_reference_visual: bool,
    /// Candidate review cleared — currently **`metadata.shortVideo.candidateStatus`** (see gaps doc).
    pub candidate_cleared: bool,
    /// No queued/running **`app_generation_job`** targeting this storyboard.
    pub no_blocking_job: bool,
    /// All of the above checks pass.
    pub ready_for_generation: bool,
    /// Machine-readable reasons when **`ready_for_generation`** is false.
    pub blocking_reasons: Vec<String>,
}

#[derive(Serialize, ToSchema)]
pub struct ShortVideoReadinessReasonRollup {
    pub reason: String,
    /// Storyboards that fail this check (one shot may contribute to multiple reasons).
    pub storyboard_count: i64,
}

#[derive(Serialize, ToSchema)]
pub struct ShortVideoReadinessRollup {
    pub total_storyboards: i64,
    pub ready_count: i64,
    pub blocked_count: i64,
    pub by_reason: Vec<ShortVideoReadinessReasonRollup>,
}

/// `GET /api/v1/projects/{project_id}/short-video-readiness`
#[derive(Serialize, ToSchema)]
pub struct ProjectShortVideoReadinessResponse {
    pub schema_version: i32,
    pub rollup: ShortVideoReadinessRollup,
    pub storyboards: Vec<StoryboardShortVideoReadiness>,
}

/// `GET /api/v1/projects/{project_id}/production-overview` — MP-W5 / A3 聚合。
#[derive(Serialize, ToSchema)]
pub struct ProjectProductionOverviewResponse {
    pub schema_version: i32,
    /// Same readiness rule as **`/short-video-readiness`** (**`ready_for_generation`**).
    pub ready_storyboard_count: i64,
    pub total_storyboard_count: i64,
    /// Distinct **`app_generation_job`** rows (**`queued`** / **`running`**) scoped to this project.
    pub running_generation_job_count: i64,
    /// **`app_quality_review`** rows with **`is_bad_case`** for this project (**`project_id`** = numeric).
    pub pending_review_bad_case_count: i64,
}

/// Aggregate counts for **`owner_user_id = JWT sub`** across all owned projects (single query).
#[derive(Serialize, ToSchema)]
pub struct ProjectsSummaryResponse {
    pub project_count: i64,
    pub script_count: i64,
    pub storyboard_count: i64,
    pub novel_count: i64,
    /// Same rule as per-project **`GET …/stats`**: **`app_asset`** with **`asset_type = 'role'`**.
    pub role_count: i64,
    pub art_style_count: i64,
    pub asset_count: i64,
    /// Same as per-project **`GET …/stats`**: **`0`** until video rows exist in Postgres.
    pub video_count: i64,
}

#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PatchProjectBody {
    #[serde(default)]
    pub name: Option<Value>,
    #[serde(default)]
    pub intro: Option<Value>,
    #[serde(default)]
    pub project_type: Option<Value>,
    #[serde(default)]
    pub image_model: Option<Value>,
    #[serde(default)]
    pub image_quality: Option<Value>,
    #[serde(default)]
    pub video_model: Option<Value>,
    #[serde(default)]
    pub art_style: Option<Value>,
    #[serde(default)]
    pub director_manual: Option<Value>,
    #[serde(default)]
    pub mode: Option<Value>,
    #[serde(default)]
    pub video_ratio: Option<Value>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    #[serde(default)]
    pub art_style_pack: Option<Value>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    #[serde(default)]
    pub story_style_pack: Option<Value>,
    /// 目标市场（如 domestic, overseas, both）
    #[serde(default)]
    #[schema(example = json!("domestic"))]
    pub target_market: Option<Value>,
    /// 目标平台数组（如 ["douyin", "bilibili", "tiktok"]）
    #[serde(default)]
    #[schema(example = json!(["douyin", "bilibili"]))]
    pub target_platforms: Option<Value>,
    /// 时长策略（如 short, medium, long）
    #[serde(default)]
    #[schema(example = json!("short"))]
    pub duration_strategy: Option<Value>,
    /// 声线配置标识
    #[serde(default)]
    pub voice_profile: Option<Value>,
    /// 字幕样式标识
    #[serde(default)]
    pub subtitle_style: Option<Value>,
    /// BGM 策略
    #[serde(default)]
    pub bgm_strategy: Option<Value>,
}

/// `PATCH /api/v1/projects/{id}/style-config` 请求体
#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PatchStyleConfigBody {
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`），传 null 清除
    #[serde(default)]
    pub art_style_pack: Option<Value>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`），传 null 清除
    #[serde(default)]
    pub story_style_pack: Option<Value>,
}

/// JSON body for `POST /api/v1/projects` (camelCase from frontend; all fields optional).
#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateProjectBody {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub intro: Option<String>,
    #[serde(default)]
    pub project_type: Option<String>,
    #[serde(default)]
    pub image_model: Option<String>,
    #[serde(default)]
    pub image_quality: Option<String>,
    #[serde(default)]
    pub video_model: Option<String>,
    #[serde(default)]
    pub art_style: Option<String>,
    #[serde(default)]
    pub director_manual: Option<String>,
    #[serde(default)]
    pub mode: Option<String>,
    #[serde(default)]
    pub video_ratio: Option<String>,
    /// 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
    #[serde(default)]
    pub art_style_pack: Option<String>,
    /// 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）
    #[serde(default)]
    pub story_style_pack: Option<String>,
    /// 目标市场（如 domestic, overseas, both）
    #[serde(default)]
    #[schema(example = "domestic")]
    pub target_market: Option<String>,
    /// 目标平台数组（如 ["douyin", "bilibili", "tiktok"]）
    #[serde(default)]
    #[schema(example = json!(["douyin", "bilibili"]))]
    pub target_platforms: Option<Vec<String>>,
    /// 时长策略（如 short, medium, long）
    #[serde(default)]
    #[schema(example = "short")]
    pub duration_strategy: Option<String>,
    /// 声线配置标识
    #[serde(default)]
    pub voice_profile: Option<String>,
    /// 字幕样式标识
    #[serde(default)]
    pub subtitle_style: Option<String>,
    /// BGM 策略
    #[serde(default)]
    pub bgm_strategy: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::PatchStyleConfigBody;
    use serde_json::json;

    #[test]
    fn patch_style_config_body_accepts_clear_and_partial_updates() {
        let body: PatchStyleConfigBody = serde_json::from_value(json!({
            "artStylePack": "art_skills/realpeople_ancient_chinese",
            "storyStylePack": null
        }))
        .expect("deserialize patch style config");

        assert_eq!(
            body.art_style_pack,
            Some(json!("art_skills/realpeople_ancient_chinese"))
        );
        assert_eq!(body.story_style_pack, None);
    }

    #[test]
    fn patch_style_config_body_rejects_unknown_fields() {
        let body: Result<PatchStyleConfigBody, _> = serde_json::from_value(json!({
            "artStylePack": "art_skills/realpeople_ancient_chinese",
            "unexpected": true
        }));
        assert!(body.is_err());
    }
}
