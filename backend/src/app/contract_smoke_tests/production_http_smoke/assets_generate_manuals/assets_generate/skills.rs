use super::super::super::super::helpers::*;
use axum::http::StatusCode;
use serde_json::Value;
use uuid::Uuid;

#[tokio::test]
async fn skills_list_ok_with_jwt_when_skills_tree_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/skills", &token).await;
    assert_eq!(status, StatusCode::OK);
    let arr = v.as_array().expect("skills list is array");
    assert!(!arr.is_empty());
    assert!(arr.iter().any(|e| {
        e.get("path")
            .and_then(Value::as_str)
            .is_some_and(|p| p.ends_with(".md"))
    }));
}
