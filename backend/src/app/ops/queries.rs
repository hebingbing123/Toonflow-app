//! SQL 片段：`clear-user-data` 的计数与删除顺序。

pub(super) const COUNT_QUERIES: &[(&str, &str)] = &[
    (
        "projects",
        "SELECT COUNT(*)::bigint FROM public.app_project WHERE owner_user_id = $1",
    ),
    (
        "scripts",
        "SELECT COUNT(*)::bigint
         FROM public.app_script s
         INNER JOIN public.app_project p ON p.id = s.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "storyboards",
        "SELECT COUNT(*)::bigint
         FROM public.app_storyboard sb
         INNER JOIN public.app_script s ON s.id = sb.script_id
         INNER JOIN public.app_project p ON p.id = s.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "assets",
        "SELECT COUNT(*)::bigint
         FROM public.app_asset a
         INNER JOIN public.app_project p ON p.id = a.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "asset_images",
        "SELECT COUNT(*)::bigint
         FROM public.app_asset_image ai
         INNER JOIN public.app_asset a ON a.id = ai.asset_id
         INNER JOIN public.app_project p ON p.id = a.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "novels",
        "SELECT COUNT(*)::bigint
         FROM public.app_novel n
         INNER JOIN public.app_project p ON p.id = n.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "novel_events",
        "SELECT COUNT(*)::bigint
         FROM public.app_novel_event e
         INNER JOIN public.app_project p ON p.id = e.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "videos",
        "SELECT COUNT(*)::bigint
         FROM public.app_video v
         INNER JOIN public.app_project p ON p.id = v.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "video_tracks",
        "SELECT COUNT(*)::bigint
         FROM public.app_video_track vt
         INNER JOIN public.app_project p ON p.id = vt.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "generation_jobs",
        "SELECT COUNT(*)::bigint FROM public.app_generation_job WHERE owner_user_id = $1",
    ),
    (
        "quality_reviews",
        "SELECT COUNT(*)::bigint FROM public.app_quality_review WHERE user_id = $1",
    ),
    (
        "usage_events",
        "SELECT COUNT(*)::bigint FROM public.app_usage_event WHERE user_id = $1",
    ),
    (
        "agent_memories",
        "SELECT COUNT(*)::bigint FROM public.app_agent_memory WHERE owner_user_id = $1",
    ),
    (
        "script_agent_plans",
        "SELECT COUNT(*)::bigint FROM public.app_script_agent_plan WHERE owner_user_id = $1",
    ),
    (
        "art_styles",
        "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE owner_user_id = $1",
    ),
    (
        "prompts",
        "SELECT COUNT(*)::bigint FROM public.app_user_prompt WHERE owner_user_id = $1",
    ),
    (
        "vendor_credentials",
        "SELECT COUNT(*)::bigint FROM public.app_vendor_credential WHERE owner_user_id = $1",
    ),
    (
        "user_profiles",
        "SELECT COUNT(*)::bigint FROM public.app_user_profile WHERE user_id = $1",
    ),
    (
        "import_user_maps",
        "SELECT COUNT(*)::bigint FROM public.import_user_map WHERE supabase_user_id = $1",
    ),
];

pub(super) const DELETE_QUERIES: &[(&str, &str)] = &[
    (
        "quality_reviews",
        "DELETE FROM public.app_quality_review WHERE user_id = $1",
    ),
    (
        "generation_jobs",
        "DELETE FROM public.app_generation_job WHERE owner_user_id = $1",
    ),
    (
        "usage_events",
        "DELETE FROM public.app_usage_event WHERE user_id = $1",
    ),
    (
        "agent_memories",
        "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1",
    ),
    (
        "script_agent_plans",
        "DELETE FROM public.app_script_agent_plan WHERE owner_user_id = $1",
    ),
    (
        "art_styles",
        "DELETE FROM public.app_art_style WHERE owner_user_id = $1",
    ),
    (
        "prompts",
        "DELETE FROM public.app_user_prompt WHERE owner_user_id = $1",
    ),
    (
        "vendor_credentials",
        "DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1",
    ),
    (
        "projects",
        "DELETE FROM public.app_project WHERE owner_user_id = $1",
    ),
    (
        "import_user_maps",
        "DELETE FROM public.import_user_map WHERE supabase_user_id = $1",
    ),
    (
        "user_profiles",
        "DELETE FROM public.app_user_profile WHERE user_id = $1",
    ),
];
