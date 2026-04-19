use serde::{Deserialize, Serialize};

/// Video export request parameters
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoExportRequest {
    /// Source video URL
    pub source_url: String,
    /// Export format (mp4, mov, etc.)
    #[serde(default = "default_export_format")]
    pub format: String,
    /// Target resolution
    #[serde(skip_serializing_if = "Option::is_none")]
    pub target_resolution: Option<String>,
    /// Include audio
    #[serde(default = "default_true")]
    pub include_audio: bool,
}

fn default_export_format() -> String {
    "mp4".to_string()
}
fn default_true() -> bool {
    true
}

/// Video export response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VideoExportResponse {
    /// Export task ID
    pub task_id: String,
    /// Current status
    pub status: VideoExportStatus,
    /// Exported video URL
    #[serde(skip_serializing_if = "Option::is_none")]
    pub export_url: Option<String>,
    /// Error message if failed
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

/// Video export status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VideoExportStatus {
    Queued,
    Processing,
    Completed,
    Failed,
}

impl VideoExportStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Processing => "processing",
            Self::Completed => "completed",
            Self::Failed => "failed",
        }
    }
}
