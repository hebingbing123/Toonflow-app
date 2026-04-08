use futures_util::stream::{self, StreamExt};
use sqlx::PgPool;

use super::NovelEventExtractionRow;
use crate::error::ApiError;
use crate::llm::{chat_completion_assistant_text, LlmConfig};

const MAX_GENERATE_EVENTS_CONCURRENCY: usize = 20;
const DEFAULT_EVENT_EXTRACTION_PROMPT: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/data/prompt_defaults/eventExtraction.txt"
));

pub(super) async fn resolve_event_extraction_prompt(
    pool: &PgPool,
    uid: uuid::Uuid,
) -> Result<String, ApiError> {
    let row: Option<String> = sqlx::query_scalar(
        r#"
        SELECT body
        FROM app_user_prompt
        WHERE owner_user_id = $1 AND legacy_id = 1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| DEFAULT_EVENT_EXTRACTION_PROMPT.to_string()))
}

async fn mark_novel_event_extraction_result(
    pool: &PgPool,
    novel_id: uuid::Uuid,
    event: Option<&str>,
    event_state: i32,
    error_reason: Option<&str>,
) {
    let _ = sqlx::query(
        r#"
        UPDATE app_novel
        SET event = $1, event_state = $2, error_reason = $3, updated_at = NOW()
        WHERE id = $4
        "#,
    )
    .bind(event)
    .bind(event_state)
    .bind(error_reason)
    .bind(novel_id)
    .execute(pool)
    .await;
}

pub(super) async fn run_novel_event_extraction_task(
    pool: PgPool,
    llm: Option<LlmConfig>,
    http_client: reqwest::Client,
    prompt: String,
    novels: Vec<NovelEventExtractionRow>,
    concurrency: usize,
) {
    let Some(cfg) = llm else {
        for novel in novels {
            mark_novel_event_extraction_result(
                &pool,
                novel.id,
                None,
                -1,
                Some("llm_not_configured"),
            )
            .await;
        }
        return;
    };

    let concurrency = concurrency.clamp(1, MAX_GENERATE_EVENTS_CONCURRENCY);

    stream::iter(novels)
        .for_each_concurrent(concurrency, |novel| {
            let pool = pool.clone();
            let http_client = http_client.clone();
            let cfg = cfg.clone();
            let prompt = prompt.clone();
            async move {
                let user_content = format!(
                    "请根据以下小说章节数：{}小说章节券：{}小说章节名称：{}、小说章节内容生成事件摘要：\n{}",
                    novel.chapter_index,
                    novel.reel.as_deref().unwrap_or_default(),
                    novel.chapter,
                    novel.chapter_data
                );
                let messages = vec![
                    serde_json::json!({"role":"system","content": prompt}),
                    serde_json::json!({"role":"user","content": user_content}),
                ];
                match chat_completion_assistant_text(&cfg, &http_client, messages).await {
                    Ok(text) => {
                        mark_novel_event_extraction_result(&pool, novel.id, Some(&text), 1, None)
                            .await;
                    }
                    Err(err) => {
                        mark_novel_event_extraction_result(
                            &pool,
                            novel.id,
                            None,
                            -1,
                            Some(&err),
                        )
                        .await;
                    }
                }
            }
        })
        .await;
}
