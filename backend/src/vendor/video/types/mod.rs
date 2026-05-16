mod export;
mod generation;
mod provider;

pub use export::{VideoExportRequest, VideoExportResponse, VideoExportStatus};
pub use generation::{VideoGenerationRequest, VideoGenerationResponse, VideoGenerationStatus};
pub use provider::VideoProvider;

// Re-exported for `vendor::video` integration tests (`super::types::default_*`).
#[allow(unused_imports)]
pub(crate) use generation::{default_aspect_ratio, default_duration, default_resolution};
