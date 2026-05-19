/// Desktop bridge surface for Flutter <-> Rust integration.
mod frb_generated;

pub mod api;

pub use api::*;
pub use media_image_doc::ImageDocument;
pub use media_timeline::TimelineDocument;
pub use media_workflow::WorkflowDocument;
