use super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::{Request, StatusCode};
use tower::ServiceExt;

#[tokio::test]
async fn marketing_site_root_when_website_dir_present() {
    let app = crate::app::build_router(smoke_state());
    let res = app
        .oneshot(
            Request::builder()
                .uri("/")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    if crate::marketing_site::resolve_dir().is_some() {
        assert_eq!(res.status(), StatusCode::OK);
        let body = axum::body::to_bytes(res.into_body(), 1024 * 1024)
            .await
            .unwrap();
        let html = std::str::from_utf8(&body).expect("utf8");
        assert!(html.contains("OpenFlow"), "expected marketing HTML at /");
    } else {
        assert_eq!(res.status(), StatusCode::NOT_FOUND);
    }
}
