use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ProjectBrief {
    #[serde(default)]
    pub premise: Option<String>,
    #[serde(default)]
    pub target_audience: Option<String>,
    #[serde(default)]
    pub emotional_tone: Option<String>,
    #[serde(default)]
    pub core_hook: Option<String>,
    #[serde(default)]
    pub visual_direction: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BrandBible {
    #[serde(default)]
    pub brand_name: Option<String>,
    #[serde(default)]
    pub brand_promise: Option<String>,
    #[serde(default)]
    pub visual_motifs: Vec<String>,
    #[serde(default)]
    pub forbidden_elements: Vec<String>,
    #[serde(default)]
    pub continuity_rules: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ProjectHomeChecklistItem {
    pub key: String,
    pub label: String,
    pub done: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ProjectHomeOnboarding {
    pub complete: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub next_step: Option<String>,
    pub checklist: Vec<ProjectHomeChecklistItem>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ProjectHomeResponse {
    pub project: ProjectRow,
    pub stats: ProjectStatsResponse,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub project_brief: Option<ProjectBrief>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub brand_bible: Option<BrandBible>,
    pub readiness_score: i32,
    pub readiness_summary: String,
    pub onboarding: ProjectHomeOnboarding,
    pub style_bible_ready: bool,
}

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

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateProjectMemberBody {
    pub user_id: Uuid,
    /// Allowed: **`editor`** or **`viewer`**.
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PatchProjectMemberBody {
    /// Allowed: **`editor`** or **`viewer`**.
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ProjectMemberResponse {
    pub project_id: Uuid,
    pub user_id: Uuid,
    pub role: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, FromRow, Serialize, ToSchema)]
#[schema(
    title = "ProjectRow",
    description = "Project record with short video configuration fields"
)]
pub struct ProjectRow {
    pub id: Uuid,
    pub workspace_id: Option<Uuid>,
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
    /// Quality gate enforcement strategy (off/warn/block)
    #[schema(example = "block")]
    pub quality_gate_strategy: Option<String>,
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
/// **`role_count`** counts **`app_asset`** rows with **`asset_type = 'role'`**; **`novel_count`**
/// counts **`app_novel`** rows; **`video_count`** counts **`app_video`** rows in a terminal state
/// (**`state` ∈ `生成成功|已完成|succeeded|completed`**), matching production workbench material-data.
#[derive(Debug, Serialize, Deserialize, ToSchema)]
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
    /// 真人模式：至少 1 条参考镜头 URL（**`metadata.shortVideo.liveAction.referenceShotUrls`**）。
    pub has_live_action_reference_shots: bool,
    /// 真人模式：表演/口播约束说明（**`metadata.shortVideo.liveAction.performanceNotes`**）。
    pub has_live_action_performance_notes: bool,
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
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectProductionOverviewResponse {
    pub schema_version: i32,
    /// Snapshot version for cross-panel consistency checking (ISO 8601 timestamp).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data_version: Option<String>,
    /// Same readiness rule as **`/short-video-readiness`** (**`ready_for_generation`**).
    pub ready_storyboard_count: i64,
    pub total_storyboard_count: i64,
    /// Distinct **`app_generation_job`** rows (**`queued`** / **`running`**) scoped to this project.
    pub running_generation_job_count: i64,
    /// **`app_quality_review`** rows with **`is_bad_case`** for this project (**`project_id`** = numeric).
    pub pending_review_bad_case_count: i64,
}

/// `GET /api/v1/projects/{project_id}/assets-overview` — C5 统一资产只读聚合。
#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct AssetsOverviewCandidateCounts {
    pub pending: i64,
    pub linked: i64,
    pub ignored: i64,
    /// **`candidate_status`** unset or unknown — treated as non-candidate flow for counts.
    pub unset: i64,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct AssetsOverviewItem {
    pub asset_id: Uuid,
    pub numeric_id: i32,
    pub name: String,
    pub asset_type: String,
    pub candidate_status: Option<String>,
    /// Linked scripts (**`app_script.numeric_id`**) in the same project via **`app_script_asset`**.
    pub linked_script_numeric_ids: Vec<i32>,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct AssetsOverviewTypeGroup {
    pub asset_type: String,
    pub items: Vec<AssetsOverviewItem>,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectAssetsOverviewResponse {
    pub schema_version: i32,
    /// Snapshot version for cross-panel consistency checking (ISO 8601 timestamp).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data_version: Option<String>,
    pub total_count: i64,
    pub candidate_counts: AssetsOverviewCandidateCounts,
    pub by_asset_type: Vec<AssetsOverviewTypeGroup>,
}

/// `GET /api/v1/projects/{project_id}/short-video-assembly` — D1 成片装配只读读模型。
#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoAssemblyProjectDefaults {
    pub voice_profile: Option<String>,
    pub subtitle_style: Option<String>,
    pub bgm_strategy: Option<String>,
}

/// D7：**成片侧生效默认**（当前等价项目列；旁白声线与 enqueue/worker 解析一致）。
#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoAssemblyEffectiveDefaults {
    /// 解析后的 TTS **`voice`**（显式覆盖 \| **`voice_profile`** \| **`alloy`**）。
    #[schema(example = "alloy")]
    pub tts_voice: String,
    pub subtitle_style: Option<String>,
    pub bgm_strategy: Option<String>,
}

#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoAssemblyShot {
    pub storyboard_id: Uuid,
    pub storyboard_numeric_id: i32,
    pub sb_index: Option<i32>,
    pub selected_media_url: Option<String>,
    /// **`none`** \| **`video`** \| **`image`** \| **`other`** — heuristic from URL/path suffix.
    pub selected_media_kind: String,
    pub duration: Option<String>,
    pub state: Option<String>,
    pub track_id: Option<i32>,
    /// Same source field as **`app_storyboard.video_desc`** (字幕 / 口播文案)。
    pub subtitle_text: Option<String>,
    /// **`explicit_narration`** \| **`prompt_fallback`** \| **`placeholder`**（与导出 manifest 一致）。
    pub subtitle_source: String,
    /// Non-placeholder narration text exists for VO/TTS pipelines（与导出 **`voiceover_ready`** 一致）。
    pub voiceover_script_ready: bool,
    pub voiceover_state: Option<String>,
    pub voiceover_audio_url: Option<String>,
    pub voiceover_error: Option<String>,
    /// Completed VO asset with non-empty audio URL.
    pub voiceover_asset_ready: bool,
}

#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoAssemblyScriptGroup {
    pub script_numeric_id: i32,
    pub script_name: Option<String>,
    pub shots: Vec<ShortVideoAssemblyShot>,
}

/// L3：**成片候选 / 分镜级**质量评审摘要（只读；与 **`GET /api/v1/quality/reviews`** 同一 `app_quality_review` 源）。
#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoQualityStageBucket {
    /// 空字符串表示 **`stage` IS NULL**。
    pub stage: String,
    pub bad_case_count: i64,
}

/// 与当前装配快照中的分镜（`storyboard_numeric_id` 集合）对齐的坏例与评审计数。
#[derive(Serialize, Deserialize, ToSchema)]
pub struct ShortVideoCandidateQualitySummary {
    pub schema_version: i32,
    /// 与 **`GET …/production-overview`** **`pending_review_bad_case_count`** 同源（项目级坏例总数）。
    pub project_bad_case_total: i64,
    /// `target_type ∈ { storyboard, video, output }` 且 **`target_id`** 命中装配分镜的评审条数（含通过与坏例）。
    pub assembly_shot_review_total: i64,
    /// 上述范围内 **`is_bad_case`** 的条数。
    pub assembly_shot_bad_case_count: i64,
    /// 至少有一条坏例的不同分镜 **`numeric_id`** 数。
    pub assembly_shots_with_bad_case: i64,
    /// **`stage`** 为 **`storyboard_panel`** / **`video_prompt`** 的坏例数（更贴近成片验收）。
    pub assembly_late_stage_bad_case_count: i64,
    pub bad_cases_by_stage: Vec<ShortVideoQualityStageBucket>,
    /// 检测到质量退化的分镜数（I.3：storyboard→video→output 质量对比）
    pub quality_degradation_count: i64,
    /// 质量退化率（百分比）
    pub quality_degradation_rate_percent: f64,
}

#[derive(Serialize, Deserialize, ToSchema)]
pub struct ProjectShortVideoAssemblyResponse {
    pub schema_version: i32,
    /// Snapshot version for cross-panel consistency checking (ISO 8601 timestamp).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data_version: Option<String>,
    pub project_defaults: ShortVideoAssemblyProjectDefaults,
    pub effective_short_video_defaults: ShortVideoAssemblyEffectiveDefaults,
    /// 与 **`scripts`** 中分镜集合对齐的质量验收摘要（L3）。
    pub candidate_quality_summary: ShortVideoCandidateQualitySummary,
    pub scripts: Vec<ShortVideoAssemblyScriptGroup>,
}

/// `GET /api/v1/projects/{project_id}/short-video-export-check` — D2 导出前检查与摘要。
#[derive(Serialize, ToSchema)]
pub struct ShortVideoExportCheckSummary {
    pub storyboard_count: i64,
    pub blocking_issue_count: i64,
    pub warning_issue_count: i64,
}

#[derive(Serialize, ToSchema)]
pub struct ShortVideoExportCheckIssue {
    /// **`blocking`** \| **`warning`**
    pub severity: String,
    pub code: String,
    pub detail: String,
    pub script_numeric_id: i32,
    pub storyboard_id: Uuid,
    pub storyboard_numeric_id: i32,
    pub sb_index: Option<i32>,
}

/// **P7**: 导出质量门禁（off/warn/block）
#[derive(Serialize, ToSchema)]
pub struct ShortVideoExportQualityGate {
    pub schema_version: i32,
    /// 门禁策略：off（跳过检查）、warn（显示警告但允许）、block（阻断导出）
    #[schema(example = "block")]
    pub strategy: String,
    /// 是否强制执行（block 模式下为 true）
    pub enforced: bool,
    /// 与 **`GET …/production-overview`** **`pending_review_bad_case_count`** 同源计数。
    pub pending_review_bad_case_count: i64,
    /// block 模式下的阻断原因（结构化）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub blocking_reasons: Option<Vec<QualityGateBlockingReason>>,
}

/// 质量门禁阻断原因
#[derive(Serialize, ToSchema)]
pub struct QualityGateBlockingReason {
    pub code: String,
    pub message: String,
    /// 返工入口（前端路由或 deep link）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rework_route: Option<String>,
}

#[derive(Serialize, ToSchema)]
pub struct ProjectShortVideoExportCheckResponse {
    pub schema_version: i32,
    /// Snapshot version for cross-panel consistency checking (ISO 8601 timestamp).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data_version: Option<String>,
    pub export_ready: bool,
    pub summary: ShortVideoExportCheckSummary,
    pub issues: Vec<ShortVideoExportCheckIssue>,
    pub quality_gate: ShortVideoExportQualityGate,
}

/// Aggregate counts across projects visible via **`app_workspace_member`** (current workspace context on the server uses the same visibility rules as list endpoints).
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
    /// Completed **`app_video`** rows (**`state`** as in **`GET …/stats` `video_count`**) in visible projects.
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
    /// Quality gate enforcement strategy (off/warn/block)
    #[serde(default)]
    #[schema(example = json!("block"))]
    pub quality_gate_strategy: Option<Value>,
    #[serde(default)]
    pub project_brief: Option<Value>,
    #[serde(default)]
    pub brand_bible: Option<Value>,
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
    /// Optional explicit workspace target (`workspaceId`). Omit to use current workspace context.
    #[serde(default)]
    pub workspace_id: Option<Uuid>,
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
    #[serde(default)]
    pub project_brief: Option<ProjectBrief>,
    #[serde(default)]
    pub brand_bible: Option<BrandBible>,
}

/// `POST /api/v1/workbench/select-video` 请求体 — 选择/替换当前采用视频
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[allow(dead_code)]
pub struct WorkbenchSelectVideoRequest {
    pub project_id: i32,
    pub script_id: i32,
    pub storyboard_id: i32,
    pub video_url: String,
}

#[allow(dead_code)]
impl WorkbenchSelectVideoRequest {
    /// Validates the request fields.
    /// Returns an error message if validation fails.
    pub fn validate(&self) -> Result<(), String> {
        if self.video_url.trim().is_empty() {
            return Err("video_url cannot be empty".to_string());
        }
        Ok(())
    }
}

/// `POST /api/v1/workbench/delete-video` 请求体 — 清空当前采用视频(暂停镜头)
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[allow(dead_code)]
pub struct WorkbenchDeleteVideoRequest {
    pub project_id: i32,
    pub script_id: i32,
    pub storyboard_id: i32,
}

/// `POST /api/v1/storyboard/update-duration` 请求体 — 更新镜头时长
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[allow(dead_code)]
pub struct StoryboardUpdateDurationRequest {
    pub project_id: i32,
    pub script_id: i32,
    pub storyboard_id: i32,
    pub duration: i32,
}

#[allow(dead_code)]
impl StoryboardUpdateDurationRequest {
    /// Validates the request fields.
    /// Returns an error message if validation fails.
    /// Duration must be in range [1, 300] seconds.
    pub fn validate(&self) -> Result<(), String> {
        if self.duration < 1 || self.duration > 300 {
            return Err(format!(
                "duration must be between 1 and 300 seconds, got {}",
                self.duration
            ));
        }
        Ok(())
    }
}

/// `POST /api/v1/production/save-flow-data` 请求体 — 保存生产流程数据(持久化镜头顺序)
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[allow(dead_code)]
pub struct ProductionSaveFlowDataRequest {
    pub project_id: i32,
    pub episodes_id: i32,
    pub data: Value,
    /// Optional version timestamp (ISO 8601) for optimistic locking.
    /// If provided, the save will fail with 409 Conflict if the current
    /// `app_production_flow.updated_at` doesn't match this value.
    #[serde(default)]
    pub flow_version: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
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

    #[test]
    fn workbench_select_video_request_deserializes_correctly() {
        let body: WorkbenchSelectVideoRequest = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789,
            "videoUrl": "https://example.com/video.mp4"
        }))
        .expect("deserialize workbench select video request");

        assert_eq!(body.project_id, 123);
        assert_eq!(body.script_id, 456);
        assert_eq!(body.storyboard_id, 789);
        assert_eq!(body.video_url, "https://example.com/video.mp4");
    }

    #[test]
    fn workbench_select_video_request_rejects_unknown_fields() {
        let result: Result<WorkbenchSelectVideoRequest, _> = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789,
            "videoUrl": "https://example.com/video.mp4",
            "unexpected": true
        }));
        assert!(result.is_err());
    }

    #[test]
    fn workbench_delete_video_request_deserializes_correctly() {
        let body: WorkbenchDeleteVideoRequest = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789
        }))
        .expect("deserialize workbench delete video request");

        assert_eq!(body.project_id, 123);
        assert_eq!(body.script_id, 456);
        assert_eq!(body.storyboard_id, 789);
    }

    #[test]
    fn workbench_delete_video_request_rejects_unknown_fields() {
        let result: Result<WorkbenchDeleteVideoRequest, _> = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789,
            "unexpected": true
        }));
        assert!(result.is_err());
    }

    #[test]
    fn storyboard_update_duration_request_deserializes_correctly() {
        let body: StoryboardUpdateDurationRequest = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789,
            "duration": 10
        }))
        .expect("deserialize storyboard update duration request");

        assert_eq!(body.project_id, 123);
        assert_eq!(body.script_id, 456);
        assert_eq!(body.storyboard_id, 789);
        assert_eq!(body.duration, 10);
    }

    #[test]
    fn storyboard_update_duration_request_rejects_unknown_fields() {
        let result: Result<StoryboardUpdateDurationRequest, _> = serde_json::from_value(json!({
            "projectId": 123,
            "scriptId": 456,
            "storyboardId": 789,
            "duration": 10,
            "unexpected": true
        }));
        assert!(result.is_err());
    }

    #[test]
    fn production_save_flow_data_request_deserializes_correctly() {
        let body: ProductionSaveFlowDataRequest = serde_json::from_value(json!({
            "projectId": 123,
            "episodesId": 456,
            "data": {"storyboard": [{"id": 789}]}
        }))
        .expect("deserialize production save flow data request");

        assert_eq!(body.project_id, 123);
        assert_eq!(body.episodes_id, 456);
        assert!(body.data.is_object());
        assert_eq!(body.flow_version, None);
    }

    #[test]
    fn production_save_flow_data_request_with_version_deserializes_correctly() {
        let body: ProductionSaveFlowDataRequest = serde_json::from_value(json!({
            "projectId": 123,
            "episodesId": 456,
            "data": {"storyboard": [{"id": 789}]},
            "flowVersion": "2024-01-01T00:00:00Z"
        }))
        .expect("deserialize production save flow data request with version");

        assert_eq!(body.project_id, 123);
        assert_eq!(body.episodes_id, 456);
        assert!(body.data.is_object());
        assert_eq!(body.flow_version, Some("2024-01-01T00:00:00Z".to_string()));
    }

    #[test]
    fn production_save_flow_data_request_rejects_unknown_fields() {
        let result: Result<ProductionSaveFlowDataRequest, _> = serde_json::from_value(json!({
            "projectId": 123,
            "episodesId": 456,
            "data": {"storyboard": [{"id": 789}]},
            "unexpected": true
        }));
        assert!(result.is_err());
    }
}
