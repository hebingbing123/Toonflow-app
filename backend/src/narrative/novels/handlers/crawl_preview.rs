//! Server-side novel URL preview fetch (HTML → title + body text). Preview only; does not write `app_novel` rows.

use std::{collections::HashSet, net::IpAddr};

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
const MAX_TOC_PAGES: usize = 20;
const MAX_PAGINATION_HOPS: usize = 5;

#[derive(Debug, Clone)]
struct ExtractedCrawlerContent {
    title: String,
    body_text: String,
    chapter_urls: Vec<String>,
    next_page_url: Option<String>,
}

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

fn normalize_url_candidate(base_url: &url::Url, raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty()
        || trimmed.starts_with("javascript:")
        || trimmed.starts_with('#')
        || trimmed.starts_with("mailto:")
    {
        return None;
    }
    let joined = base_url.join(trimmed).ok()?;
    Some(joined.to_string())
}

fn extract_links(document: &Html, base_url: &url::Url, selector: &str, cap: usize) -> Vec<String> {
    let Ok(sel) = Selector::parse(selector) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    let mut seen = HashSet::<String>::new();
    for node in document.select(&sel) {
        let Some(href) = node.value().attr("href") else {
            continue;
        };
        let Some(url) = normalize_url_candidate(base_url, href) else {
            continue;
        };
        if seen.insert(url.clone()) {
            out.push(url);
            if out.len() >= cap {
                break;
            }
        }
    }
    out
}

fn extract_next_page(document: &Html, base_url: &url::Url) -> Option<String> {
    let Ok(a_sel) = Selector::parse("a[href]") else {
        return None;
    };
    for node in document.select(&a_sel) {
        let anchor_text = node.text().collect::<String>();
        let text = anchor_text.trim().to_lowercase();
        if text.contains("下一页")
            || text.contains("next")
            || text.contains("下页")
            || text.contains("继续")
        {
            if let Some(href) = node.value().attr("href") {
                if let Some(url) = normalize_url_candidate(base_url, href) {
                    return Some(url);
                }
            }
        }
    }
    None
}

fn extract_crawler_content(
    html: &str,
    fallback_title: &str,
    page_url: &url::Url,
) -> ExtractedCrawlerContent {
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

    let chapter_urls = {
        let mut links = extract_links(&document, page_url, "article a[href]", MAX_TOC_PAGES);
        if links.is_empty() {
            links = extract_links(
                &document,
                page_url,
                ".chapter a[href], .list a[href], .catalog a[href]",
                MAX_TOC_PAGES,
            );
        }
        if links.is_empty() {
            links = extract_links(&document, page_url, "a[href]", MAX_TOC_PAGES);
        }
        links
    };
    let next_page_url = extract_next_page(&document, page_url);

    ExtractedCrawlerContent {
        title,
        body_text,
        chapter_urls,
        next_page_url,
    }
}

async fn fetch_crawler_content(
    state: &AppState,
    parsed: &url::Url,
) -> Result<ExtractedCrawlerContent, ApiError> {
    assert_fetchable_url(parsed)?;
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
    Ok(extract_crawler_content(&html, host, parsed))
}

async fn crawl_preview_adaptive(
    state: &AppState,
    seed_url: &url::Url,
) -> Result<NovelCrawlPreviewResponse, ApiError> {
    let seed = fetch_crawler_content(state, seed_url).await?;

    if !seed.chapter_urls.is_empty() {
        let mut chunks = Vec::<String>::new();
        for chapter_url in seed.chapter_urls.iter().take(MAX_TOC_PAGES) {
            let Ok(parsed) = url::Url::parse(chapter_url) else {
                continue;
            };
            let chapter = fetch_crawler_content(state, &parsed).await?;
            if chapter.body_text.trim().is_empty() {
                continue;
            }
            chunks.push(format!("{}\n{}", chapter.title, chapter.body_text));
        }
        if !chunks.is_empty() {
            return Ok(NovelCrawlPreviewResponse {
                title: seed.title,
                body_text: chunks.join("\n\n"),
                mode: "toc".into(),
                page_count: chunks.len() as i32,
            });
        }
    }

    let mut pages = vec![seed.body_text];
    let mut visited = HashSet::<String>::from([seed_url.to_string()]);
    let mut next_url = seed.next_page_url;
    let mut hops = 0usize;
    while let Some(raw_next) = next_url {
        if hops >= MAX_PAGINATION_HOPS || visited.contains(&raw_next) {
            break;
        }
        visited.insert(raw_next.clone());
        let Ok(parsed) = url::Url::parse(&raw_next) else {
            break;
        };
        let page = fetch_crawler_content(state, &parsed).await?;
        if page.body_text.trim().is_empty() {
            break;
        }
        pages.push(page.body_text);
        next_url = page.next_page_url;
        hops += 1;
    }
    Ok(NovelCrawlPreviewResponse {
        title: seed.title,
        body_text: pages.join("\n\n"),
        mode: if pages.len() > 1 {
            "pagination".into()
        } else {
            "single".into()
        },
        page_count: pages.len() as i32,
    })
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

    let payload = crawl_preview_adaptive(&state, &parsed).await?;
    Ok(JsonResponse(payload))
}

#[cfg(test)]
mod tests {
    use url::Url;

    use super::{extract_crawler_content, normalize_extracted_text, strip_scripts_and_styles};

    #[test]
    fn strips_script_before_body_text() {
        let html = r#"<!doctype html><html><head><title>Hi</title></head><body>
<script>alert(1)</script><p>正文一行</p></body></html>"#;
        let cleaned = strip_scripts_and_styles(html);
        assert!(!cleaned.contains("alert"));
        let page = Url::parse("https://x.example/book/1").expect("url");
        let extracted = extract_crawler_content(html, "fb", &page);
        assert_eq!(extracted.title, "Hi");
        assert!(extracted.body_text.contains("正文一行"));
    }

    #[test]
    fn normalize_collapses_blank_lines() {
        let s = normalize_extracted_text("a\n\n\n  b  ");
        assert_eq!(s, "a\nb");
    }

    #[test]
    fn extracts_catalog_links_and_next_page() {
        let html = r#"<!doctype html><html><head><title>目录</title></head><body>
<div class="catalog"><a href="/c1">第一章</a><a href="/c2">第二章</a></div>
<a href="/next">下一页</a>
</body></html>"#;
        let page = Url::parse("https://x.example/book").expect("url");
        let extracted = extract_crawler_content(html, "fb", &page);
        assert_eq!(extracted.chapter_urls.len(), 2);
        assert_eq!(extracted.chapter_urls[0], "https://x.example/c1");
        assert_eq!(
            extracted.next_page_url.as_deref(),
            Some("https://x.example/next")
        );
    }
}
