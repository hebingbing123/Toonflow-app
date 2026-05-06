use super::*;
use crate::settings::agent_memory::{
    load_project_automation_memory_policy, policy_allows_automated_memory,
};
use serde_json::{json, Value};

pub(super) const VIDEO_SUMMARY_MEMORY_TIER: &str = "stage_summary";
pub(super) const VIDEO_SCOPED_MEMORY_TIER: &str = "delta_memory";

pub(super) fn script_summary_scope_signature(
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    content: &str,
) -> Value {
    let mut scope = json!({
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "memoryName": name,
    });
    enrich_scope_signature_with_content(&mut scope, content);
    scope
}

pub(super) fn project_summary_scope_signature(
    project_numeric_id: i32,
    name: &str,
    content: &str,
) -> Value {
    let mut scope = json!({
        "projectId": project_numeric_id,
        "memoryName": name,
    });
    enrich_scope_signature_with_content(&mut scope, content);
    scope
}

pub(super) fn storyboard_scope_signature(
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    name: &str,
    content: &str,
) -> Value {
    let mut scope = json!({
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "storyboardIds": [storyboard_numeric_id],
        "memoryName": name,
    });
    enrich_scope_signature_with_content(&mut scope, content);
    scope
}

fn enrich_scope_signature_with_content(scope: &mut Value, content: &str) {
    let Some(object) = scope.as_object_mut() else {
        return;
    };
    if let Some(subject) = extract_key_value(content, "subject").filter(|value| !value.is_empty()) {
        object.insert("subject".into(), Value::String(subject));
    }
    if let Some(subject_aliases) = extract_key_value(content, "subjectAliases")
        .filter(|value| !value.is_empty())
        .map(|value| {
            value
                .split('/')
                .map(normalize_prompt_text)
                .filter(|item| !item.is_empty())
                .collect::<Vec<_>>()
        })
        .filter(|value| !value.is_empty())
    {
        object.insert("subjectAliases".into(), json!(subject_aliases));
    }
}

pub(super) async fn summary_memory_allowed(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    content: &str,
    memory_tier: &str,
    scope_signature: &Value,
) -> Result<bool, ApiError> {
    let policy =
        load_project_automation_memory_policy(pool, user_id, project_numeric_id, "productionAgent")
            .await?;
    Ok(policy_allows_automated_memory(
        &policy,
        memory_tier,
        Some(name),
        content,
        Some(scope_signature),
    ))
}

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
    let scope_signature =
        script_summary_scope_signature(project_numeric_id, script_numeric_id, name, content);
    if !summary_memory_allowed(
        pool,
        user_id,
        project_numeric_id,
        name,
        content,
        VIDEO_SUMMARY_MEMORY_TIER,
        &scope_signature,
    )
    .await?
    {
        return Ok(());
    }

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
    .bind(name)
    .bind(content)
    .bind(VIDEO_SUMMARY_MEMORY_TIER)
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
        let scope_signature =
            script_summary_scope_signature(project_numeric_id, script_numeric_id, name, &content);
        if !summary_memory_allowed(
            pool,
            user_id,
            project_numeric_id,
            name,
            &content,
            VIDEO_SUMMARY_MEMORY_TIER,
            &scope_signature,
        )
        .await?
        {
            continue;
        }
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
        .bind(name)
        .bind(&content)
        .bind(VIDEO_SUMMARY_MEMORY_TIER)
        .bind(&scope_signature)
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
    let scope_signature = project_summary_scope_signature(project_numeric_id, name, content);
    if !summary_memory_allowed(
        pool,
        user_id,
        project_numeric_id,
        name,
        content,
        VIDEO_SUMMARY_MEMORY_TIER,
        &scope_signature,
    )
    .await?
    {
        return Ok(());
    }

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000, $5, $6)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(content)
    .bind(VIDEO_SUMMARY_MEMORY_TIER)
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
        let scope_signature = project_summary_scope_signature(project_numeric_id, name, &content);
        if !summary_memory_allowed(
            pool,
            user_id,
            project_numeric_id,
            name,
            &content,
            VIDEO_SUMMARY_MEMORY_TIER,
            &scope_signature,
        )
        .await?
        {
            continue;
        }
        sqlx::query(
            r#"
            INSERT INTO app_agent_memory (
              owner_user_id, numeric_project_id, episodes_id, agent_type,
              memory_type, role, name, content, summarized, create_time_ms,
              memory_tier, scope_signature
            )
            VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000, $5, $6)
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(name)
        .bind(&content)
        .bind(VIDEO_SUMMARY_MEMORY_TIER)
        .bind(&scope_signature)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}
