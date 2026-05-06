use super::focus::prepare_selected_video_memory_for_storage;
use super::*;
use super::storage::{storyboard_scope_signature, summary_memory_allowed, VIDEO_SCOPED_MEMORY_TIER};

pub(crate) async fn persist_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let optimization_bias = load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    let Some(content) = prepare_selected_video_memory_for_storage(content, optimization_bias)
    else {
        return Ok(());
    };
    let Some(storyboard_numeric_id) = extract_key_value(&content, "storyboardIds")
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let scope_signature = storyboard_scope_signature(
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
        SELECTED_VIDEO_MEMORY_NAME,
        &content,
    );
    if !summary_memory_allowed(
        pool,
        user_id,
        project_numeric_id,
        SELECTED_VIDEO_MEMORY_NAME,
        &content,
        VIDEO_SCOPED_MEMORY_TIER,
        &scope_signature,
    )
    .await?
    {
        delete_selected_video_memory_for_scope(
            pool,
            user_id,
            project_numeric_id,
            script_numeric_id,
            &content,
        )
        .await?;
        return Ok(());
    }
    let latest_same_scope = load_latest_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &content,
    )
    .await?;

    if latest_same_scope.as_deref() == Some(content.as_str()) {
        return Ok(());
    }
    if latest_same_scope.as_deref().is_some_and(|existing| {
        selected_video_memory_update_would_reduce_quality_with_bias(
            existing,
            &content,
            optimization_bias,
        )
    }) {
        return Ok(());
    }

    delete_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &content,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000, $6, $7)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(&content)
    .bind(VIDEO_SCOPED_MEMORY_TIER)
    .bind(&scope_signature)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn load_latest_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<Option<String>, ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(None);
    };

    let rows = sqlx::query_scalar::<_, String>(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .find(|existing| selected_video_memory_scope(existing).as_ref() == Some(&scope)))
}

async fn delete_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(());
    };

    let rows = sqlx::query_as::<_, (i64, String)>(
        r#"
        SELECT id, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let duplicate_ids = rows
        .into_iter()
        .filter_map(|(id, existing)| {
            (selected_video_memory_scope(&existing).as_ref() == Some(&scope)).then_some(id)
        })
        .collect::<Vec<_>>();
    if duplicate_ids.is_empty() {
        return Ok(());
    }

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id = ANY($1)
        "#,
    )
    .bind(&duplicate_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn refresh_script_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(), ApiError> {
    let optimization_bias = load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    let selected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rejected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_script_video_style_memory_with_bias(
        &selected_rows,
        &rejected_rows,
        optimization_bias,
    );
    let observation_summary = build_script_video_observation_memory_with_bias(
        &rejected_rows,
        selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
    );
    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME,
        build_script_role_video_style_memories(&selected_rows),
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME,
        build_video_generation_brief_memory(
            summarized.as_deref(),
            observation_summary.as_deref(),
            optimization_bias,
        )
        .as_deref(),
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME,
        observation_summary.as_deref(),
        SCRIPT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME,
        build_script_role_video_observation_memories_with_bias(
            &rejected_rows,
            selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
        ),
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await
}
