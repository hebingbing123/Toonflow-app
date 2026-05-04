use super::*;

pub(super) async fn replace_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .bind(content)
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
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(super) async fn replace_summary_memories(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    contents: Vec<String>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for content in contents.into_iter().take(keep_rows as usize) {
        sqlx::query(
            r#"
            INSERT INTO app_agent_memory (
              owner_user_id, numeric_project_id, episodes_id, agent_type,
              memory_type, role, name, content, summarized, create_time_ms
            )
            VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(script_numeric_id)
        .bind(name)
        .bind(content)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}

pub(super) async fn replace_project_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(content)
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
            AND episodes_id IS NULL
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $3
          ORDER BY create_time_ms DESC
          OFFSET $4
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(super) async fn replace_project_summary_memories(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    contents: Vec<String>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for content in contents.into_iter().take(keep_rows as usize) {
        sqlx::query(
            r#"
            INSERT INTO app_agent_memory (
              owner_user_id, numeric_project_id, episodes_id, agent_type,
              memory_type, role, name, content, summarized, create_time_ms
            )
            VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(name)
        .bind(content)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}
