//! Workflow graph primitives shared by desktop and backend orchestration.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WorkflowDocument {
    pub id: Uuid,
    pub nodes: Vec<WorkflowNode>,
    pub edges: Vec<WorkflowEdge>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WorkflowNode {
    pub id: Uuid,
    pub kind: WorkflowNodeKind,
    pub label: String,
    pub config: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WorkflowEdge {
    pub from: Uuid,
    pub to: Uuid,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum WorkflowNodeKind {
    Transcription,
    SceneDetect,
    ImageGenerate,
    VideoGenerate,
    SubtitleGenerate,
    Export,
}

impl WorkflowDocument {
    pub fn empty() -> Self {
        Self {
            id: Uuid::new_v4(),
            nodes: Vec::new(),
            edges: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_workflow_has_no_nodes() {
        let doc = WorkflowDocument::empty();
        assert!(doc.nodes.is_empty());
        assert!(doc.edges.is_empty());
    }
}
