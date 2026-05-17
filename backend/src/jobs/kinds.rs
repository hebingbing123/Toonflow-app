//! HTTP 接口和 Worker 使用的标准 `app_generation_job.kind` 值。
//!
//! 定义资产生成和提示词优化的任务类型常量。
//!
//! **`assets-generate`** 入队 payload 版本与 **`project_uuid`** 解析：见 [`crate::jobs::payload_project`] 与仓库 **`docs/plans/assets-generate-job-payload-v2.md`**。

/// Single-image asset generate (Electron-era **`POST …/assets-generate/generate`**); worker uses
/// **`images/edits`** when payload has `image_base64`, otherwise **`images/generations`**,
/// then inserts **`app_asset_image`** (**`file_path`** = provider URL or **`…/images/{id}/file`**
/// when **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** is set).
pub const JOB_KIND_ASSET_GENERATE_IMAGE: &str = "asset.generate.image";
/// Single prompt polish (Electron-era **`POST …/assets-generate/polish-prompt`**); worker calls chat completion when **`LlmConfig`** is set, else **`failed`**.
pub const JOB_KIND_ASSET_POLISH_PROMPT: &str = "asset.polish.prompt";
/// Batch / multiplex image work (**`POST …/assets-generate/batch-generate`** and production enqueue paths).
/// Worker branches on **`payload`**: non-empty **`items`** → one image + **`app_asset_image`** per item
/// (project-owned assets; optional positive **`script_id`** restricts each item to **`app_script_asset`**);
/// **`source: production.assets.batch-generate`** → script-linked asset only
/// (**`app_script_asset`**) then one **`app_asset_image`**; **`source: production.storyboard.batch-generate-image`**
/// → owned storyboard row then **`images/generations`** + **`app_storyboard.file_path`**; **`source: production.edit-image.generate-flow`**
/// → **`images/generations`** with result URL only (no DB row).
pub const JOB_KIND_ASSET_GENERATE_BATCH: &str = "asset.generate.batch";
/// Batch prompt polish (**`POST …/assets-generate/batch-polish`**); worker runs **`chat_completion_assistant_text`** per item when **`LlmConfig`** is set (cooperative cancel between items), else **`failed`**.
pub const JOB_KIND_ASSET_POLISH_BATCH: &str = "asset.polish.batch";
/// Electron-era **`modelTest`** probe (**`POST …/settings/vendors/model-test`**); worker performs a live
/// text/image/video vendor probe using stored credentials when present, otherwise server env fallbacks.
pub const JOB_KIND_SETTINGS_VENDOR_MODEL_TEST: &str = "settings.vendor.model_test";
/// Account data export (**`POST /api/v1/settings/account/export`**); worker snapshots current-user
/// structured data into a local zip artifact and returns a settings download path.
pub const JOB_KIND_SETTINGS_ACCOUNT_EXPORT: &str = "settings.account.export";
/// Workspace shared cleared-template audit export (**`POST …/shared/audit/export-async`**); worker
/// writes **`TOONFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR`** (defaults under temp), then history
/// is appended with **`job_id`** for **`GET …/export-jobs/{id}/file`**.
pub const JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT: &str =
    "settings.workspace_shared_audit.export";
/// Flutter / integration probe (**`POST /api/v1/jobs`**); worker sleeps ~1s then **`succeeded`** with **`{ ok, probe }`**.
pub const JOB_KIND_FLUTTER_PROBE: &str = "flutter.probe";
/// Video generation (**`POST …/production/workbench/generate-video`**); worker generates video from storyboard items.
pub const JOB_KIND_VIDEO_GENERATE: &str = "video.generate";
/// Video export (**`POST …/production/export-image`** export as video); worker exports video file.
pub const JOB_KIND_VIDEO_EXPORT: &str = "video.export";
/// Batch rough-cut pre-assembly manifest (**`POST …/short-video-pre-assembly`**).
pub const JOB_KIND_SHORT_VIDEO_PRE_ASSEMBLY: &str = "short_video.pre_assembly";
/// Timeline preview mux (**`POST …/short-video-timeline/preview`**).
pub const JOB_KIND_SHORT_VIDEO_TIMELINE_PREVIEW: &str = "short_video.timeline_preview";
/// Voiceover generation (**`POST …/production/workbench/generate-voiceover`**); worker synthesizes
/// storyboard narration into a persisted local audio artifact and writes the latest artifact
/// reference back into **`app_storyboard.metadata.voiceover`**.
pub const JOB_KIND_VOICEOVER_GENERATE: &str = "voiceover.generate";
/// Reserved (**L2**): timed subtitles / captions; enqueue may set **`job_sub_kind`** = **`subtitle.captions`**;
/// worker route not implemented — jobs would fail until a handler lands.
pub const JOB_KIND_SUBTITLE_GENERATE: &str = "subtitle.generate";
/// Reserved (**L2**): background music mix; enqueue may set **`job_sub_kind`** = **`bgm.mix`**;
/// worker route not implemented — jobs would fail until a handler lands.
pub const JOB_KIND_BGM_GENERATE: &str = "bgm.generate";

/// Hosted novel crawl import batch (premium): executes `crawl-import-batch` logic under job worker.
pub const JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH: &str = "novel.crawl.import_batch";
