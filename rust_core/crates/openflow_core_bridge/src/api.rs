pub use media_image_doc::ImageDocument;
pub use media_timeline::TimelineDocument;
pub use media_workflow::WorkflowDocument;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CoreBridgeHealth {
    pub bridge_api_version: u32,
    pub rust_core_version: String,
    pub desktop_supported: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TimelineSummary {
    pub document_id: String,
    pub revision: u32,
    pub video_track_count: usize,
    pub audio_track_count: usize,
    pub subtitle_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImageDocumentSummary {
    pub document_id: String,
    pub width: u32,
    pub height: u32,
    pub layer_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WorkflowSummary {
    pub document_id: String,
    pub node_count: usize,
    pub edge_count: usize,
}

pub fn bridge_health() -> CoreBridgeHealth {
    CoreBridgeHealth {
        bridge_api_version: 1,
        rust_core_version: env!("CARGO_PKG_VERSION").to_string(),
        desktop_supported: true,
    }
}

pub fn new_timeline_document() -> TimelineDocument {
    TimelineDocument::empty()
}

pub fn summarize_timeline_document(document: TimelineDocument) -> TimelineSummary {
    TimelineSummary {
        document_id: document.id.to_string(),
        revision: document.revision,
        video_track_count: document.video_tracks.len(),
        audio_track_count: document.audio_tracks.len(),
        subtitle_count: document.subtitles.len(),
    }
}

pub fn new_image_document(width: u32, height: u32) -> ImageDocument {
    ImageDocument::new(width, height)
}

pub fn summarize_image_document(document: ImageDocument) -> ImageDocumentSummary {
    ImageDocumentSummary {
        document_id: document.id.to_string(),
        width: document.width,
        height: document.height,
        layer_count: document.layers.len(),
    }
}

pub fn new_workflow_document() -> WorkflowDocument {
    WorkflowDocument::empty()
}

pub fn summarize_workflow_document(document: WorkflowDocument) -> WorkflowSummary {
    WorkflowSummary {
        document_id: document.id.to_string(),
        node_count: document.nodes.len(),
        edge_count: document.edges.len(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bridge_health_reports_desktop_support() {
        let health = bridge_health();
        assert_eq!(health.bridge_api_version, 1);
        assert!(health.desktop_supported);
    }

    #[test]
    fn fresh_documents_summarize_to_zero_content() {
        let timeline = summarize_timeline_document(new_timeline_document());
        assert_eq!(timeline.video_track_count, 0);
        assert_eq!(timeline.audio_track_count, 0);
        assert_eq!(timeline.subtitle_count, 0);

        let image = summarize_image_document(new_image_document(1920, 1080));
        assert_eq!(image.width, 1920);
        assert_eq!(image.height, 1080);
        assert_eq!(image.layer_count, 0);

        let workflow = summarize_workflow_document(new_workflow_document());
        assert_eq!(workflow.node_count, 0);
        assert_eq!(workflow.edge_count, 0);
    }
}
