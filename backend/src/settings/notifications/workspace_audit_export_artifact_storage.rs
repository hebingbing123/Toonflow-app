//! Optional **S3-compatible** object storage for workspace shared audit export artifacts.
//!
//! When **`TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET`** is set, async exports use the shared
//! [`crate::settings::export_s3`] client (see **`TOONFLOW_EXPORT_S3_ENDPOINT`** for a single MinIO URL).

use uuid::Uuid;

use crate::settings::export_s3;

fn s3_bucket_name() -> Option<String> {
    std::env::var("TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_BUCKET")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn s3_object_key_prefix() -> String {
    std::env::var("TOONFLOW_WORKSPACE_SHARED_AUDIT_EXPORT_S3_PREFIX")
        .ok()
        .map(|s| s.trim().trim_matches('/').to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "workspace-shared-audit-exports".to_string())
}

pub(crate) fn use_s3_for_workspace_shared_audit_export_artifacts() -> bool {
    s3_bucket_name().is_some()
}

/// Upload bytes; returns **`(bucket, object_key)`**.
pub(crate) async fn put_workspace_shared_audit_export_s3_object(
    owner_user_id: Uuid,
    file_name: &str,
    content_type: &str,
    bytes: &[u8],
) -> Result<(String, String), String> {
    let bucket = s3_bucket_name().ok_or_else(|| "S3 bucket not configured".to_string())?;
    let key = format!("{}/{}/{}", s3_object_key_prefix(), owner_user_id, file_name);
    export_s3::put_object(&bucket, &key, content_type, bytes).await?;
    Ok((bucket, key))
}

pub(crate) async fn get_workspace_shared_audit_export_s3_object(
    bucket: &str,
    key: &str,
) -> Result<Vec<u8>, String> {
    export_s3::get_object(bucket, key).await
}

/// Best-effort cleanup of this user’s workspace-shared audit export objects (e.g. account delete).
pub(crate) async fn delete_workspace_shared_audit_export_s3_prefix_for_user(user_id: Uuid) {
    let Some(bucket) = s3_bucket_name() else {
        return;
    };
    let prefix = format!("{}/{}/", s3_object_key_prefix(), user_id);
    let _ = export_s3::delete_objects_with_prefix(&bucket, &prefix).await;
}
