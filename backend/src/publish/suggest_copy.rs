//! **F1** — 多平台差异化文案建议（LLM 可用时调用；否则降级模板填充）。
//! **J.1** — Input hash cache to reduce redundant LLM calls.
//! **J.2** — Incremental copy generation for changed platforms only.

use serde_json::{json, Value};
use sqlx::PgPool;

use crate::error::ApiError;
use crate::llm::chat_completion_with_usage;
use crate::publish::platform_registry::spec_for_platform;
use crate::publish::types::PublishTargetRow;
use crate::state::AppState;

use super::copy_cache::{compute_input_hash, lookup_cache, store_cache, update_cache_hit};
use super::types::PublishDraftRow;

fn truncate_chars(s: &str, max_chars: usize) -> String {
    if s.chars().count() <= max_chars {
        s.to_string()
    } else {
        s.chars().take(max_chars).collect()
    }
}

pub(crate) fn fallback_platform_copy_fragment(
    draft: &PublishDraftRow,
    targets: &[PublishTargetRow],
) -> Value {
    let mut m = serde_json::Map::new();
    for t in targets {
        let spec = spec_for_platform(&t.platform_id);
        let tmax = spec.map(|s| s.title_max_chars as usize).unwrap_or(80);
        let dmax = spec
            .map(|s| s.description_max_chars as usize)
            .unwrap_or(500);
        let tag_take = spec.map(|s| s.tags_max as usize).unwrap_or(5);

        let title = truncate_chars(draft.title.trim(), tmax);
        let description = truncate_chars(draft.description.trim(), dmax);
        let tags: Vec<String> = draft.tags.iter().take(tag_take).cloned().collect();
        m.insert(
            t.platform_id.clone(),
            json!({
                "title": title,
                "description": description,
                "tags": tags,
            }),
        );
    }
    Value::Object(m)
}

fn extract_json_value(raw: &str) -> Result<Value, ApiError> {
    let t = raw.trim();
    let start = t
        .find('{')
        .ok_or_else(|| ApiError::BadRequest("model did not return JSON object".into()))?;
    let end = t
        .rfind('}')
        .ok_or_else(|| ApiError::BadRequest("truncated JSON object".into()))?;
    serde_json::from_str::<Value>(&t[start..=end])
        .map_err(|e| ApiError::BadRequest(format!("invalid JSON: {e}")))
}

fn merge_llm_with_fallback(
    draft: &PublishDraftRow,
    targets: &[PublishTargetRow],
    llm_fragment: Value,
) -> Value {
    let fb = fallback_platform_copy_fragment(draft, targets);
    let mut out = fb.as_object().cloned().unwrap_or_default();
    if let Value::Object(llm_obj) = llm_fragment {
        for t in targets {
            if let Some(v) = llm_obj.get(&t.platform_id) {
                out.insert(t.platform_id.clone(), v.clone());
            }
        }
    }
    Value::Object(out)
}

/// Compute platform diff: which platforms are added, removed, or unchanged.
fn compute_platform_diff(
    existing_copy: &Value,
    targets: &[PublishTargetRow],
) -> (Vec<String>, Vec<String>, Vec<String>) {
    let existing_platforms: std::collections::HashSet<String> = existing_copy
        .as_object()
        .map(|obj| obj.keys().cloned().collect())
        .unwrap_or_default();

    let target_platforms: std::collections::HashSet<String> =
        targets.iter().map(|t| t.platform_id.clone()).collect();

    let added: Vec<String> = target_platforms
        .difference(&existing_platforms)
        .cloned()
        .collect();
    let removed: Vec<String> = existing_platforms
        .difference(&target_platforms)
        .cloned()
        .collect();
    let unchanged: Vec<String> = target_platforms
        .intersection(&existing_platforms)
        .cloned()
        .collect();

    (added, removed, unchanged)
}

pub(crate) async fn suggest_platform_copy_fragment(
    state: &AppState,
    pool: &PgPool,
    draft: &PublishDraftRow,
    targets: &[PublishTargetRow],
    style_hint: Option<&str>,
) -> Result<(Value, &'static str), ApiError> {
    if targets.is_empty() {
        return Err(ApiError::BadRequest(
            "no publish targets — add targets before generating copy".into(),
        ));
    }

    // J.2: Compute platform diff to identify which platforms need generation
    let (added, _removed, unchanged) = compute_platform_diff(&draft.platform_copy.0, targets);

    // If no platforms added and we have existing copy for all current platforms,
    // return existing copy (incremental mode)
    if added.is_empty() && !unchanged.is_empty() {
        // Build result from existing copy, excluding removed platforms
        let mut result = serde_json::Map::new();
        if let Some(existing_obj) = draft.platform_copy.0.as_object() {
            for platform_id in &unchanged {
                if let Some(copy) = existing_obj.get(platform_id) {
                    result.insert(platform_id.clone(), copy.clone());
                }
            }
        }
        return Ok((Value::Object(result), "incremental"));
    }

    // Filter targets to only include added platforms for generation
    let targets_to_generate: Vec<PublishTargetRow> = if !added.is_empty() {
        targets
            .iter()
            .filter(|t| added.contains(&t.platform_id))
            .cloned()
            .collect()
    } else {
        // First generation: all platforms are "added"
        targets.to_vec()
    };

    // Compute input hash for cache lookup (only for platforms being generated)
    let input_hash = compute_input_hash(draft, &targets_to_generate, style_hint);

    // Check cache first
    if let Some(cached) = lookup_cache(pool, &input_hash).await? {
        // Update cache hit statistics
        update_cache_hit(pool, cached.id).await?;

        // Merge cached result with existing unchanged platforms
        let mut result = serde_json::Map::new();

        // Add unchanged platforms from existing copy
        if let Some(existing_obj) = draft.platform_copy.0.as_object() {
            for platform_id in &unchanged {
                if let Some(copy) = existing_obj.get(platform_id) {
                    result.insert(platform_id.clone(), copy.clone());
                }
            }
        }

        // Add cached platforms
        if let Some(cached_obj) = cached.platform_copy_fragment.as_object() {
            for (k, v) in cached_obj {
                result.insert(k.clone(), v.clone());
            }
        }

        return Ok((Value::Object(result), "cache"));
    }

    let Some(cfg) = state.llm.as_ref() else {
        let fragment = fallback_platform_copy_fragment(draft, &targets_to_generate);
        // Store fallback result in cache
        store_cache(pool, &input_hash, &fragment, "fallback").await?;

        // Merge with existing unchanged platforms
        let mut result = serde_json::Map::new();
        if let Some(existing_obj) = draft.platform_copy.0.as_object() {
            for platform_id in &unchanged {
                if let Some(copy) = existing_obj.get(platform_id) {
                    result.insert(platform_id.clone(), copy.clone());
                }
            }
        }
        if let Some(fragment_obj) = fragment.as_object() {
            for (k, v) in fragment_obj {
                result.insert(k.clone(), v.clone());
            }
        }

        return Ok((Value::Object(result), "fallback"));
    };

    let mut spec_lines = Vec::new();
    for t in &targets_to_generate {
        if let Some(s) = spec_for_platform(&t.platform_id) {
            spec_lines.push(format!(
                "- {} (id `{}`): title≤{} chars, description≤{} chars, tags≤{}, cover_required={}",
                s.label_zh,
                s.platform_id,
                s.title_max_chars,
                s.description_max_chars,
                s.tags_max,
                s.requires_cover
            ));
        }
    }

    let hint = style_hint.unwrap_or("neutral promotional tone suitable for short drama clips");
    let user = format!(
        r#"Produce ONLY a compact JSON object whose keys are platform_id strings exactly as listed below.
Each value MUST be an object with optional keys "title","description","tags" (tags is array of strings).
Do not wrap in markdown fences.

Platforms:
{}

Draft baseline title (may shorten): "{}"
Draft baseline description (may shorten): "{}"
Baseline tags (may reuse subset): {:?}

Style hint: {}

Respond with JSON only."#,
        spec_lines.join("\n"),
        draft.title.trim(),
        draft.description.trim(),
        draft.tags,
        hint,
    );

    let messages = vec![
        json!({"role": "system", "content": "You generate localized publish captions per platform under strict JSON."}),
        json!({"role": "user", "content": user}),
    ];

    let res = chat_completion_with_usage(cfg, &state.http_client, messages)
        .await
        .map_err(|e| ApiError::BadRequest(format!("llm error: {e}")))?;

    let parsed = extract_json_value(&res.content)?;
    let merged = merge_llm_with_fallback(draft, &targets_to_generate, parsed);

    // Store LLM result in cache (only for generated platforms)
    store_cache(pool, &input_hash, &merged, "llm").await?;

    // Merge with existing unchanged platforms
    let mut result = serde_json::Map::new();
    if let Some(existing_obj) = draft.platform_copy.0.as_object() {
        for platform_id in &unchanged {
            if let Some(copy) = existing_obj.get(platform_id) {
                result.insert(platform_id.clone(), copy.clone());
            }
        }
    }
    if let Some(merged_obj) = merged.as_object() {
        for (k, v) in merged_obj {
            result.insert(k.clone(), v.clone());
        }
    }

    Ok((Value::Object(result), "llm"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn create_test_target(platform_id: &str) -> PublishTargetRow {
        PublishTargetRow {
            id: uuid::Uuid::new_v4(),
            draft_id: uuid::Uuid::new_v4(),
            platform_id: platform_id.to_string(),
            automation_mode: "manual".to_string(),
            serial_order: 0,
            extra: sqlx::types::Json(json!({})),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        }
    }

    #[test]
    fn test_compute_platform_diff_all_new() {
        let existing_copy = json!({});
        let targets = vec![
            create_test_target("douyin"),
            create_test_target("xiaohongshu"),
        ];

        let (added, removed, unchanged) = compute_platform_diff(&existing_copy, &targets);

        assert_eq!(added.len(), 2);
        assert!(added.contains(&"douyin".to_string()));
        assert!(added.contains(&"xiaohongshu".to_string()));
        assert_eq!(removed.len(), 0);
        assert_eq!(unchanged.len(), 0);
    }

    #[test]
    fn test_compute_platform_diff_all_unchanged() {
        let existing_copy = json!({
            "douyin": {"title": "Test", "description": "Test"},
            "xiaohongshu": {"title": "Test", "description": "Test"}
        });
        let targets = vec![
            create_test_target("douyin"),
            create_test_target("xiaohongshu"),
        ];

        let (added, removed, unchanged) = compute_platform_diff(&existing_copy, &targets);

        assert_eq!(added.len(), 0);
        assert_eq!(removed.len(), 0);
        assert_eq!(unchanged.len(), 2);
        assert!(unchanged.contains(&"douyin".to_string()));
        assert!(unchanged.contains(&"xiaohongshu".to_string()));
    }

    #[test]
    fn test_compute_platform_diff_mixed() {
        let existing_copy = json!({
            "douyin": {"title": "Test", "description": "Test"},
            "bilibili": {"title": "Test", "description": "Test"}
        });
        let targets = vec![
            create_test_target("douyin"),
            create_test_target("xiaohongshu"),
        ];

        let (added, removed, unchanged) = compute_platform_diff(&existing_copy, &targets);

        assert_eq!(added.len(), 1);
        assert!(added.contains(&"xiaohongshu".to_string()));
        assert_eq!(removed.len(), 1);
        assert!(removed.contains(&"bilibili".to_string()));
        assert_eq!(unchanged.len(), 1);
        assert!(unchanged.contains(&"douyin".to_string()));
    }

    #[test]
    fn test_compute_platform_diff_all_removed() {
        let existing_copy = json!({
            "douyin": {"title": "Test", "description": "Test"},
            "xiaohongshu": {"title": "Test", "description": "Test"}
        });
        let targets = vec![create_test_target("bilibili")];

        let (added, removed, unchanged) = compute_platform_diff(&existing_copy, &targets);

        assert_eq!(added.len(), 1);
        assert!(added.contains(&"bilibili".to_string()));
        assert_eq!(removed.len(), 2);
        assert!(removed.contains(&"douyin".to_string()));
        assert!(removed.contains(&"xiaohongshu".to_string()));
        assert_eq!(unchanged.len(), 0);
    }

    #[test]
    fn test_fallback_platform_copy_fragment() {
        let draft = PublishDraftRow {
            id: uuid::Uuid::new_v4(),
            project_id: uuid::Uuid::new_v4(),
            profile_id: None,
            script_id: None,
            video_asset_key: None,
            cover_asset_key: None,
            title: "Test Title".to_string(),
            description: "Test Description".to_string(),
            tags: vec!["tag1".to_string(), "tag2".to_string()],
            platform_copy: sqlx::types::Json(json!({})),
            scheduled_at: None,
            draft_status: "draft".to_string(),
            metadata: sqlx::types::Json(json!({})),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };

        let targets = vec![
            create_test_target("douyin"),
            create_test_target("xiaohongshu"),
        ];

        let result = fallback_platform_copy_fragment(&draft, &targets);

        assert!(result.is_object());
        let obj = result.as_object().unwrap();
        assert_eq!(obj.len(), 2);
        assert!(obj.contains_key("douyin"));
        assert!(obj.contains_key("xiaohongshu"));

        // Check douyin copy
        let douyin_copy = obj.get("douyin").unwrap();
        assert_eq!(douyin_copy["title"], "Test Title");
        assert_eq!(douyin_copy["description"], "Test Description");
        assert_eq!(douyin_copy["tags"].as_array().unwrap().len(), 2);
    }
}
