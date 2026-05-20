//! Per-project novel crawl credentials (encrypted at rest) and HTTP auth resolution.

use std::time::Duration;

use axum::http::HeaderMap;
use reqwest::header::{COOKIE, USER_AGENT};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, not_implemented_i18n, validate_enum, ApiError};
use crate::state::AppState;
use crate::vendor::credential::{decrypt, encrypt, is_encryption_configured};

use super::dto::{NovelCrawlAuthGetResponse, NovelCrawlAuthOverride, NovelCrawlAuthPutBody};

const AUTH_MODES: &[&str] = &["none", "cookie", "password", "cookie_and_password"];
const USER_AGENT_VALUE: &str = "Openflow/1.0 server-side content-intake crawler";

#[derive(Debug, Clone, Default)]
struct StoredCrawlAuth {
    auth_mode: String,
    cookie: Option<String>,
    username: Option<String>,
    password: Option<String>,
    login_url: Option<String>,
    login_username_field: String,
    login_password_field: String,
}

#[derive(Debug, Clone, Default)]
pub(crate) struct ResolvedCrawlAuth {
    pub(crate) cookie_header: Option<String>,
    pub(crate) basic_auth: Option<(String, String)>,
}

fn encrypt_field(plaintext: &str) -> Result<Vec<u8>, ApiError> {
    encrypt(plaintext).ok_or_else(|| {
        not_implemented_i18n(
            "Credential encryption not configured (set OPENFLOW_VENDOR_CREDENTIAL_KEY)",
            "凭据加密未配置（请设置 OPENFLOW_VENDOR_CREDENTIAL_KEY）",
        )
    })
}

fn decrypt_field(bytes: Option<Vec<u8>>) -> Option<String> {
    let bytes = bytes?;
    decrypt(&bytes)
}

fn merge_cookie_parts(parts: impl IntoIterator<Item = String>) -> Option<String> {
    let merged = parts
        .into_iter()
        .map(|s| s.trim().trim_end_matches(';').trim().to_string())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>();
    if merged.is_empty() {
        None
    } else {
        Some(merged.join("; "))
    }
}

fn extract_set_cookie_values(headers: &HeaderMap) -> String {
    let mut pairs = Vec::<String>::new();
    for value in headers.get_all("set-cookie") {
        let Ok(raw) = value.to_str() else {
            continue;
        };
        let pair = raw.split(';').next().unwrap_or("").trim();
        if !pair.is_empty() {
            pairs.push(pair.to_string());
        }
    }
    pairs.join("; ")
}

pub(crate) fn validate_auth_mode(mode: &str) -> Result<(), ApiError> {
    validate_enum(mode, AUTH_MODES, "auth_mode")
}

async fn load_stored(pool: &PgPool, project_id: Uuid) -> Result<Option<StoredCrawlAuth>, ApiError> {
    let row = sqlx::query_as::<_, CrawlAuthRow>(
        r#"
        SELECT
            auth_mode,
            cookie_encrypted,
            username_encrypted,
            password_encrypted,
            login_url,
            login_username_field,
            login_password_field
        FROM app_project_novel_crawl_auth
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.map(|r| StoredCrawlAuth {
        auth_mode: r.auth_mode,
        cookie: decrypt_field(r.cookie_encrypted),
        username: decrypt_field(r.username_encrypted),
        password: decrypt_field(r.password_encrypted),
        login_url: r.login_url,
        login_username_field: r.login_username_field,
        login_password_field: r.login_password_field,
    }))
}

async fn form_login_cookie(
    client: &reqwest::Client,
    login_url: &str,
    username: &str,
    password: &str,
    user_field: &str,
    pass_field: &str,
    existing_cookie: Option<&str>,
) -> Result<String, ApiError> {
    let body = format!(
        "{}={}&{}={}",
        urlencoding::encode(user_field),
        urlencoding::encode(username),
        urlencoding::encode(pass_field),
        urlencoding::encode(password)
    );
    let mut req = client
        .post(login_url)
        .header(USER_AGENT, USER_AGENT_VALUE)
        .header(
            reqwest::header::CONTENT_TYPE,
            "application/x-www-form-urlencoded",
        )
        .body(body);
    if let Some(cookie) = existing_cookie.filter(|c| !c.is_empty()) {
        req = req.header(COOKIE, cookie);
    }
    let resp = req.send().await.map_err(|e| {
        bad_request_i18n(
            &format!("login request failed: {e}"),
            &format!("登录请求失败：{e}"),
        )
    })?;
    let status = resp.status();
    let cookies = extract_set_cookie_values(resp.headers());
    if cookies.is_empty() && !status.is_success() {
        return Err(bad_request_i18n(
            &format!("login returned HTTP {}", status.as_u16()),
            &format!("登录返回 HTTP {}", status.as_u16()),
        ));
    }
    if cookies.is_empty() {
        return Err(bad_request_i18n(
            "login succeeded but no Set-Cookie was returned; try cookie mode with browser cookies",
            "登录未返回 Set-Cookie，请改用 Cookie 模式粘贴浏览器 Cookie",
        ));
    }
    Ok(cookies)
}

fn pick_credentials(
    stored: &StoredCrawlAuth,
    override_auth: Option<&NovelCrawlAuthOverride>,
) -> (Option<String>, Option<String>) {
    let username = override_auth
        .and_then(|a| a.username.clone())
        .or_else(|| stored.username.clone());
    let password = override_auth
        .and_then(|a| a.password.clone())
        .or_else(|| stored.password.clone());
    (username, password)
}

fn pick_cookie(
    stored: &StoredCrawlAuth,
    override_auth: Option<&NovelCrawlAuthOverride>,
) -> Option<String> {
    override_auth
        .and_then(|a| a.cookie.clone())
        .or_else(|| stored.cookie.clone())
}

pub(crate) async fn resolve_crawl_auth_inline(
    _state: &AppState,
    override_auth: Option<&NovelCrawlAuthOverride>,
) -> Result<ResolvedCrawlAuth, ApiError> {
    let Some(o) = override_auth else {
        return Ok(ResolvedCrawlAuth::default());
    };
    let mut cookie_parts = Vec::<String>::new();
    if let Some(c) = o.cookie.as_deref().filter(|c| !c.is_empty()) {
        cookie_parts.push(c.to_string());
    }
    let username = o
        .username
        .as_deref()
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    let password = o
        .password
        .as_deref()
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    let basic_auth = match (username, password) {
        (Some(u), Some(p)) => Some((u, p)),
        _ => None,
    };
    Ok(ResolvedCrawlAuth {
        cookie_header: merge_cookie_parts(cookie_parts),
        basic_auth,
    })
}

pub(crate) async fn resolve_stored_crawl_auth(
    state: &AppState,
    pool: &PgPool,
    project_id: Uuid,
) -> Result<ResolvedCrawlAuth, ApiError> {
    resolve_crawl_auth(state, pool, project_id, None).await
}

pub(crate) async fn resolve_crawl_auth_for_request(
    state: &AppState,
    project_id: Uuid,
    override_auth: Option<&NovelCrawlAuthOverride>,
) -> Result<ResolvedCrawlAuth, ApiError> {
    if let Some(pool) = state.pool.as_ref() {
        resolve_crawl_auth(state, pool, project_id, override_auth).await
    } else {
        resolve_crawl_auth_inline(state, override_auth).await
    }
}

pub(crate) async fn resolve_crawl_auth(
    state: &AppState,
    pool: &PgPool,
    project_id: Uuid,
    override_auth: Option<&NovelCrawlAuthOverride>,
) -> Result<ResolvedCrawlAuth, ApiError> {
    let stored = load_stored(pool, project_id).await?.unwrap_or_default();
    let mode = stored.auth_mode.as_str();
    let use_cookie = matches!(mode, "cookie" | "cookie_and_password");
    let use_password = matches!(mode, "password" | "cookie_and_password");

    let mut cookie_parts = Vec::<String>::new();
    if use_cookie {
        if let Some(c) = pick_cookie(&stored, override_auth) {
            cookie_parts.push(c);
        }
    }

    let (username, password) = pick_credentials(&stored, override_auth);
    let mut basic_auth = None;

    if use_password {
        if let (Some(u), Some(p)) = (username.as_deref(), password.as_deref()) {
            if let Some(login_url) = stored.login_url.as_deref().filter(|s| !s.is_empty()) {
                let user_field = if stored.login_username_field.trim().is_empty() {
                    "username"
                } else {
                    stored.login_username_field.trim()
                };
                let pass_field = if stored.login_password_field.trim().is_empty() {
                    "password"
                } else {
                    stored.login_password_field.trim()
                };
                let existing = merge_cookie_parts(cookie_parts.iter().cloned());
                let session = form_login_cookie(
                    &state.http_client,
                    login_url,
                    u,
                    p,
                    user_field,
                    pass_field,
                    existing.as_deref(),
                )
                .await?;
                cookie_parts.push(session);
            } else {
                basic_auth = Some((u.to_string(), p.to_string()));
            }
        }
    }

    // Inline override can supply cookie even when stored mode is password-only.
    if let Some(c) = override_auth.and_then(|a| a.cookie.as_ref()) {
        if !c.trim().is_empty() && !use_cookie {
            cookie_parts.push(c.trim().to_string());
        }
    }

    Ok(ResolvedCrawlAuth {
        cookie_header: merge_cookie_parts(cookie_parts),
        basic_auth,
    })
}

pub(crate) fn apply_crawl_auth(
    builder: reqwest::RequestBuilder,
    auth: &ResolvedCrawlAuth,
) -> reqwest::RequestBuilder {
    let mut req = builder.header(USER_AGENT, USER_AGENT_VALUE);
    if let Some(cookie) = auth.cookie_header.as_deref().filter(|c| !c.is_empty()) {
        req = req.header(COOKIE, cookie);
    }
    if let Some((user, pass)) = auth.basic_auth.as_ref() {
        req = req.basic_auth(user, Some(pass));
    }
    req
}

pub(crate) async fn build_crawl_http_client(state: &AppState) -> reqwest::Client {
    reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(30))
        .timeout(Duration::from_secs(180))
        .cookie_store(true)
        .build()
        .unwrap_or_else(|_| state.http_client.clone())
}

pub(crate) async fn get_crawl_auth_config(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<NovelCrawlAuthGetResponse, ApiError> {
    let row = sqlx::query_as::<_, CrawlAuthMetaRow>(
        r#"
        SELECT
            auth_mode,
            cookie_encrypted IS NOT NULL AS has_cookie,
            username_encrypted IS NOT NULL AS has_username,
            password_encrypted IS NOT NULL AS has_password,
            login_url,
            login_username_field,
            login_password_field,
            updated_at
        FROM app_project_novel_crawl_auth
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(match row {
        Some(r) => NovelCrawlAuthGetResponse {
            auth_mode: r.auth_mode,
            has_cookie: r.has_cookie,
            has_username: r.has_username,
            has_password: r.has_password,
            login_url: r.login_url,
            login_username_field: r.login_username_field,
            login_password_field: r.login_password_field,
            encryption_configured: is_encryption_configured(),
            updated_at: Some(r.updated_at.to_rfc3339()),
        },
        None => NovelCrawlAuthGetResponse {
            auth_mode: "none".into(),
            has_cookie: false,
            has_username: false,
            has_password: false,
            login_url: None,
            login_username_field: "username".into(),
            login_password_field: "password".into(),
            encryption_configured: is_encryption_configured(),
            updated_at: None,
        },
    })
}

pub(crate) async fn put_crawl_auth_config(
    pool: &PgPool,
    project_id: Uuid,
    body: NovelCrawlAuthPutBody,
) -> Result<NovelCrawlAuthGetResponse, ApiError> {
    validate_auth_mode(&body.auth_mode)?;

    let needs_secret = body.auth_mode != "none"
        && (body.cookie.as_ref().is_some_and(|c| !c.is_empty())
            || body.username.as_ref().is_some_and(|u| !u.is_empty())
            || body.password.as_ref().is_some_and(|p| !p.is_empty()));

    if needs_secret && !is_encryption_configured() {
        return Err(not_implemented_i18n(
            "Credential encryption not configured (set OPENFLOW_VENDOR_CREDENTIAL_KEY)",
            "凭据加密未配置（请设置 OPENFLOW_VENDOR_CREDENTIAL_KEY）",
        ));
    }

    let existing = sqlx::query_as::<_, CrawlAuthEncryptedRow>(
        r#"
        SELECT cookie_encrypted, username_encrypted, password_encrypted
        FROM app_project_novel_crawl_auth
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (cookie_encrypted, username_encrypted, password_encrypted) = if body.auth_mode == "none" {
        (None, None, None)
    } else {
        (
            resolve_secret_update(
                body.cookie.as_deref(),
                existing.as_ref().and_then(|e| e.cookie_encrypted.as_ref()),
            )?,
            resolve_secret_update(
                body.username.as_deref(),
                existing
                    .as_ref()
                    .and_then(|e| e.username_encrypted.as_ref()),
            )?,
            resolve_secret_update(
                body.password.as_deref(),
                existing
                    .as_ref()
                    .and_then(|e| e.password_encrypted.as_ref()),
            )?,
        )
    };

    let login_username_field = body
        .login_username_field
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or("username")
        .to_string();
    let login_password_field = body
        .login_password_field
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or("password")
        .to_string();

    sqlx::query(
        r#"
        INSERT INTO app_project_novel_crawl_auth (
            project_id,
            auth_mode,
            cookie_encrypted,
            username_encrypted,
            password_encrypted,
            login_url,
            login_username_field,
            login_password_field,
            updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
        ON CONFLICT (project_id) DO UPDATE SET
            auth_mode = EXCLUDED.auth_mode,
            cookie_encrypted = EXCLUDED.cookie_encrypted,
            username_encrypted = EXCLUDED.username_encrypted,
            password_encrypted = EXCLUDED.password_encrypted,
            login_url = EXCLUDED.login_url,
            login_username_field = EXCLUDED.login_username_field,
            login_password_field = EXCLUDED.login_password_field,
            updated_at = NOW()
        "#,
    )
    .bind(project_id)
    .bind(&body.auth_mode)
    .bind(cookie_encrypted)
    .bind(username_encrypted)
    .bind(password_encrypted)
    .bind(body.login_url.as_deref())
    .bind(&login_username_field)
    .bind(&login_password_field)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_crawl_auth_config(pool, project_id).await
}

/// `Some("")` clears; `None` keeps existing ciphertext; `Some(value)` encrypts new value.
fn resolve_secret_update(
    incoming: Option<&str>,
    existing_encrypted: Option<&Vec<u8>>,
) -> Result<Option<Vec<u8>>, ApiError> {
    match incoming {
        None => Ok(existing_encrypted.cloned()),
        Some("") => Ok(None),
        Some(value) => Ok(Some(encrypt_field(value)?)),
    }
}

#[derive(Debug, sqlx::FromRow)]
struct CrawlAuthEncryptedRow {
    cookie_encrypted: Option<Vec<u8>>,
    username_encrypted: Option<Vec<u8>>,
    password_encrypted: Option<Vec<u8>>,
}

#[derive(Debug, sqlx::FromRow)]
struct CrawlAuthRow {
    auth_mode: String,
    cookie_encrypted: Option<Vec<u8>>,
    username_encrypted: Option<Vec<u8>>,
    password_encrypted: Option<Vec<u8>>,
    login_url: Option<String>,
    login_username_field: String,
    login_password_field: String,
}

#[derive(Debug, sqlx::FromRow)]
struct CrawlAuthMetaRow {
    auth_mode: String,
    has_cookie: bool,
    has_username: bool,
    has_password: bool,
    login_url: Option<String>,
    login_username_field: String,
    login_password_field: String,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_cookie_parts_skips_empty() {
        assert_eq!(
            merge_cookie_parts(vec!["a=1".into(), "".into(), "b=2".into()]),
            Some("a=1; b=2".into())
        );
    }
}
