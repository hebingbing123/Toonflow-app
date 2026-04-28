//! Load and assemble context for video prompt generation.

use super::*;

#[derive(Debug, sqlx::FromRow)]
pub(super) struct ProjectPromptSeedRow {
    pub(super) art_style: Option<String>,
    pub(super) director_manual: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub(super) struct ScriptRolePromptSeedRow {
    pub(super) asset_type: String,
    pub(super) name: Option<String>,
    pub(super) describe: Option<String>,
}

pub(super) async fn load_video_prompt_context(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: Option<i32>,
    runtime: Option<&StoryboardNegativePromptRuntime>,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Result<Option<VideoPromptContext>, ApiError> {
    let Some(storyboard_numeric_id) = storyboard_id.filter(|id| *id > 0) else {
        return Ok(None);
    };
    let (row, memory_style_notes, continuity_notes) = if let Some(runtime) = runtime {
        let row = runtime.storyboard_row.clone().ok_or(ApiError::NotFound)?;
        let (memory_style_notes, continuity_notes) = build_video_prompt_memory_notes_with_pressure(
            runtime.prompt_support_rows.clone(),
            storyboard_numeric_id,
            runtime.current_prompt_seed.as_deref(),
            &row,
            constraint_pressure,
        );
        (row, memory_style_notes, continuity_notes)
    } else {
        let storyboard_uuid = crate::scope::owned_storyboard_in_script_scope(
            pool,
            user_id,
            project_id,
            script_id,
            storyboard_numeric_id,
        )
        .await
        .map_err(|e| e.into_api_error())?
        .storyboard_id;
        let row = sqlx::query_as::<_, StoryboardPromptSeedRow>(
            r#"
            SELECT prompt, video_desc, duration
            FROM app_storyboard
            WHERE id = $1
            "#,
        )
        .bind(storyboard_uuid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::NotFound)?;

        let current_prompt_seed = storyboard_prompt_seed(&row);
        let (memory_style_notes, continuity_notes) = load_video_prompt_memory_notes(
            pool,
            user_id,
            project_id,
            script_id,
            storyboard_numeric_id,
            current_prompt_seed.as_deref(),
            &row,
            constraint_pressure,
        )
        .await?;
        (row, memory_style_notes, continuity_notes)
    };
    let current_prompt_seed = storyboard_prompt_seed(&row);
    let project_row = sqlx::query_as::<_, ProjectPromptSeedRow>(
        r#"
        SELECT art_style, director_manual
        FROM app_project
        WHERE owner_user_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let script_role_rows = sqlx::query_as::<_, ScriptRolePromptSeedRow>(
        r#"
        SELECT a.asset_type, a.name, a.describe
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        INNER JOIN app_script sc ON sc.id = sa.script_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND a.asset_type IN ('role', 'scene', 'tool')
        ORDER BY a.created_at DESC
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let script_role_rows = select_video_prompt_asset_seed_rows(script_role_rows);

    let mut script_role_anchors = Vec::new();
    let mut script_scene_anchors = Vec::new();
    let mut script_tool_anchors = Vec::new();
    for row in script_role_rows {
        let Some(anchor) = compact_script_asset_anchor(row) else {
            continue;
        };
        match anchor.asset_type.as_str() {
            "role" => script_role_anchors.push(anchor.value),
            "scene" => script_scene_anchors.push(anchor.value),
            "tool" => script_tool_anchors.push(anchor.value),
            _ => {}
        }
    }

    Ok(Some(VideoPromptContext {
        storyboard_prompt: row.prompt,
        storyboard_video_desc: row.video_desc,
        storyboard_duration: row.duration,
        storyboard_prompt_seed: current_prompt_seed,
        project_art_style: project_row.as_ref().and_then(|row| row.art_style.clone()),
        project_director_manual: project_row
            .as_ref()
            .and_then(|row| row.director_manual.clone()),
        script_role_anchors,
        script_scene_anchors,
        script_tool_anchors,
        memory_style_notes,
        continuity_notes,
    }))
}

pub(super) fn select_video_prompt_asset_seed_rows(
    rows: Vec<ScriptRolePromptSeedRow>,
) -> Vec<ScriptRolePromptSeedRow> {
    let mut role_count = 0usize;
    let mut scene_count = 0usize;
    let mut tool_count = 0usize;
    let mut selected = Vec::new();

    for row in rows {
        let asset_type = normalize_prompt_text(&row.asset_type).to_lowercase();
        let keep = match asset_type.as_str() {
            "role" if role_count < VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT => {
                role_count += 1;
                true
            }
            "scene" if scene_count < VIDEO_PROMPT_SCENE_ASSET_ROW_LIMIT => {
                scene_count += 1;
                true
            }
            "tool" if tool_count < VIDEO_PROMPT_TOOL_ASSET_ROW_LIMIT => {
                tool_count += 1;
                true
            }
            _ => false,
        };
        if keep {
            selected.push(row);
        }
    }

    selected
}
