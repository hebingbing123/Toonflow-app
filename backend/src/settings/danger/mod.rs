//! 危险操作模块。
//!
//! 遗留 `POST /api/other/deleteAllData` 和 `GET /api/setting/dbConfig/clearData` 擦除/重建**本地 SQLite**。
//! SaaS：`POST` 端点仅接受 `{}`；需要 **JWT**；响应 **501** — 无批量擦除（使用 Supabase 操作/账户删除流程）。

use axum::{routing::post, Router};

use crate::state::AppState;

mod handlers;
mod types;

#[allow(unused_imports)]
pub(crate) use handlers::{__path_post_clear_database, __path_post_delete_all_data};
pub(crate) use handlers::{post_clear_database, post_delete_all_data};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/danger/delete-all-data",
            post(post_delete_all_data),
        )
        .route(
            "/api/v1/settings/danger/clear-database",
            post(post_clear_database),
        )
}

#[cfg(test)]
mod tests {
    use super::handlers::wipe_not_supported;
    use super::types::EmptyDangerBody;
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    use crate::error::ApiError;
    use axum::body::to_bytes;
    use axum::response::IntoResponse;

    #[test]
    fn empty_danger_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<EmptyDangerBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn empty_danger_body_accepts_empty() {
        let b: EmptyDangerBody = serde_json::from_str(r#"{}"#).unwrap();
        let _ = b;
    }

    #[test]
    fn wipe_not_supported_returns_not_implemented() {
        let err = wipe_not_supported();
        match err {
            ApiError::NotImplementedI18n { en, zh } => {
                assert!(en.contains("bulk database wipe is not supported"));
                assert!(zh.contains("不支持批量数据库清除"));
            }
            _ => panic!("expected NotImplementedI18n variant"),
        }
    }

    #[tokio::test]
    async fn wipe_not_supported_response_en() {
        let err = wipe_not_supported();
        let resp = err.into_response();

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("bulk database wipe is not supported"));
        assert!(message.contains("use hosted Postgres operations"));
    }

    #[tokio::test]
    async fn wipe_not_supported_response_zh() {
        let resp = REQUEST_LOCALE
            .scope(ApiLocale::Zh, async {
                let err = wipe_not_supported();
                err.into_response()
            })
            .await;

        let bytes = to_bytes(resp.into_body(), 16 * 1024)
            .await
            .expect("body bytes");
        let json: serde_json::Value = serde_json::from_slice(&bytes).expect("json body");

        assert_eq!(json.get("status").and_then(|v| v.as_u64()), Some(501));
        assert_eq!(
            json.get("code").and_then(|v| v.as_str()),
            Some("not_implemented")
        );
        let message = json.get("message").and_then(|v| v.as_str()).unwrap();
        assert!(message.contains("不支持批量数据库清除"));
        assert!(message.contains("托管 Postgres 操作"));
    }
}
