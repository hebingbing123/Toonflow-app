//! Shared **S3-compatible** client for settings export artifacts (workspace shared audit zip/csv/json,
//! account data zip). Endpoint resolution is unified so one MinIO cluster can back multiple buckets.
//!
//! Env (first non-empty wins for URL):
//! - **`TOONFLOW_EXPORT_S3_ENDPOINT`** — preferred shared override
//! - **`TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_ENDPOINT`**
//! - **`TOONFLOW_ACCOUNT_EXPORT_S3_ENDPOINT`**
//!
//! Path-style: true if any of **`TOONFLOW_EXPORT_S3_FORCE_PATH_STYLE`**,
//! **`TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_FORCE_PATH_STYLE`**,
//! **`TOONFLOW_ACCOUNT_EXPORT_S3_FORCE_PATH_STYLE`** is `1`/`true`, else **true** when a custom
//! endpoint is set (typical MinIO).

use tokio::sync::OnceCell;

static S3_CLIENT: OnceCell<aws_sdk_s3::Client> = OnceCell::const_new();

fn first_nonempty_env(keys: &[&str]) -> Option<String> {
    for key in keys {
        if let Ok(v) = std::env::var(key) {
            let t = v.trim().to_string();
            if !t.is_empty() {
                return Some(t);
            }
        }
    }
    None
}

fn resolved_endpoint_url() -> Option<String> {
    first_nonempty_env(&[
        "TOONFLOW_EXPORT_S3_ENDPOINT",
        "TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_ENDPOINT",
        "TOONFLOW_ACCOUNT_EXPORT_S3_ENDPOINT",
    ])
}

fn force_path_style_for_custom_endpoint() -> bool {
    for key in &[
        "TOONFLOW_EXPORT_S3_FORCE_PATH_STYLE",
        "TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_FORCE_PATH_STYLE",
        "TOONFLOW_ACCOUNT_EXPORT_S3_FORCE_PATH_STYLE",
    ] {
        if let Ok(v) = std::env::var(key) {
            let s = v.trim();
            if s == "1" || s.eq_ignore_ascii_case("true") {
                return true;
            }
            if s == "0" || s.eq_ignore_ascii_case("false") {
                return false;
            }
        }
    }
    resolved_endpoint_url().is_some()
}

async fn shared_s3_client() -> Result<&'static aws_sdk_s3::Client, String> {
    S3_CLIENT
        .get_or_try_init(|| async {
            let shared_config =
                aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
            let mut b = aws_sdk_s3::config::Builder::from(&shared_config);
            if let Some(url) = resolved_endpoint_url() {
                b = b.endpoint_url(&url);
                b = b.force_path_style(force_path_style_for_custom_endpoint());
            }
            Ok(aws_sdk_s3::Client::from_conf(b.build()))
        })
        .await
}

pub(crate) async fn put_object(
    bucket: &str,
    key: &str,
    content_type: &str,
    bytes: &[u8],
) -> Result<(), String> {
    let client = shared_s3_client().await?;
    client
        .put_object()
        .bucket(bucket)
        .key(key)
        .content_type(content_type)
        .body(aws_sdk_s3::primitives::ByteStream::from(bytes.to_vec()))
        .send()
        .await
        .map_err(|e| format!("S3 put_object: {e}"))?;
    Ok(())
}

pub(crate) async fn get_object(bucket: &str, key: &str) -> Result<Vec<u8>, String> {
    let client = shared_s3_client().await?;
    let out = client
        .get_object()
        .bucket(bucket)
        .key(key)
        .send()
        .await
        .map_err(|e| format!("S3 get_object: {e}"))?;
    let body = out.body.collect().await.map_err(|e| e.to_string())?;
    Ok(body.into_bytes().to_vec())
}

/// Best-effort removal of all objects under **`prefix/`** (e.g. on account delete).
pub(crate) async fn delete_objects_with_prefix(bucket: &str, prefix: &str) -> Result<(), String> {
    let client = shared_s3_client().await?;
    let mut continuation: Option<String> = None;
    loop {
        let mut req = client.list_objects_v2().bucket(bucket).prefix(prefix);
        if let Some(ref t) = continuation {
            req = req.continuation_token(t.clone());
        }
        let out = req
            .send()
            .await
            .map_err(|e| format!("S3 list_objects_v2: {e}"))?;
        let contents = out.contents();
        if !contents.is_empty() {
            let mut objects = Vec::new();
            for obj in contents {
                if let Some(k) = obj.key() {
                    objects.push(
                        aws_sdk_s3::types::ObjectIdentifier::builder()
                            .key(k)
                            .build()
                            .map_err(|e| e.to_string())?,
                    );
                }
            }
            if !objects.is_empty() {
                let delete = aws_sdk_s3::types::Delete::builder()
                    .set_objects(Some(objects))
                    .build()
                    .map_err(|e| e.to_string())?;
                client
                    .delete_objects()
                    .bucket(bucket)
                    .delete(delete)
                    .send()
                    .await
                    .map_err(|e| format!("S3 delete_objects: {e}"))?;
            }
        }
        continuation = out.next_continuation_token().map(|s| s.to_string());
        if continuation.is_none() {
            break;
        }
    }
    Ok(())
}
