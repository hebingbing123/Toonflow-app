use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn visual_manual_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/visual-manual").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn visual_manual_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/visual-manual", &token).await;
    assert_eq!(status, StatusCode::OK, "visual_manual={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2, "expected multiple art_skills styles");
    assert!(
        styles
            .iter()
            .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")),
        "expected 2D_90s_japanese_anime in {styles:?}"
    );
}

#[tokio::test]
async fn visual_manual_post_ok_with_jwt_when_art_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/visual-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "visual_manual_post={v}");
    let styles = v["styles"].as_array().expect("styles");
    assert!(styles.len() >= 2);
    assert!(styles
        .iter()
        .any(|s| s["stylePath"].as_str() == Some("2D_90s_japanese_anime")));
}

#[tokio::test]
async fn visual_manual_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/visual-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}
