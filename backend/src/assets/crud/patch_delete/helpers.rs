use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};

pub(super) fn parse_asset_type_patch(v: Option<Value>) -> Result<FieldPatch<String>, ApiError> {
    let p = parse_optional_text_field(v, "asset_type")?;
    match &p {
        FieldPatch::Absent => Ok(FieldPatch::Absent),
        FieldPatch::Set(None) => Err(bad_request_i18n(
            "asset_type cannot be null; omit or set role|tool|scene",
            "asset_type 不能为 null；请省略该字段或设置为 role|tool|scene",
        )),
        FieldPatch::Set(Some(s)) => {
            let t = s.trim().to_lowercase();
            if t != "role" && t != "tool" && t != "scene" {
                return Err(bad_request_i18n(
                    "asset_type must be role, tool, or scene",
                    "asset_type 必须是 role、tool 或 scene",
                ));
            }
            Ok(FieldPatch::Set(Some(t)))
        }
    }
}

pub(super) fn merge_metadata_image_id(mut meta: Value, patch: &FieldPatch<i32>) -> Value {
    if !meta.is_object() {
        meta = Value::Object(Default::default());
    }
    if let Some(obj) = meta.as_object_mut() {
        match patch {
            FieldPatch::Absent => {}
            FieldPatch::Set(None) => {
                obj.remove("imageId");
            }
            FieldPatch::Set(Some(n)) => {
                obj.insert("imageId".into(), serde_json::json!(n));
            }
        }
    }
    meta
}

pub(super) async fn cover_numeric_image_exists_for_asset(
    pool: &PgPool,
    asset_id: Uuid,
    numeric_image_id: i32,
) -> Result<bool, ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
          SELECT 1 FROM app_asset_image
          WHERE asset_id = $1 AND numeric_image_id = $2
        )
        "#,
    )
    .bind(asset_id)
    .bind(numeric_image_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(ok)
}
