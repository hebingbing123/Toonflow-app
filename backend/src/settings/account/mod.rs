//! 账户数据导出与删号。
//!
//! - `POST /api/v1/settings/account/export`：入队账户导出 zip
//! - `GET /api/v1/settings/account/exports`：查看最近导出任务
//! - `GET /api/v1/settings/account/exports/{job_id}/file`：下载导出包
//! - `POST /api/v1/settings/account/delete`：强确认后删除当前账户
//!
//! **S3（可选）**：设置 **`TOONFLOW_ACCOUNT_EXPORT_S3_BUCKET`** 后 worker 将 zip 写入对象存储；与 workspace 导出共用
//! **`TOONFLOW_EXPORT_S3_ENDPOINT`** / **`TOONFLOW_ACCOUNT_EXPORT_S3_ENDPOINT`** 等（见 **`crate::settings::export_s3`**）。

use axum::{routing::get, routing::post, Router};

use crate::state::AppState;

mod handlers;
mod storage;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{
    __path_get_account_export_file, __path_get_account_exports, __path_post_account_delete,
    __path_post_account_export,
};
pub(crate) use handlers::{
    get_account_export_file, get_account_exports, post_account_delete, post_account_export,
};
pub(crate) use storage::build_account_export_artifact;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/settings/account/export", post(post_account_export))
        .route("/api/v1/settings/account/exports", get(get_account_exports))
        .route(
            "/api/v1/settings/account/exports/{job_id}/file",
            get(get_account_export_file),
        )
        .route("/api/v1/settings/account/delete", post(post_account_delete))
}

#[cfg(test)]
mod tests {
    use crate::error::helpers::bad_request_i18n;
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    use crate::error::ApiError;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    use super::types::ACCOUNT_DELETE_CONFIRM_PHRASE;

    #[test]
    fn account_delete_confirm_phrase_error_creates_correct_variant() {
        let err = bad_request_i18n(
            &format!("confirmPhrase must equal `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
            &format!("confirmPhrase 必须等于 `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
        );
        match err {
            ApiError::BadRequest(msg) => {
                assert!(
                    msg.contains("confirmPhrase must equal")
                        || msg.contains("confirmPhrase 必须等于")
                );
            }
            _ => panic!("expected BadRequest variant"),
        }
    }

    #[tokio::test]
    async fn account_delete_confirm_phrase_error_response_en() {
        let err = bad_request_i18n(
            &format!("confirmPhrase must equal `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
            &format!("confirmPhrase 必须等于 `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("confirmPhrase must equal"));
        assert!(message.contains(ACCOUNT_DELETE_CONFIRM_PHRASE));
    }

    #[tokio::test]
    async fn account_delete_confirm_phrase_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = bad_request_i18n(
                    &format!("confirmPhrase must equal `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
                    &format!("confirmPhrase 必须等于 `{ACCOUNT_DELETE_CONFIRM_PHRASE}`"),
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("confirmPhrase 必须等于"));
        assert!(message.contains(ACCOUNT_DELETE_CONFIRM_PHRASE));
    }

    #[test]
    fn account_delete_acknowledge_error_creates_correct_variant() {
        let err = bad_request_i18n(
            "acknowledgeIrreversible must be true",
            "acknowledgeIrreversible 必须为 true",
        );
        match err {
            ApiError::BadRequest(msg) => {
                assert!(
                    msg == "acknowledgeIrreversible must be true"
                        || msg == "acknowledgeIrreversible 必须为 true"
                );
            }
            _ => panic!("expected BadRequest variant"),
        }
    }

    #[tokio::test]
    async fn account_delete_acknowledge_error_response_en() {
        let err = bad_request_i18n(
            "acknowledgeIrreversible must be true",
            "acknowledgeIrreversible 必须为 true",
        );
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("acknowledgeIrreversible must be true")
        );
    }

    #[tokio::test]
    async fn account_delete_acknowledge_error_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = bad_request_i18n(
                    "acknowledgeIrreversible must be true",
                    "acknowledgeIrreversible 必须为 true",
                );
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(400));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("bad_request")
        );
        assert_eq!(
            json.get("message").and_then(|v| v.as_str()),
            Some("acknowledgeIrreversible 必须为 true")
        );
    }
}
