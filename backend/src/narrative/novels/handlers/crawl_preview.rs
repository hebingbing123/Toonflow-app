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
use serde_json::{Map, Value};
use uuid::Uuid;

use crate::assets::ensure_owned_project_pk;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::dto::{
    NovelCrawlImportBatchBody, NovelCrawlImportBatchItem, NovelCrawlImportBatchResponse,
};
use super::super::dto::{
    NovelCrawlImportBody, NovelCrawlImportResponse, NovelCrawlPreviewBody,
    NovelCrawlPreviewResponse,
};
use super::super::ADV_LOCK_NOVEL_NUMERIC;
use super::list::{normalize_intake_source, trim_opt};

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

#[derive(Debug, Clone)]
pub(crate) struct CrawlAuditSummary {
    pub(crate) mode: String,
    pub(crate) page_count: i32,
    pub(crate) chapter_url_count: i32,
    pub(crate) body_char_count: i32,
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
    if !(joined.scheme() == "http" || joined.scheme() == "https") {
        return None;
    }
    // Keep crawler behavior aligned with the Flutter client:
    // only allow URLs from the same host.
    let base_host = base_url.host_str()?;
    let joined_host = joined.host_str()?;
    if !joined_host.eq_ignore_ascii_case(base_host) {
        return None;
    }
    Some(joined.to_string())
}

fn discover_next_page_url(document: &Html, base_url: &url::Url) -> Option<String> {
    let Ok(a_sel) = Selector::parse("a[href]") else {
        return None;
    };
    for node in document.select(&a_sel) {
        let anchor_text = node.text().collect::<String>();
        let text = anchor_text.trim().to_lowercase();
        let rel = node
            .value()
            .attr("rel")
            .unwrap_or_default()
            .to_lowercase()
            .trim()
            .to_string();

        if rel == "next" || text.contains("下一页") || text.contains("下页") || text == "next"
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

fn discover_chapter_urls(document: &Html, base_url: &url::Url, cap: usize) -> Vec<String> {
    // Keep it in sync with the Flutter client logic:
    // - label-based chapters: 第X章/序章/尾声/番外
    // - href-based chapters: contains "/chapter" "/read" "chapter="
    let chapter_label_pattern =
        Regex::new(r"(?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|序章|尾声|番外)")
            .expect("chapter label regex");

    let Ok(a_sel) = Selector::parse("a[href]") else {
        return Vec::new();
    };

    let mut discovered = HashSet::<String>::new();
    let mut out = Vec::<String>::new();
    for node in document.select(&a_sel) {
        let anchor_text = node.text().collect::<String>();
        let href = node
            .value()
            .attr("href")
            .unwrap_or_default()
            .trim()
            .to_string();
        if href.is_empty() {
            continue;
        }

        let anchor_text_trimmed = anchor_text.trim();
        let seems_chapter = chapter_label_pattern.is_match(anchor_text_trimmed);

        let lower_href = href.to_lowercase();
        let seems_chapter_href = lower_href.contains("/chapter")
            || lower_href.contains("/read")
            || lower_href.contains("chapter=");

        if !seems_chapter && !seems_chapter_href {
            continue;
        }

        if let Some(url) = normalize_url_candidate(base_url, &href) {
            if discovered.insert(url.clone()) {
                out.push(url);
                if out.len() >= cap {
                    break;
                }
            }
        }
    }

    out
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

    let chapter_urls = discover_chapter_urls(&document, page_url, 80);
    let next_page_url = discover_next_page_url(&document, page_url);

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

pub(crate) async fn crawl_preview_adaptive(
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
            let body_text = chunks.join("\n\n");
            return Ok(NovelCrawlPreviewResponse {
                title: seed.title,
                body_text: body_text.clone(),
                mode: "toc".into(),
                page_count: chunks.len() as i32,
                chapter_url_count: seed.chapter_urls.len() as i32,
                body_char_count: body_text.chars().count() as i32,
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
    let body_text = pages.join("\n\n");
    Ok(NovelCrawlPreviewResponse {
        title: seed.title,
        body_text: body_text.clone(),
        mode: if pages.len() > 1 {
            "pagination".into()
        } else {
            "single".into()
        },
        page_count: pages.len() as i32,
        chapter_url_count: seed.chapter_urls.len() as i32,
        body_char_count: body_text.chars().count() as i32,
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

pub(crate) fn normalize_extracted_text_for_import(raw: &str) -> String {
    // Ported from Flutter `import_parser.dart::_normalizeExtractedText`.
    let mut normalized = raw
        .replace("\r\n", "\n")
        .replace('\r', "\n")
        .replace('\u{00A0}', " ")
        .replace('\u{200B}', "")
        .replace('\u{3000}', " ");

    let whitespace_re = Regex::new(r"[ \t]{2,}").expect("whitespace regex");
    let junk_line_re = Regex::new(
        r"(?i)(?:收藏本站|最新网址|手机阅读|本章未完|点击下一页|上一章|下一章|广告|版权归|请记住本站)",
    )
    .expect("junk regex");

    let lines = normalized
        .split('\n')
        .map(|line| whitespace_re.replace_all(line, " ").to_string())
        .map(|line| line.trim().to_string())
        .filter(|line| !line.is_empty())
        .filter(|line| !junk_line_re.is_match(line))
        .collect::<Vec<_>>();

    normalized = lines.join("\n");

    let too_many_newlines_re = Regex::new(r"\n{3,}").expect("newlines regex");
    too_many_newlines_re
        .replace_all(&normalized, "\n\n")
        .to_string()
        .trim()
        .to_string()
}

pub(crate) fn parse_whole_book_chapters_from_normalized(
    normalized: &str,
    fallback_prefix: &str,
) -> Vec<(i32, String, String)> {
    // Returns (chapter_index, chapter_title, chapter_data).
    let chapter_header_re = Regex::new(
        r"(?m)^\s*((?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|(?:序章|尾声|番外))(?:[^\n\r]{0,36}))\s*$",
    )
    .expect("chapter header regex");

    if normalized.is_empty() {
        return Vec::new();
    }

    let mut match_caps = chapter_header_re
        .captures_iter(normalized)
        .collect::<Vec<_>>();

    if match_caps.is_empty() {
        return vec![(
            1,
            format!("{fallback_prefix} 1"),
            normalize_extracted_text_for_import(normalized),
        )];
    }

    let mut matches = Vec::<(usize, usize, String)>::new();
    for cap in match_caps.drain(..) {
        let full = cap
            .get(0)
            .expect("full match range in chapter header regex");
        let title = cap
            .get(1)
            .map(|m| m.as_str().trim().to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(String::new);
        matches.push((full.start(), full.end(), title));
    }

    let mut chapters = Vec::<(i32, String, String)>::new();
    for (i, (_start, end, title)) in matches.iter().enumerate() {
        let body_start = *end;
        let body_end = if i + 1 < matches.len() {
            matches[i + 1].0
        } else {
            normalized.len()
        };
        if body_start >= body_end {
            continue;
        }

        let body = normalized[body_start..body_end].trim();
        if body.is_empty() {
            continue;
        }

        let idx = chapters.len() as i32 + 1;
        let chapter_title = if !title.is_empty() {
            title.clone()
        } else {
            format!("{fallback_prefix} {}", i + 1)
        };
        chapters.push((
            idx,
            chapter_title,
            normalize_extracted_text_for_import(body),
        ));
    }

    chapters
}

pub(crate) fn evaluate_novel_import_quality(
    chapters: &[(i32, String, String)],
    min_total_chars: usize,
    min_avg_chapter_chars: usize,
    max_duplicate_ratio_percent: usize,
) -> (Vec<String>, Vec<String>) {
    // Returns (blockers, warnings).
    let mut blockers = Vec::<String>::new();
    let mut warnings = Vec::<String>::new();

    if chapters.is_empty() {
        blockers.push("没有可导入的正文章节".into());
        return (blockers, warnings);
    }

    let body_texts = chapters
        .iter()
        .map(|(_, _, data)| data.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect::<Vec<_>>();

    if body_texts.is_empty() {
        blockers.push("没有可导入的正文章节".into());
        return (blockers, warnings);
    }

    let total_chars = body_texts.iter().map(|s| s.len()).sum::<usize>();
    let avg_chars = total_chars / body_texts.len();

    if total_chars < min_total_chars {
        blockers.push(format!("正文总字数过少（{}），疑似抽取失败", total_chars));
    }
    if avg_chars < min_avg_chapter_chars {
        blockers.push(format!(
            "平均章节字数过少（{}），请先检查切章结果",
            avg_chars
        ));
    }

    let unique_bodies = body_texts
        .iter()
        .cloned()
        .collect::<std::collections::HashSet<_>>();
    let duplicate_count = body_texts.len() - unique_bodies.len();
    let duplicate_ratio_percent = (duplicate_count * 100) / body_texts.len().max(1);

    if duplicate_ratio_percent >= max_duplicate_ratio_percent {
        blockers.push(format!(
            "章节正文重复比例过高（{}%）",
            duplicate_ratio_percent
        ));
    } else if duplicate_ratio_percent > 0 {
        warnings.push(format!(
            "检测到部分重复正文（{}%）",
            duplicate_ratio_percent
        ));
    }

    if body_texts.len() == 1 {
        warnings.push("仅识别到 1 章，可能是整本未正确切章".into());
    }
    if body_texts.len() > 300 {
        warnings.push(format!(
            "章节数较多（{}），建议抽样检查切章准确性",
            body_texts.len()
        ));
    }

    (blockers, warnings)
}

pub(crate) async fn insert_imported_novels_for_project(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    chapters: &[(i32, String, String)],
    intake_status: &str,
    intake_note: Option<&str>,
    intake_source_url: &str,
    crawl_audit: &CrawlAuditSummary,
) -> Result<i32, ApiError> {
    let intake_source = normalize_intake_source("crawler_server")?;
    let intake_source_url = trim_opt(Some(intake_source_url.to_string()))
        .ok_or_else(|| ApiError::BadRequest("intake_source_url must not be empty".into()))?;
    let intake_note = intake_note.and_then(|s| trim_opt(Some(s.to_string())));

    let intake_status = intake_status.trim().to_string();
    // Validate intake_status using the same allowed set as create.rs.
    match intake_status.as_str() {
        "draft" | "pending_review" | "admitted" | "rejected" => {}
        _ => {
            return Err(ApiError::BadRequest(
                "intake_status must be one of draft, pending_review, admitted, rejected".into(),
            ))
        }
    }

    let metadata = {
        let mut m = Map::new();
        m.insert("intakeSource".into(), Value::String(intake_source));
        m.insert("intakeSourceUrl".into(), Value::String(intake_source_url));
        m.insert("intakeStatus".into(), Value::String(intake_status));
        let audit_note = format!(
            "server-crawl mode={} pages={} chapter_links={} chars={}",
            crawl_audit.mode,
            crawl_audit.page_count,
            crawl_audit.chapter_url_count,
            crawl_audit.body_char_count
        );
        let merged_note = match intake_note {
            Some(note) if !note.is_empty() => format!("{note} | {audit_note}"),
            _ => audit_note,
        };
        m.insert("intakeNote".into(), Value::String(merged_note));
        Value::Object(m)
    };

    let now_ms = chrono::Utc::now().timestamp_millis();

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_NOVEL_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_novel
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for (i, (chapter_index, chapter_title, chapter_data)) in chapters.iter().enumerate() {
        let numeric_id = next_numeric_id + i as i32;
        sqlx::query(
            r#"
            INSERT INTO app_novel (
              project_id, numeric_id, chapter_index, reel, chapter, chapter_data,
              event, event_state, error_reason, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, NULL, $4, $5, NULL, 0, NULL, $6, $7)
            "#,
        )
        .bind(project_id)
        .bind(numeric_id)
        .bind(*chapter_index)
        .bind(chapter_title)
        .bind(chapter_data)
        .bind(now_ms)
        .bind(metadata.clone())
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(chapters.len() as i32)
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/novels/crawl-import",
    operation_id = "postProjectNovelCrawlImportByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = NovelCrawlImportBody,
    responses(
        (status = 200, description = "OK", body = NovelCrawlImportResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_novel_crawl_import(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<NovelCrawlImportBody>,
) -> Result<JsonResponse<NovelCrawlImportResponse>, ApiError> {
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

    let preview = crawl_preview_adaptive(&state, &parsed).await?;
    let normalized_for_import = normalize_extracted_text_for_import(&preview.body_text);

    let mut chapters =
        parse_whole_book_chapters_from_normalized(&normalized_for_import, "导入章节");

    // Drop empty bodies and reindex (parse already normalizes).
    chapters.retain(|(_, _, data)| !data.trim().is_empty());
    for (idx, ch) in chapters.iter_mut().enumerate() {
        ch.0 = (idx + 1) as i32;
    }

    let (blockers, warnings) = evaluate_novel_import_quality(&chapters, 200, 50, 40);
    if !blockers.is_empty() {
        return Err(ApiError::BadRequest(format!(
            "导入质量门未通过：{}",
            blockers.join("；")
        )));
    }

    let created = insert_imported_novels_for_project(
        pool,
        project_id,
        &chapters,
        &body.intake_status,
        body.intake_note.as_deref(),
        raw_url,
        &CrawlAuditSummary {
            mode: preview.mode.clone(),
            page_count: preview.page_count,
            chapter_url_count: preview.chapter_url_count,
            body_char_count: preview.body_char_count,
        },
    )
    .await?;

    Ok(JsonResponse(NovelCrawlImportResponse {
        title: preview.title,
        mode: preview.mode,
        page_count: preview.page_count,
        chapter_url_count: preview.chapter_url_count,
        body_char_count: preview.body_char_count,
        chapters_created: created,
        quality_warnings: warnings,
    }))
}

fn classify_import_error(err: &ApiError) -> (String, String) {
    // Stable-ish error codes for observability; keep the message human-readable.
    match err {
        ApiError::Unauthorized => ("unauthorized".into(), "unauthorized".into()),
        ApiError::BadToken => ("invalid_token".into(), "invalid token".into()),
        ApiError::AuthNotConfigured => ("auth_not_configured".into(), "auth not configured".into()),
        ApiError::NotFound => ("not_found".into(), "not found".into()),
        ApiError::Forbidden(msg) => ("forbidden".into(), msg.clone()),
        ApiError::BadRequest(msg) => ("bad_request".into(), msg.clone()),
        ApiError::Conflict(msg) => ("conflict".into(), msg.clone()),
        ApiError::ConflictWithDetails { message, .. } => ("conflict".into(), message.clone()),
        ApiError::DatabaseError(msg) => ("database_error".into(), msg.clone()),
        ApiError::QuotaExceeded(msg) => ("quota_exceeded".into(), msg.clone()),
        ApiError::NotImplemented(msg) => ("not_implemented".into(), msg.clone()),
        ApiError::Internal => ("internal".into(), "internal error".into()),
        ApiError::WebhookNotConfigured => (
            "webhook_not_configured".into(),
            "webhook not configured".into(),
        ),
        ApiError::InvalidWebhookSignature => (
            "invalid_webhook_signature".into(),
            "invalid webhook signature".into(),
        ),
        ApiError::LlmNotConfigured => ("llm_not_configured".into(), "llm not configured".into()),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/novels/crawl-import-batch",
    operation_id = "postProjectNovelCrawlImportBatchByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = NovelCrawlImportBatchBody,
    responses(
        (status = 200, description = "OK", body = NovelCrawlImportBatchResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_novel_crawl_import_batch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<NovelCrawlImportBatchBody>,
) -> Result<JsonResponse<NovelCrawlImportBatchResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    ensure_owned_project_pk(pool, uid, project_id).await?;

    if body.urls.is_empty() {
        return Err(ApiError::BadRequest("urls must not be empty".into()));
    }
    if body.urls.len() > 50 {
        return Err(ApiError::BadRequest("urls too many (max 50)".into()));
    }

    let mut items: Vec<NovelCrawlImportBatchItem> = Vec::new();
    let mut succeeded = 0i32;
    let mut failed = 0i32;

    for raw in body.urls.iter() {
        let url = raw.trim().to_string();
        if url.is_empty() {
            continue;
        }

        let result: Result<NovelCrawlImportResponse, ApiError> = async {
            let parsed =
                url::Url::parse(&url).map_err(|_| ApiError::BadRequest("invalid url".into()))?;
            assert_fetchable_url(&parsed)?;

            let preview = crawl_preview_adaptive(&state, &parsed).await?;
            let normalized_for_import = normalize_extracted_text_for_import(&preview.body_text);
            let mut chapters =
                parse_whole_book_chapters_from_normalized(&normalized_for_import, "导入章节");
            chapters.retain(|(_, _, data)| !data.trim().is_empty());
            for (idx, ch) in chapters.iter_mut().enumerate() {
                ch.0 = (idx + 1) as i32;
            }

            let (blockers, warnings) = evaluate_novel_import_quality(&chapters, 200, 50, 40);
            if !blockers.is_empty() {
                return Err(ApiError::BadRequest(format!(
                    "导入质量门未通过：{}",
                    blockers.join("；")
                )));
            }

            let created = insert_imported_novels_for_project(
                pool,
                project_id,
                &chapters,
                &body.intake_status,
                body.intake_note.as_deref(),
                &url,
                &CrawlAuditSummary {
                    mode: preview.mode.clone(),
                    page_count: preview.page_count,
                    chapter_url_count: preview.chapter_url_count,
                    body_char_count: preview.body_char_count,
                },
            )
            .await?;

            Ok(NovelCrawlImportResponse {
                title: preview.title,
                mode: preview.mode,
                page_count: preview.page_count,
                chapter_url_count: preview.chapter_url_count,
                body_char_count: preview.body_char_count,
                chapters_created: created,
                quality_warnings: warnings,
            })
        }
        .await;

        match result {
            Ok(ok) => {
                succeeded += 1;
                items.push(NovelCrawlImportBatchItem {
                    url,
                    ok: true,
                    error_code: None,
                    error_message: None,
                    title: Some(ok.title),
                    mode: Some(ok.mode),
                    page_count: Some(ok.page_count),
                    chapter_url_count: Some(ok.chapter_url_count),
                    body_char_count: Some(ok.body_char_count),
                    chapters_created: Some(ok.chapters_created),
                    quality_warnings: ok.quality_warnings,
                });
            }
            Err(e) => {
                failed += 1;
                let (code, msg) = classify_import_error(&e);
                items.push(NovelCrawlImportBatchItem {
                    url,
                    ok: false,
                    error_code: Some(code),
                    error_message: Some(msg),
                    title: None,
                    mode: None,
                    page_count: None,
                    chapter_url_count: None,
                    body_char_count: None,
                    chapters_created: None,
                    quality_warnings: Vec::new(),
                });
            }
        }
    }

    Ok(JsonResponse(NovelCrawlImportBatchResponse {
        total: (succeeded + failed),
        succeeded,
        failed,
        items,
    }))
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
