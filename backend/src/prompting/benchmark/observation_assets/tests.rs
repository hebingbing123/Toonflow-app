//! 观察资产治理单元测试。

#[cfg(test)]
mod tests {
    use crate::prompting::benchmark::observation_assets::handlers::{
        validate_scope_kind, validate_source_kind, validate_status,
    };

    #[test]
    fn test_validate_scope_kind() {
        assert!(validate_scope_kind("global").is_ok());
        assert!(validate_scope_kind("project").is_ok());
        assert!(validate_scope_kind("style_pack").is_ok());
        assert!(validate_scope_kind("invalid").is_err());
    }

    #[test]
    fn test_validate_source_kind() {
        assert!(validate_source_kind("quality_review").is_ok());
        assert!(validate_source_kind("job_failure").is_ok());
        assert!(validate_source_kind("patch_attribution").is_ok());
        assert!(validate_source_kind("human_review").is_ok());
        assert!(validate_source_kind("experiment").is_ok());
        assert!(validate_source_kind("invalid").is_err());
    }

    #[test]
    fn test_validate_status() {
        assert!(validate_status("candidate").is_ok());
        assert!(validate_status("active").is_ok());
        assert!(validate_status("archived").is_ok());
        assert!(validate_status("rejected").is_ok());
        assert!(validate_status("invalid").is_err());
    }
}
