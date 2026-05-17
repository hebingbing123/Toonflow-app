//! Collect per-storyboard candidate video URLs (metadata + generation jobs).

use std::collections::HashMap;

use serde_json::Value;
use sqlx::PgPool;

use crate::error::ApiError;
use crate::jobs::JOB_KIND_VIDEO_GENERATE;

const VIDEO_SUFFIXES: [&str; 6] = [".mp4", ".mov", ".webm", ".m4v", ".mkv", ".avi"];

#[inline]
fn looks_like_video_url(raw: &str) -> bool {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return false;
    }
    let path = trimmed
        .split('?')
        .next()
        .unwrap_or(trimmed)
        .split('#')
        .next()
        .unwrap_or(trimmed)
        .to_ascii_lowercase();
    VIDEO_SUFFIXES.iter().any(|ext| path.ends_with(ext))
}

pub fn parse_candidate_urls_from_metadata(value: Option<&Value>) -> Vec<String> {
    let Some(value) = value else {
        return Vec::new();
    };
    let arr = value
        .get("candidateVideos")
        .or_else(|| value.get("candidate_videos"))
        .and_then(Value::as_array);
    let Some(arr) = arr else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for item in arr {
        let url = item.as_str().map(str::to_string).or_else(|| {
            item.get("url")
                .or_else(|| item.get("videoUrl"))
                .and_then(Value::as_str)
                .map(str::to_string)
        });
        if let Some(url) = url {
            if looks_like_video_url(&url) {
                push_unique(&mut out, url);
            }
        }
    }
    out
}

fn push_unique(out: &mut Vec<String>, url: String) {
    let trimmed = url.trim().to_string();
    if trimmed.is_empty() {
        return;
    }
    if out.iter().any(|u| u == &trimmed) {
        return;
    }
    out.push(trimmed);
}

pub fn merge_candidate_video_urls(
    metadata_urls: Vec<String>,
    job_urls: Vec<String>,
    current_video: Option<&str>,
) -> Vec<String> {
    let mut out = metadata_urls;
    for url in job_urls {
        push_unique(&mut out, url);
    }
    if let Some(current) = current_video.map(str::trim).filter(|s| !s.is_empty()) {
        if looks_like_video_url(current) {
            push_unique(&mut out, current.to_string());
        }
    }
    out
}

/// Batch-load completed video job URLs keyed by storyboard **`numeric_id`**.
pub async fn fetch_storyboard_candidate_job_video_urls(
    pool: &PgPool,
    project_numeric_id: i32,
    storyboard_numeric_ids: &[i32],
) -> Result<HashMap<i32, Vec<String>>, ApiError> {
    if storyboard_numeric_ids.is_empty() {
        return Ok(HashMap::new());
    }
    let rows: Vec<(i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT
          (j.payload->>'storyboard_numeric_id')::int4 AS storyboard_numeric_id,
          COALESCE(
            NULLIF(j.result->>'video_url', ''),
            NULLIF(j.result->>'videoUrl', ''),
            NULLIF(j.result->>'url', '')
          ) AS video_url
        FROM app_generation_job j
        WHERE j.kind = $1
          AND j.status = 'completed'
          AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
          AND (j.payload->>'project_numeric_id')::int = $2
          AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
          AND (j.payload->>'storyboard_numeric_id')::int4 = ANY($3::int4[])
          AND COALESCE(
            NULLIF(j.result->>'video_url', ''),
            NULLIF(j.result->>'videoUrl', ''),
            NULLIF(j.result->>'url', '')
          ) IS NOT NULL
        ORDER BY j.updated_at DESC
        "#,
    )
    .bind(JOB_KIND_VIDEO_GENERATE)
    .bind(project_numeric_id)
    .bind(storyboard_numeric_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut map: HashMap<i32, Vec<String>> = HashMap::new();
    for (sid, url) in rows {
        let Some(url) = url.filter(|u| looks_like_video_url(u)) else {
            continue;
        };
        map.entry(sid).or_default().push(url);
    }
    Ok(map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_metadata_candidate_array() {
        let meta = json!({
            "candidateVideos": ["https://a/x.mp4", {"url": "https://b/y.mov"}]
        });
        let urls = parse_candidate_urls_from_metadata(Some(&meta));
        assert_eq!(urls.len(), 2);
    }

    #[test]
    fn merge_dedupes_and_includes_current() {
        let merged = merge_candidate_video_urls(
            vec!["https://a/1.mp4".into()],
            vec!["https://a/2.mp4".into(), "https://a/1.mp4".into()],
            Some("https://a/3.mp4"),
        );
        assert_eq!(merged.len(), 3);
    }
}
