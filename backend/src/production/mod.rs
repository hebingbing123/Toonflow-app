//! **`POST /api/v1/production/*`** 制作工作台 HTTP 路由（与旧 Electron **`/api/production/**`** 对齐的契约面）。
//!
//! 数据在 PG（如 **`app_production_flow`**、**`app_storyboard`**、视频轨等）；历史命名见迁移文档。
//! 子模块：
//! - `workbench` — 流程、分镜、视频、轨道、图片编辑、资产

pub(crate) mod flow_data;
mod openapi;
pub(crate) mod patch;
mod quality_gate;
mod router;
mod types;
mod workbench;

#[cfg(test)]
mod tests;

pub use openapi::ProductionApi;
pub use quality_gate::QualityGateStrategy;
pub(crate) use quality_gate::{enforce_quality_gate, run_quality_gate, QualityGateStage};
#[cfg(test)]
pub(crate) use quality_gate::{QualityGateDecision, QualityGateIssue, QualityGateSeverity};
pub use router::router;
pub(crate) use types::{VideoItem, WorkbenchGenerateVideoBody};
pub(crate) use workbench::storyboard_ops::shot_text::{
    export_duration_warning_code, resolve_shot_script_source, resolve_shot_voiceover_ready,
};
pub(crate) use workbench::video::generate::{
    infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
};
pub(crate) use workbench::video_prompt_memory::{
    build_selected_video_memory, clear_rejected_video_negative_memory,
    compact_selected_video_memory_for_focus, optimize_scoped_video_memory,
    persist_rejected_video_negative_memory, persist_selected_video_memory,
    refresh_project_video_style_memory, refresh_script_video_style_memory,
    selected_video_memory_is_low_signal, storyboard_prompt_seed, StoryboardPromptSeedRow,
};
