//! Server-side novel URL preview fetch (HTML → title + body text). Preview only; does not write `app_novel` rows.

use std::net::IpAddr;

use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use regex::Regex;
use reqwest::header::USER_AGENT;
use scraper::{Html, Selector};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::dto::{NovelCrawlPreviewBody, NovelCrawlPreviewResponse};

const MAX_HTML_BYTES: u64 = 2 * 1024 * 1024;

fn assert_fetchable_url(url: &url::Url) -> Result<(), ApiError> {
    match url.scheme() {
        "http" | "https" => {}
        _ => return Err(ApiError::BadRequest("url must use http or https".into())),
    }
    let host = url
        .host_str()
        .ok_or_else(|| ApiError::BadRequest("url missing host".into()))?;
    if host.eq_ignore_ascii_case("localhost")
        || host == "127.0.0.1"
        || host == "::1"
        || host.ends_with(".localhost")
    {
        return Err(ApiError::BadRequest(
            "localhost and loopback URLs are not allowed".into(),
        ));
    }
    if let Ok(ip) = host.parse::<IpAddr>() {
        match ip {
            IpAddr::V4(v4) => {
                if v4.is_private() || v4.is_loopback() || v4.is_link_local() {
                    return Err(ApiError::BadRequest(
                        "private or loopback IP URLs are not allowed".into(),
                    ));
                }
            }
            IpAddr::V6(v6) => {
                if v6.is_loopback() || v6.is_unique_local() || v6.is_unicast_link_local() {
                    return Err(ApiError::BadRequest(
                        "private or loopback IP URLs are not allowed".into(),
                    ));
                }
            }
        }
    }
    Ok(())
}

fn strip_scripts_and_styles(html: &str) -> String {
    let patterns = [
        r"(?is)<script[^>]*>.*?</script>",
        r"(?is)<style[^>]*>.*?</style>",
        r"(?is)<noscript[^>]*>.*?</noscript>",
    ];
    let mut out = html.to_string();
    for p in patterns {
        let Ok(re) = Regex::new(p) else {
            continue;
        };
        out = re.replace_all(&out, "").to_string();
    }
    out
}

fn normalize_extracted_text(raw: &str) -> String {
    let collapsed_ws = Regex::new(r"[ \t]{2,}").expect("regex");
    raw.lines()
        .map(|line| line.trim())
        .filter(|line| !line.is_empty())
        .map(|line| collapsed_ws.replace_all(line, " ").to_string())
        .collect::<Vec<_>>()
        .join("\n")
}

fn extract_title_and_body(html: &str, fallback_title: &str) -> (String, String) {
    let cleaned = strip_scripts_and_styles(html);
    let document = Html::parse_document(&cleaned);
    let title_sel = Selector::parse("title").expect("selector title");
    let title = document
        .select(&title_sel)
        .next()
        .map(|n| n.text().collect::<String>().trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| fallback_title.to_string());

    let body_sel = Selector::parse("body").expect("selector body");
    let body_raw = document
        .select(&body_sel)
        .next()
        .map(|n| n.text().collect::<Vec<_>>().join("\n"))
        .unwrap_or_default();
    let body_text = normalize_extracted_text(&body_raw);
    (title, body_text)
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/novels/crawl-preview",
    operation_id = "postProjectNovelCrawlPreviewByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = NovelCrawlPreviewBody,
    responses(
        (status = 200, description = "OK", body = NovelCrawlPreviewResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_novel_crawl_preview(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<NovelCrawlPreviewBody>,
) -> Result<JsonResponse<NovelCrawlPreviewResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    ensure_owned_project_pk(pool, uid, project_id).await?;

    let raw_url = body.url.trim();
    if raw_url.is_empty() {
        return Err(ApiError::BadRequest("url must not be empty".into()));
    }
    let parsed =
        url::Url::parse(raw_url).map_err(|_| ApiError::BadRequest("invalid url".into()))?;
    assert_fetchable_url(&parsed)?;

    let resp = state
        .http_client
        .get(parsed.clone())
        .header(
            USER_AGENT,
            "Toonflow/1.0 server-side content-intake crawler",
        )
        .send()
        .await
        .map_err(|e| ApiError::BadRequest(format!("fetch failed: {e}")))?;

    let status = resp.status();
    if !status.is_success() {
        return Err(ApiError::BadRequest(format!(
            "upstream returned HTTP {}",
            status.as_u16()
        )));
    }

    let len = resp.content_length().unwrap_or(0);
    if len > MAX_HTML_BYTES {
        return Err(ApiError::BadRequest(
            "response body too large (Content-Length)".into(),
        ));
    }

    let bytes = resp
        .bytes()
        .await
        .map_err(|e| ApiError::BadRequest(format!("failed to read response body: {e}")))?;
    if bytes.len() as u64 > MAX_HTML_BYTES {
        return Err(ApiError::BadRequest("response body too large".into()));
    }

    let html = String::from_utf8_lossy(&bytes).into_owned();
    let host = parsed.host_str().unwrap_or("novel");
    let (title, body_text) = extract_title_and_body(&html, host);

    Ok(JsonResponse(NovelCrawlPreviewResponse {
        title,
        body_text,
        mode: "single".into(),
        page_count: 1,
    }))
}

#[cfg(test)]
mod tests {
    use super::{extract_title_and_body, normalize_extracted_text, strip_scripts_and_styles};

    #[test]
    fn strips_script_before_body_text() {
        let html = r#"<!doctype html><html><head><title>Hi</title></head><body>
<script>alert(1)</script><p>正文一行</p></body></html>"#;
        let cleaned = strip_scripts_and_styles(html);
        assert!(!cleaned.contains("alert"));
        let (title, body) = extract_title_and_body(html, "fb");
        assert_eq!(title, "Hi");
        assert!(body.contains("正文一行"));
    }

    #[test]
    fn normalize_collapses_blank_lines() {
        let s = normalize_extracted_text("a\n\n\n  b  ");
        assert_eq!(s, "a\nb");
    }
}
