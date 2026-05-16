use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow, ToSchema)]
pub struct ExportTask {
    pub id: Uuid,
    pub project_id: Uuid,
    pub version_id: Option<Uuid>,
    pub status: String,
    pub stage: Option<String>,
    pub progress: i32,
    pub format: String,
    pub quality: serde_json::Value,
    pub output_url: Option<String>,
    pub error: Option<String>,
    pub started_at: Option<DateTime<Utc>>,
    pub completed_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum ExportStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
}

impl ExportStatus {
    pub fn as_str(&self) -> &str {
        match self {
            ExportStatus::Pending => "pending",
            ExportStatus::Running => "running",
            ExportStatus::Completed => "completed",
            ExportStatus::Failed => "failed",
            ExportStatus::Cancelled => "cancelled",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum ExportStage {
    Preparing,
    Encoding,
    Uploading,
    Finalizing,
}

impl ExportStage {
    pub fn as_str(&self) -> &str {
        match self {
            ExportStage::Preparing => "preparing",
            ExportStage::Encoding => "encoding",
            ExportStage::Uploading => "uploading",
            ExportStage::Finalizing => "finalizing",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum ExportFormat {
    Mp4,
    Mov,
    #[serde(rename = "webm")]
    WebM,
}

impl ExportFormat {
    pub fn as_str(&self) -> &str {
        match self {
            ExportFormat::Mp4 => "mp4",
            ExportFormat::Mov => "mov",
            ExportFormat::WebM => "webm",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ExportQuality {
    pub resolution: String, // "1080p", "720p", "480p"
    pub bitrate: i32,       // kbps
    pub framerate: i32,     // fps
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct CreateExportTaskRequest {
    pub project_id: Uuid,
    pub version_id: Option<Uuid>,
    pub format: ExportFormat,
    pub quality: ExportQuality,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, utoipa::IntoParams)]
pub struct ExportTaskListQuery {
    pub project_id: Option<Uuid>,
    pub status: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct CancelExportTaskRequest {
    pub task_id: Uuid,
}
