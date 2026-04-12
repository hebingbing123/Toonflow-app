//! HTTP 接口和 Worker 使用的标准 `app_generation_job.kind` 值。
//!
//! 定义资产生成和提示词优化的任务类型常量。

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
/// Flutter / integration probe (**`POST /api/v1/jobs`**); worker sleeps ~1s then **`succeeded`** with **`{ ok, probe }`**.
pub const JOB_KIND_FLUTTER_PROBE: &str = "flutter.probe";
/// Video generation (**`POST …/production/workbench/generate-video`**); worker generates video from storyboard items.
pub const JOB_KIND_VIDEO_GENERATE: &str = "video.generate";
/// Video export (**`POST …/production/export-image`** export as video); worker exports video file.
pub const JOB_KIND_VIDEO_EXPORT: &str = "video.export";
