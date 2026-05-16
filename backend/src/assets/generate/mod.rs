//! 遗留 `/api/assetsGenerate/*` 资产生成端点。
//!
//! 处理单图生成、提示词优化、批量生成和批量优化请求，
//! 将任务加入 `app_generation_job` 队列由后台 Worker 执行。
//!
//! 端点：
//! - `POST …/generate` — 单图生成
//! - `POST …/polish-prompt` — 单条提示词优化
//! - `POST …/batch-generate` — 批量图片生成
//! - `POST …/batch-polish` — 批量提示词优化
//! - `POST …/cancel-generate` — 取消生成任务

mod common;
mod handlers;
mod types;

use axum::{routing::post, Router};

use crate::state::AppState;

use handlers::{
    post_batch_generate_image_assets, post_batch_polish_assets_prompt, post_cancel_generate,
    post_generate_assets, post_polish_assets_prompt,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/assets-generate/generate",
            post(post_generate_assets),
        )
        .route(
            "/api/v1/assets-generate/polish-prompt",
            post(post_polish_assets_prompt),
        )
        .route(
            "/api/v1/assets-generate/batch-generate",
            post(post_batch_generate_image_assets),
        )
        .route(
            "/api/v1/assets-generate/batch-polish",
            post(post_batch_polish_assets_prompt),
        )
        .route(
            "/api/v1/assets-generate/cancel-generate",
            post(post_cancel_generate),
        )
}

#[cfg(test)]
mod tests {
    use super::common::{normalize_optional_base64, MAX_BASE64_HINT_LEN};
    use crate::error::ApiError;

    #[test]
    fn normalize_base64_none_or_blank_to_none() {
        assert_eq!(
            normalize_optional_base64(None, "base64").expect("none"),
            None
        );
        assert_eq!(
            normalize_optional_base64(Some("  "), "base64").expect("blank"),
            None
        );
    }

    #[test]
    fn normalize_base64_raw_to_data_uri() {
        let got = normalize_optional_base64(Some("  QUJDRA== "), "base64").expect("raw");
        assert_eq!(got.as_deref(), Some("data:image/jpeg;base64,QUJDRA=="));
    }

    #[test]
    fn normalize_base64_keeps_data_uri() {
        let src = "data:image/png;base64,AA==";
        let got = normalize_optional_base64(Some(src), "base64").expect("uri");
        assert_eq!(got.as_deref(), Some(src));
    }

    #[test]
    fn normalize_base64_rejects_over_limit() {
        let oversized = "A".repeat(MAX_BASE64_HINT_LEN + 1);
        let err = normalize_optional_base64(Some(&oversized), "base64").expect_err("oversized");
        match err {
            ApiError::BadRequest(msg) => assert!(
                msg.contains(&format!("at most {MAX_BASE64_HINT_LEN} characters")),
                "msg={msg}"
            ),
            other => panic!("expected bad_request, got {other:?}"),
        }
    }

    #[test]
    fn normalize_base64_accepts_exact_limit() {
        let exact = "A".repeat(MAX_BASE64_HINT_LEN);
        let got = normalize_optional_base64(Some(&exact), "base64").expect("exact");
        let expected = format!("data:image/jpeg;base64,{exact}");
        assert_eq!(got.as_deref(), Some(expected.as_str()));
    }
}
