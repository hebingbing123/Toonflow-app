pub(crate) mod create_list;
pub(crate) mod detail;

pub(crate) use create_list::{create_project, list_projects, projects_summary};
pub(crate) use detail::{
    create_project_member, delete_project_by_id, delete_project_member, get_project_by_id,
    list_project_audit, list_project_members, patch_project_by_id, patch_project_member,
    patch_style_config, project_assets_overview_by_id, project_home_by_id, project_overview_by_id,
    project_production_overview_by_id, project_short_video_assembly_by_id,
    project_short_video_export_by_id, project_short_video_export_check_by_id,
    project_short_video_pre_assembly_by_id, project_short_video_readiness_by_id,
    project_short_video_timeline_apply_template, project_short_video_timeline_by_id,
    project_short_video_timeline_preview, project_short_video_timeline_put,
    project_short_video_timeline_reorder, project_short_video_timeline_restore,
    project_short_video_timeline_revisions, project_stats_by_id,
};

#[cfg(test)]
mod tests {
    use super::super::types::{CreateProjectBody, PatchProjectBody};

    #[test]
    fn patch_project_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchProjectBody>(r#"{"name":"a","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_project_body_accepts_empty_object() {
        let b: CreateProjectBody = serde_json::from_str("{}").unwrap();
        assert!(b.name.is_none());
    }

    #[test]
    fn create_project_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateProjectBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }
}
