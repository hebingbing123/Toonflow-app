//! Service Level Indicator (SLI) definitions for critical paths.

use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

/// Critical user paths that have defined SLIs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum CriticalPath {
    /// Video generation workflow (storyboard → video generation)
    VideoGeneration,
    /// Publish workflow (draft → job creation → delivery)
    PublishWorkflow,
    /// Quality review workflow (review → rework loop)
    QualityReview,
    /// Project overview loading (dashboard aggregation)
    ProjectOverview,
    /// Asset management operations (upload, generate, delete)
    AssetManagement,
}

/// SLI definition for a critical path.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SliDefinition {
    /// Critical path identifier
    pub path: CriticalPath,
    /// Human-readable name
    pub name: String,
    /// Description of what this path does
    pub description: String,
    /// Endpoint patterns that belong to this path
    pub endpoints: Vec<String>,
    /// Target p95 latency in milliseconds
    pub target_p95_latency_ms: u64,
    /// Target success rate (0.0 to 1.0)
    pub target_success_rate: f64,
    /// Target availability (0.0 to 1.0)
    pub target_availability: f64,
}

/// SLI snapshot showing current performance vs targets.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SliSnapshot {
    /// Critical path
    pub path: CriticalPath,
    /// SLI definition
    pub definition: SliDefinition,
    /// Current p95 latency in milliseconds
    pub current_p95_latency_ms: u64,
    /// Current success rate (0.0 to 1.0)
    pub current_success_rate: f64,
    /// Current availability (0.0 to 1.0)
    pub current_availability: f64,
    /// Whether p95 latency meets target
    pub latency_meets_target: bool,
    /// Whether success rate meets target
    pub success_rate_meets_target: bool,
    /// Whether availability meets target
    pub availability_meets_target: bool,
    /// Overall SLI health (all targets met)
    pub healthy: bool,
    /// Total requests in measurement window
    pub total_requests: u64,
}

/// SLI definitions for all critical paths.
pub static SLI_DEFINITIONS: Lazy<Vec<SliDefinition>> = Lazy::new(|| {
    vec![
        SliDefinition {
            path: CriticalPath::VideoGeneration,
            name: "Video Generation Workflow".to_string(),
            description:
                "Storyboard to video generation including prompt generation and video job creation"
                    .to_string(),
            endpoints: vec![
                "/api/v1/production/workbench/generate-video".to_string(),
                "/api/v1/production/workbench/batch-generate-candidate-clips".to_string(),
                "/api/v1/production/workbench/generate-video-prompt".to_string(),
                "/api/v1/production/workbench/get-video-list".to_string(),
            ],
            target_p95_latency_ms: 60_000, // 60 seconds for video generation
            target_success_rate: 0.95,     // 95% success rate
            target_availability: 0.99,     // 99% availability
        },
        SliDefinition {
            path: CriticalPath::PublishWorkflow,
            name: "Publish Workflow".to_string(),
            description: "Draft creation, platform targeting, job creation, and delivery"
                .to_string(),
            endpoints: vec![
                "/api/v1/projects/{project_id}/publish/drafts".to_string(),
                "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/targets".to_string(),
                "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/jobs".to_string(),
                "/api/v1/projects/{project_id}/publish/drafts/{draft_id}/prepare-check".to_string(),
            ],
            target_p95_latency_ms: 5_000, // 5 seconds for publish operations
            target_success_rate: 0.99,    // 99% success rate
            target_availability: 0.995,   // 99.5% availability
        },
        SliDefinition {
            path: CriticalPath::QualityReview,
            name: "Quality Review Workflow".to_string(),
            description: "Quality review, bad case detection, and rework loop".to_string(),
            endpoints: vec![
                "/api/v1/projects/{project_id}/production-overview".to_string(),
                "/api/v1/projects/{project_id}/short-video-export-check".to_string(),
            ],
            target_p95_latency_ms: 2_000, // 2 seconds for quality checks
            target_success_rate: 0.98,    // 98% success rate
            target_availability: 0.99,    // 99% availability
        },
        SliDefinition {
            path: CriticalPath::ProjectOverview,
            name: "Project Overview Loading".to_string(),
            description: "Dashboard aggregation and project overview data loading".to_string(),
            endpoints: vec![
                "/api/v1/projects/{project_id}/production-overview".to_string(),
                "/api/v1/projects/{project_id}/short-video-assembly".to_string(),
                "/api/v1/projects/{project_id}/assets-overview".to_string(),
            ],
            target_p95_latency_ms: 500, // 500ms for dashboard loading
            target_success_rate: 0.99,  // 99% success rate
            target_availability: 0.995, // 99.5% availability
        },
        SliDefinition {
            path: CriticalPath::AssetManagement,
            name: "Asset Management Operations".to_string(),
            description: "Asset upload, generation, deletion, and retrieval".to_string(),
            endpoints: vec![
                "/api/v1/production/assets/batch-generate-assets-image".to_string(),
                "/api/v1/production/assets/delete-assets-derivative".to_string(),
                "/api/v1/production/assets/get-assets-data".to_string(),
                "/api/v1/production/assets/update-assets-url".to_string(),
            ],
            target_p95_latency_ms: 10_000, // 10 seconds for asset operations
            target_success_rate: 0.97,     // 97% success rate
            target_availability: 0.99,     // 99% availability
        },
    ]
});

impl SliDefinition {
    /// Check if an endpoint path matches this SLI definition.
    pub fn matches_endpoint(&self, path: &str) -> bool {
        self.endpoints.iter().any(|pattern| {
            // Simple pattern matching: exact match or segment-based match for parameterized paths
            if pattern.contains("{") {
                // Pattern has parameters, do segment-based matching
                let pattern_segments: Vec<&str> = pattern.split('/').collect();
                let path_segments: Vec<&str> = path.split('/').collect();

                // Must have same number of segments
                if pattern_segments.len() != path_segments.len() {
                    return false;
                }

                // Match each segment (parameters match any value)
                pattern_segments
                    .iter()
                    .zip(path_segments.iter())
                    .all(|(pattern_seg, path_seg)| {
                        pattern_seg.starts_with('{') || pattern_seg == path_seg
                    })
            } else {
                // Exact match
                path == pattern
            }
        })
    }

    /// Get SLI definition by critical path.
    pub fn get(path: CriticalPath) -> Option<SliDefinition> {
        SLI_DEFINITIONS.iter().find(|def| def.path == path).cloned()
    }

    /// Get SLI definition for an endpoint path.
    pub fn for_endpoint(path: &str) -> Option<SliDefinition> {
        SLI_DEFINITIONS
            .iter()
            .find(|def| def.matches_endpoint(path))
            .cloned()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_endpoint_matching_exact() {
        let def = SliDefinition::get(CriticalPath::VideoGeneration).unwrap();
        assert!(def.matches_endpoint("/api/v1/production/workbench/generate-video"));
        assert!(!def.matches_endpoint("/api/v1/production/workbench/other"));
    }

    #[test]
    fn test_endpoint_matching_parameterized() {
        let def = SliDefinition::get(CriticalPath::PublishWorkflow).unwrap();
        assert!(def.matches_endpoint("/api/v1/projects/123/publish/drafts"));
        assert!(def.matches_endpoint("/api/v1/projects/456/publish/drafts/789/targets"));
        assert!(!def.matches_endpoint("/api/v1/projects/123/other"));
    }

    #[test]
    fn test_for_endpoint() {
        let def = SliDefinition::for_endpoint("/api/v1/production/workbench/generate-video");
        assert!(def.is_some());
        assert_eq!(def.unwrap().path, CriticalPath::VideoGeneration);

        let def = SliDefinition::for_endpoint("/api/v1/projects/123/publish/drafts");
        assert!(def.is_some());
        assert_eq!(def.unwrap().path, CriticalPath::PublishWorkflow);

        let def = SliDefinition::for_endpoint("/api/v1/unknown");
        assert!(def.is_none());
    }
}
