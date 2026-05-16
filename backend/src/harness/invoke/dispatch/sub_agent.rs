pub(super) fn is_sub_agent_tool(name: &str) -> bool {
    matches!(
        name,
        "run_sub_agent_storySkeleton"
            | "run_sub_agent_adaptationStrategy"
            | "run_sub_agent_script"
            | "run_supervision_agent"
            | "run_sub_agent_derive_assets"
            | "run_sub_agent_generate_assets"
            | "run_sub_agent_director_plan"
            | "run_sub_agent_storyboard_gen"
            | "run_sub_agent_storyboard_panel"
            | "run_sub_agent_storyboard_table"
            | "run_sub_agent_production_supervision"
    )
}
