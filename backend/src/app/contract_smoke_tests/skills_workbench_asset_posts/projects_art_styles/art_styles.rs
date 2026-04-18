use super::super::super::helpers::*;
use axum::http::StatusCode;

/// Missing **`Authorization`** must yield **401** before any Postgres pool access (no **503** `database_error` when `DATABASE_URL` is unset).
#[tokio::test]
async fn art_styles_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_by_numeric_id_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/numeric/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_cover_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/numeric/1/cover").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
