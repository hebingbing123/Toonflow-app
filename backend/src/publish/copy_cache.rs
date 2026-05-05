//! **J.1** — Input hash cache for publish copy generation.
//!
//! Reduces redundant LLM calls by caching results based on input hash.

use chrono::{DateTime, Utc};
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

use super::types::{PublishDraftRow, PublishTargetRow};

#[derive(Debug, FromRow)]
#[allow(dead_code)]
pub(crate) struct PublishCopyCacheRow {
    pub(crate) id: Uuid,
    pub(crate) input_hash: String,
    pub(crate) platform_copy_fragment: Value,
    pub(crate) source: String,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) last_used_at: DateTime<Utc>,
    pub(crate) use_count: i32,
}

/// Compute a stable hash of the input parameters for cache lookup.
///
/// Hash includes:
/// - Draft title, description, tags
/// - Target platform IDs (sorted for stability)
/// - Style hint (if provided)
pub(crate) fn compute_input_hash(
    draft: &PublishDraftRow,
    targets: &[PublishTargetRow],
    style_hint: Option<&str>,
) -> String {
    let mut hasher = Sha256::new();

    // Hash draft content
    hasher.update(draft.title.as_bytes());
    hasher.update(b"\x00"); // separator
    hasher.update(draft.description.as_bytes());
    hasher.update(b"\x00");

    // Hash tags (sorted for stability)
    let mut sorted_tags = draft.tags.clone();
    sorted_tags.sort();
    for tag in &sorted_tags {
        hasher.update(tag.as_bytes());
        hasher.update(b"\x00");
    }

    // Hash target platform IDs (sorted for stability)
    let mut platform_ids: Vec<_> = targets.iter().map(|t| &t.platform_id).collect();
    platform_ids.sort();
    for pid in platform_ids {
        hasher.update(pid.as_bytes());
        hasher.update(b"\x00");
    }

    // Hash style hint if provided
    if let Some(hint) = style_hint {
        hasher.update(hint.as_bytes());
    }

    format!("{:x}", hasher.finalize())
}

/// Look up cached publish copy by input hash.
pub(crate) async fn lookup_cache(
    pool: &PgPool,
    input_hash: &str,
) -> Result<Option<PublishCopyCacheRow>, ApiError> {
    let row = sqlx::query_as::<_, PublishCopyCacheRow>(
        r#"
        SELECT id, input_hash, platform_copy_fragment, source, created_at, last_used_at, use_count
        FROM app_publish_copy_cache
        WHERE input_hash = $1
        "#,
    )
    .bind(input_hash)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row)
}

/// Update cache hit statistics (last_used_at and use_count).
pub(crate) async fn update_cache_hit(pool: &PgPool, cache_id: Uuid) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_publish_copy_cache
        SET last_used_at = now(), use_count = use_count + 1
        WHERE id = $1
        "#,
    )
    .bind(cache_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Store a new cache entry.
pub(crate) async fn store_cache(
    pool: &PgPool,
    input_hash: &str,
    platform_copy_fragment: &Value,
    source: &str,
) -> Result<Uuid, ApiError> {
    let row = sqlx::query_as::<_, (Uuid,)>(
        r#"
        INSERT INTO app_publish_copy_cache (input_hash, platform_copy_fragment, source)
        VALUES ($1, $2, $3)
        ON CONFLICT (input_hash) DO UPDATE
        SET platform_copy_fragment = EXCLUDED.platform_copy_fragment,
            source = EXCLUDED.source,
            last_used_at = now(),
            use_count = app_publish_copy_cache.use_count + 1
        RETURNING id
        "#,
    )
    .bind(input_hash)
    .bind(platform_copy_fragment)
    .bind(source)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn create_test_draft(title: &str, tags: Vec<String>) -> PublishDraftRow {
        PublishDraftRow {
            id: Uuid::new_v4(),
            project_id: Uuid::new_v4(),
            profile_id: None,
            script_id: None,
            video_asset_key: None,
            cover_asset_key: None,
            title: title.to_string(),
            description: "Test Description".to_string(),
            tags,
            platform_copy: sqlx::types::Json(json!({})),
            scheduled_at: None,
            draft_status: "draft".to_string(),
            metadata: sqlx::types::Json(json!({})),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn test_compute_input_hash_stability() {
        let draft1 = create_test_draft("Test Title", vec!["tag1".to_string(), "tag2".to_string()]);
        let draft2 = create_test_draft("Test Title", vec!["tag2".to_string(), "tag1".to_string()]);

        let targets = vec![
            PublishTargetRow {
                id: Uuid::new_v4(),
                draft_id: Uuid::new_v4(),
                platform_id: "douyin".to_string(),
                automation_mode: "manual".to_string(),
                serial_order: 0,
                extra: sqlx::types::Json(json!({})),
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
            PublishTargetRow {
                id: Uuid::new_v4(),
                draft_id: Uuid::new_v4(),
                platform_id: "xiaohongshu".to_string(),
                automation_mode: "manual".to_string(),
                serial_order: 1,
                extra: sqlx::types::Json(json!({})),
                created_at: Utc::now(),
                updated_at: Utc::now(),
            },
        ];

        let hash1 = compute_input_hash(&draft1, &targets, Some("neutral"));
        let hash2 = compute_input_hash(&draft2, &targets, Some("neutral"));

        // Hashes should be identical despite different tag order
        assert_eq!(hash1, hash2);
    }

    #[test]
    fn test_compute_input_hash_different_content() {
        let draft1 = create_test_draft("Test Title 1", vec!["tag1".to_string()]);
        let draft2 = create_test_draft("Test Title 2", vec!["tag1".to_string()]);

        let targets = vec![PublishTargetRow {
            id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            platform_id: "douyin".to_string(),
            automation_mode: "manual".to_string(),
            serial_order: 0,
            extra: sqlx::types::Json(json!({})),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }];

        let hash1 = compute_input_hash(&draft1, &targets, None);
        let hash2 = compute_input_hash(&draft2, &targets, None);

        // Hashes should be different
        assert_ne!(hash1, hash2);
    }
}
