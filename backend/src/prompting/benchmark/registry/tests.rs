//! 基线样本注册表单元测试。

#[cfg(test)]
mod tests {
    use super::super::handlers::{
        validate_case_type, validate_source_kind, validate_stage,
    };

    #[test]
    fn test_validate_stage_accepts_valid_stages() {
        assert!(validate_stage("story_skeleton").is_ok());
        assert!(validate_stage("adaptation_strategy").is_ok());
        assert!(validate_stage("director_planning").is_ok());
        assert!(validate_stage("storyboard_table").is_ok());
        assert!(validate_stage("storyboard_panel").is_ok());
        assert!(validate_stage("video_prompt").is_ok());
    }

    #[test]
    fn test_validate_stage_rejects_invalid_stages() {
        assert!(validate_stage("invalid_stage").is_err());
        assert!(validate_stage("").is_err());
        assert!(validate_stage("STORY_SKELETON").is_err());
    }

    #[test]
    fn test_validate_case_type_accepts_valid_types() {
        assert!(validate_case_type("golden").is_ok());
        assert!(validate_case_type("bad_case").is_ok());
        assert!(validate_case_type("regression_guard").is_ok());
    }

    #[test]
    fn test_validate_case_type_rejects_invalid_types() {
        assert!(validate_case_type("invalid_type").is_err());
        assert!(validate_case_type("").is_err());
        assert!(validate_case_type("GOLDEN").is_err());
    }

    #[test]
    fn test_validate_source_kind_accepts_valid_sources() {
        assert!(validate_source_kind("quality_review").is_ok());
        assert!(validate_source_kind("job_failure").is_ok());
        assert!(validate_source_kind("patch_attribution").is_ok());
        assert!(validate_source_kind("manual").is_ok());
    }

    #[test]
    fn test_validate_source_kind_rejects_invalid_sources() {
        assert!(validate_source_kind("invalid_source").is_err());
        assert!(validate_source_kind("").is_err());
        assert!(validate_source_kind("MANUAL").is_err());
    }
}
