//! **F1** — 多平台差异化文案建议（LLM 可用时调用；否则降级模板填充）。
//! **J.1** — Input hash cache to reduce redundant LLM calls.

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

    // Compute input hash for cache lookup
    let input_hash = compute_input_hash(draft, targets, style_hint);

    // Check cache first
    if let Some(cached) = lookup_cache(pool, &input_hash).await? {
        // Update cache hit statistics
        update_cache_hit(pool, cached.id).await?;
        return Ok((cached.platform_copy_fragment, "cache"));
    }

    let Some(cfg) = state.llm.as_ref() else {
        let fragment = fallback_platform_copy_fragment(draft, targets);
        // Store fallback result in cache
        store_cache(pool, &input_hash, &fragment, "fallback").await?;
        return Ok((fragment, "fallback"));
    };

    let mut spec_lines = Vec::new();
    for t in targets {
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
    let merged = merge_llm_with_fallback(draft, targets, parsed);

    // Store LLM result in cache
    store_cache(pool, &input_hash, &merged, "llm").await?;

    Ok((merged, "llm"))
}
