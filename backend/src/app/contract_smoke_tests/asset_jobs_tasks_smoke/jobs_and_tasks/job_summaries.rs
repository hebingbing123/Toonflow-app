use super::{assert_database_error_get, assert_unauthorized_get};

#[tokio::test]
async fn jobs_kinds_unauthorized_without_bearer() {
    assert_unauthorized_get("/api/v1/jobs/kinds").await;
}

#[tokio::test]
async fn jobs_kinds_summary_unauthorized_without_bearer() {
    assert_unauthorized_get("/api/v1/jobs/kinds/summary").await;
}

#[tokio::test]
async fn jobs_status_summary_unauthorized_without_bearer() {
    assert_unauthorized_get("/api/v1/jobs/status/summary").await;
}

#[tokio::test]
async fn jobs_kinds_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/jobs/kinds").await;
}

#[tokio::test]
async fn jobs_kinds_summary_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/jobs/kinds/summary").await;
}

#[tokio::test]
async fn jobs_status_summary_requires_database_with_jwt() {
    assert_database_error_get("/api/v1/jobs/status/summary").await;
}
