use axum::Router;
use serde_json::Value;
use tower::ServiceExt;
use zip::ZipArchive;

use crate::app::pg_contract_tests::{
    build_router, contract_state, header, jwt_fixture, read_json_response, test_addr, Body,
    ConnectInfo, Method, PgPool, PgPoolOptions, Request, Response, StatusCode, Uuid,
    CONTRACT_USER_SUB,
};

pub(super) async fn connect_contract_app() -> (PgPool, String, Router, Uuid) {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    crate::app::pg_contract_tests::ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));
    (pool, token, app, sub)
}

pub(super) async fn post_json_raw_response(
    app: &Router,
    token: &str,
    uri: &str,
    body: Value,
) -> Response {
    app.clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap()
}

pub(super) async fn post_json_response(
    app: &Router,
    token: &str,
    uri: &str,
    body: Value,
) -> (StatusCode, Value) {
    let res = post_json_raw_response(app, token, uri, body).await;
    read_json_response(res).await
}

pub(super) async fn create_project(app: &Router, token: &str) -> (i32, String) {
    let (status, created) =
        post_json_response(app, token, "/api/v1/projects", serde_json::json!({})).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    (
        created["numeric_id"].as_i64().expect("numeric_id") as i32,
        created["id"].as_str().expect("project uuid").to_string(),
    )
}

pub(super) async fn create_script(
    app: &Router,
    token: &str,
    project_uuid: &str,
    name: &str,
) -> i32 {
    let (status, script) = post_json_response(
        app,
        token,
        &format!("/api/v1/projects/{project_uuid}/scripts"),
        serde_json::json!({ "name": name }),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    script["numeric_id"].as_i64().expect("script numeric_id") as i32
}

pub(super) async fn create_storyboard(
    app: &Router,
    token: &str,
    project_uuid: &str,
    script_id: i32,
    body: &str,
) -> i32 {
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_id}/storyboards"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, storyboard) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "storyboard={storyboard}");
    storyboard["numeric_id"]
        .as_i64()
        .expect("storyboard numeric_id") as i32
}

pub(super) async fn get_production_data(
    app: &Router,
    token: &str,
    project_id: i32,
    script_id: i32,
    ids: &[i32],
) -> Value {
    let (status, production_data) = post_json_response(
        app,
        token,
        "/api/v1/production/get-production-data",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "ids": ids,
        }),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "production_data={production_data}");
    production_data
}

pub(super) async fn get_flow_data(
    app: &Router,
    token: &str,
    project_id: i32,
    script_id: i32,
) -> Value {
    let (status, flow_data) = post_json_response(
        app,
        token,
        "/api/v1/production/get-flow-data",
        serde_json::json!({
            "projectId": project_id,
            "episodesId": script_id,
        }),
    )
    .await;
    assert_eq!(status, StatusCode::OK, "flow_data={flow_data}");
    flow_data
}

pub(super) async fn save_flow_data(app: &Router, token: &str, body: Value) {
    let res = post_json_raw_response(app, token, "/api/v1/production/save-flow-data", body).await;
    assert_eq!(
        res.status(),
        StatusCode::OK,
        "save-flow-data should accept owned project"
    );
}

pub(super) async fn save_storyboard_image_url(
    app: &Router,
    token: &str,
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    image_url: &str,
) -> Value {
    let (status, updated_storyboard) = post_json_response(
        app,
        token,
        "/api/v1/production/storyboard/update-url",
        serde_json::json!({
            "projectId": project_id,
            "scriptId": script_id,
            "storyboardId": storyboard_id,
            "imageUrl": image_url,
        }),
    )
    .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "updated_storyboard={updated_storyboard}"
    );
    updated_storyboard
}

pub(super) async fn save_workbench_video_action(
    app: &Router,
    token: &str,
    uri: &str,
    body: Value,
) -> Value {
    let (status, payload) = post_json_response(app, token, uri, body).await;
    assert_eq!(status, StatusCode::OK, "{uri}={payload}");
    payload
}

pub(super) async fn read_storyboard_indexes(pool: &PgPool, ids: &[i32]) -> Vec<(i32, Option<i32>)> {
    sqlx::query_as(
        r#"
        SELECT numeric_id, sb_index
        FROM app_storyboard
        WHERE numeric_id = ANY($1::int4[])
        ORDER BY numeric_id ASC
        "#,
    )
    .bind(ids.to_vec())
    .fetch_all(pool)
    .await
    .expect("query reordered storyboard indexes")
}

pub(super) async fn count_video_track_rows(
    pool: &PgPool,
    sub: Uuid,
    project_id: i32,
    script_id: i32,
    track_id: i32,
) -> i64 {
    sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_video_track vt
        INNER JOIN app_project p ON p.id = vt.project_id
        INNER JOIN app_script s ON s.id = vt.script_id
        WHERE p.numeric_id = $2
          AND s.numeric_id = $3
          AND vt.numeric_id = $4
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .bind(script_id)
    .bind(track_id)
    .fetch_one(pool)
    .await
    .expect("query persisted video track")
}

pub(super) async fn count_agent_memory_rows(
    pool: &PgPool,
    sub: Uuid,
    project_id: i32,
    script_id: i32,
    name: &str,
    like_pattern: Option<String>,
) -> i64 {
    match like_pattern {
        Some(pattern) => sqlx::query_scalar(
            r#"
                SELECT COUNT(*)
                FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND episodes_id = $3
                  AND agent_type = 'productionAgent'
                  AND memory_type = 'summary'
                  AND name = $4
                  AND content LIKE $5
                "#,
        )
        .bind(sub)
        .bind(project_id)
        .bind(script_id)
        .bind(name)
        .bind(pattern)
        .fetch_one(pool)
        .await
        .expect("query agent memory rows with pattern"),
        None => sqlx::query_scalar(
            r#"
                SELECT COUNT(*)
                FROM app_agent_memory
                WHERE owner_user_id = $1
                  AND numeric_project_id = $2
                  AND episodes_id = $3
                  AND agent_type = 'productionAgent'
                  AND memory_type = 'summary'
                  AND name = $4
                "#,
        )
        .bind(sub)
        .bind(project_id)
        .bind(script_id)
        .bind(name)
        .fetch_one(pool)
        .await
        .expect("query agent memory rows"),
    }
}

pub(super) fn read_zip_string_entry<R: std::io::Read + std::io::Seek>(
    archive: &mut ZipArchive<R>,
    name: &str,
) -> String {
    let mut entry = archive.by_name(name).expect("zip entry");
    let mut content = String::new();
    std::io::Read::read_to_string(&mut entry, &mut content).expect("read zip string entry");
    content
}
