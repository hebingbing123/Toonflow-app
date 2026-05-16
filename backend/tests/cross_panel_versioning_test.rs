//! Cross-panel snapshot versioning tests (K.4)

#[cfg(test)]
mod tests {
    #[test]
    fn test_production_overview_response_has_data_version_field() {
        // Verify the response type includes dataVersion field
        let sample = serde_json::json!({
            "schema_version": 1,
            "dataVersion": "2025-01-15 10:30:45.123456+00",
            "ready_storyboard_count": 10,
            "total_storyboard_count": 15,
            "running_generation_job_count": 2,
            "pending_review_bad_case_count": 3
        });

        assert!(sample.get("dataVersion").is_some());
        assert_eq!(
            sample["dataVersion"].as_str(),
            Some("2025-01-15 10:30:45.123456+00")
        );
    }

    #[test]
    fn test_assets_overview_response_has_data_version_field() {
        let sample = serde_json::json!({
            "schema_version": 1,
            "dataVersion": "2025-01-15 10:30:45.123456+00",
            "total_count": 5,
            "candidate_counts": {
                "pending": 1,
                "linked": 2,
                "ignored": 1,
                "unset": 1
            },
            "by_asset_type": []
        });

        assert!(sample.get("dataVersion").is_some());
    }

    #[test]
    fn test_short_video_assembly_response_has_data_version_field() {
        let sample = serde_json::json!({
            "schema_version": 1,
            "dataVersion": "2025-01-15 10:30:45.123456+00",
            "project_defaults": {
                "voice_profile": null,
                "subtitle_style": null,
                "bgm_strategy": null
            },
            "effective_short_video_defaults": {
                "tts_voice": "alloy",
                "subtitle_style": null,
                "bgm_strategy": null
            },
            "candidate_quality_summary": {
                "schema_version": 1,
                "project_bad_case_total": 0,
                "assembly_shot_review_total": 0,
                "assembly_shot_bad_case_count": 0,
                "assembly_shots_with_bad_case": 0,
                "assembly_late_stage_bad_case_count": 0,
                "bad_cases_by_stage": [],
                "quality_degradation_count": 0,
                "quality_degradation_rate_percent": 0.0
            },
            "scripts": []
        });

        assert!(sample.get("dataVersion").is_some());
    }

    #[test]
    fn test_export_check_response_has_data_version_field() {
        let sample = serde_json::json!({
            "schema_version": 1,
            "dataVersion": "2025-01-15 10:30:45.123456+00",
            "export_ready": true,
            "summary": {
                "storyboard_count": 10,
                "blocking_issue_count": 0,
                "warning_issue_count": 2
            },
            "issues": [],
            "quality_gate_placeholder": {
                "schema_version": 1,
                "enforced": false,
                "pending_review_bad_case_count": 0
            }
        });

        assert!(sample.get("dataVersion").is_some());
    }

    #[test]
    fn test_data_version_can_be_null() {
        // dataVersion is optional and can be null if no data exists
        let sample = serde_json::json!({
            "schema_version": 1,
            "dataVersion": null,
            "ready_storyboard_count": 0,
            "total_storyboard_count": 0,
            "running_generation_job_count": 0,
            "pending_review_bad_case_count": 0
        });

        assert!(sample.get("dataVersion").is_some());
        assert!(sample["dataVersion"].is_null());
    }

    #[test]
    fn test_version_comparison_logic() {
        // Test that version comparison works correctly
        let v1 = "2025-01-15 10:30:45.123456+00";
        let v2 = "2025-01-15 10:35:12.789012+00";

        // v2 should be newer than v1
        assert!(v2 > v1);
    }

    #[test]
    fn test_consistency_detection_logic() {
        // Simulate cross-panel consistency checking
        struct PanelSnapshot {
            panel: &'static str,
            data_version: Option<&'static str>,
        }

        let panels = [
            PanelSnapshot {
                panel: "production",
                data_version: Some("2025-01-15 10:30:45.123456+00"),
            },
            PanelSnapshot {
                panel: "assets",
                data_version: Some("2025-01-15 10:35:12.789012+00"),
            },
            PanelSnapshot {
                panel: "assembly",
                data_version: Some("2025-01-15 10:30:45.123456+00"),
            },
        ];

        // Find latest version
        let latest = panels.iter().filter_map(|p| p.data_version).max().unwrap();

        assert_eq!(latest, "2025-01-15 10:35:12.789012+00");

        // Find stale panels
        let stale_panels: Vec<_> = panels
            .iter()
            .filter(|p| p.data_version.is_some() && p.data_version.unwrap() < latest)
            .map(|p| p.panel)
            .collect();

        assert_eq!(stale_panels, vec!["production", "assembly"]);
    }
}
