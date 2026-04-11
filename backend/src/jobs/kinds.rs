//! Well-known `app_generation_job.kind` values used by HTTP surfaces and the worker.

/// Single-image asset generate (legacy **`POST …/assets-generate/generate`**); worker uses
/// **`images/edits`** when payload has `image_base64`, otherwise **`images/generations`**,
/// then inserts **`app_asset_image`** (**`file_path`** = provider URL or **`…/images/{id}/file`**
/// when **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** is set).
pub const JOB_KIND_ASSET_GENERATE_IMAGE: &str = "asset.generate.image";
/// Single prompt polish (legacy **`POST …/assets-generate/polish-prompt`**); worker calls chat completion when **`LlmConfig`** is set, else **`failed`**.
pub const JOB_KIND_ASSET_POLISH_PROMPT: &str = "asset.polish.prompt";
/// Batch image generate (**`POST …/assets-generate/batch-generate`**); worker runs one image call
/// (prefer **`images/edits`** when `image_base64` exists, fallback **`images/generations`**) plus
/// one **`app_asset_image`** insert per item when LLM key is set (same **`file_path`** rules as
/// single-image).
pub const JOB_KIND_ASSET_GENERATE_BATCH: &str = "asset.generate.batch";
/// Batch prompt polish (**`POST …/assets-generate/batch-polish`**); worker runs **`chat_completion_assistant_text`** per item when **`LlmConfig`** is set (cooperative cancel between items), else **`failed`**.
pub const JOB_KIND_ASSET_POLISH_BATCH: &str = "asset.polish.batch";
/// Legacy **`modelTest`** probe (**`POST …/settings/vendors/model-test`**); worker performs a live
/// text/image/video vendor probe using stored credentials when present, otherwise server env fallbacks.
pub const JOB_KIND_SETTINGS_VENDOR_MODEL_TEST: &str = "settings.vendor.model_test";
/// Flutter / integration probe (**`POST /api/v1/jobs`**); worker sleeps ~1s then **`succeeded`** with **`{ ok, probe }`**.
pub const JOB_KIND_FLUTTER_PROBE: &str = "flutter.probe";
/// Video generation (**`POST …/production/workbench/generate-video`**); worker generates video from storyboard items.
pub const JOB_KIND_VIDEO_GENERATE: &str = "video.generate";
/// Video export (**`POST …/production/export-image`** export as video); worker exports video file.
pub const JOB_KIND_VIDEO_EXPORT: &str = "video.export";
