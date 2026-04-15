use chrono::Utc;
use sqlx::PgPool;
use uuid::Uuid;

use crate::state::AppState;

/// Check whether summarization is needed and generate summary via LLM.
pub(super) async fn maybe_summarize_messages(
    pool: &PgPool,
    state: &AppState,
    uid: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    messages_per_summary: i64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .fetch_one(pool)
    .await?;

    if count < messages_per_summary {
        return Ok(());
    }

    let messages: Vec<(String, String)> = sqlx::query_as(
        r#"
        SELECT role, content FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
        ORDER BY create_time_ms ASC
        LIMIT $5
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(messages_per_summary)
    .fetch_all(pool)
    .await?;

    if messages.is_empty() {
        return Ok(());
    }

    let conversation = messages
        .iter()
        .map(|(role, content)| format!("{role}: {content}"))
        .collect::<Vec<_>>()
        .join("\n");

    let summary_text = if let Some(ref cfg) = state.llm {
        let client = reqwest::Client::new();
        let prompt = format!(
            "请总结以下对话的关键要点，用中文输出，不超过100字：\n\n{}",
            conversation
        );
        let llm_messages = vec![
            serde_json::json!({"role": "system", "content": "你是一个对话摘要助手。"}),
            serde_json::json!({"role": "user", "content": prompt}),
        ];
        match crate::llm::chat_completion_assistant_text(cfg, &client, llm_messages).await {
            Ok(text) => text,
            Err(e) => {
                tracing::warn!(error = %e, "LLM summarization failed, using fallback");
                format!("[摘要] {}条消息待总结", messages.len())
            }
        }
    } else {
        format!("[摘要] {}条消息待总结", messages.len())
    };

    let summary_max_length = state.memory_config.read().await.summary_max_length as usize;
    let summary_text = if summary_text.len() > summary_max_length {
        format!(
            "{}...",
            &summary_text[..summary_max_length.min(summary_text.len()) - 3]
        )
    } else {
        summary_text
    };

    let now_ms = Utc::now().timestamp_millis();

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'summary', 'assistant', 'summary', $5, 1, $6)
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(&summary_text)
    .bind(now_ms)
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        UPDATE app_agent_memory
        SET summarized = 1
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'message'
          AND summarized = 0
          AND id IN (
            SELECT id FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND episodes_id IS NOT DISTINCT FROM $3
              AND agent_type = $4
              AND memory_type = 'message'
              AND summarized = 0
            ORDER BY create_time_ms ASC
            LIMIT $5
          )
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(messages_per_summary)
    .execute(pool)
    .await?;

    tracing::info!(
        user_id = %uid,
        project_id = %project_id,
        agent_type = %agent_type,
        "auto-generated memory summary"
    );

    Ok(())
}
