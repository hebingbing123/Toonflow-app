use super::*;

use serde_json::{json, Value};

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn project_numeric_crud_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let unique_suffix = Uuid::new_v4().simple().to_string();
    let initial_name = format!("pg_numeric_project_{unique_suffix}");
    let updated_name = format!("{initial_name}_updated");

    let create_body = json!({
        "name": initial_name,
        "intro": "seed intro",
        "project_type": "short-drama",
        "art_style": "ink",
        "director_manual": "story-manual",
        "video_ratio": "9:16",
        "image_model": "dalle-3",
        "video_model": "runway",
        "image_quality": "hd",
        "mode": "novel",
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "added={added}");
    let project_uuid = added["id"].as_str().expect("project id").to_owned();
    let numeric_id = added["numeric_id"].as_i64().expect("numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/projects?limit=100&offset=0")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, listed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "listed={listed}");
    let created_row = listed
        .as_array()
        .and_then(|rows| {
            rows.iter()
                .find(|row| row["name"].as_str() == Some(initial_name.as_str()))
        })
        .cloned()
        .expect("created project row");
    assert_eq!(
        created_row["numeric_id"].as_i64(),
        Some(i64::from(numeric_id))
    );
    assert_eq!(created_row["intro"].as_str(), Some("seed intro"));
    assert_eq!(created_row["project_type"].as_str(), Some("short-drama"));
    assert_eq!(created_row["mode"].as_str(), Some("novel"));
    assert_eq!(created_row["art_style"].as_str(), Some("ink"));
    assert_eq!(
        created_row["director_manual"].as_str(),
        Some("story-manual")
    );
    assert_eq!(created_row["video_ratio"].as_str(), Some("9:16"));
    assert_eq!(created_row["image_model"].as_str(), Some("dalle-3"));
    assert_eq!(created_row["video_model"].as_str(), Some("runway"));
    assert_eq!(created_row["image_quality"].as_str(), Some("hd"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND numeric_id = $2",
    )
    .bind(sub)
    .bind(numeric_id)
    .fetch_optional(&pool)
    .await
    .expect("select initial mode");
    assert_eq!(stored_mode.as_deref(), Some("novel"));

    let patch_body = json!({
        "name": updated_name,
        "intro": Value::Null,
        "project_type": "feature",
        "art_style": Value::Null,
        "director_manual": "revised-manual",
        "video_ratio": "16:9",
        "image_model": "flux",
        "video_model": "kling",
        "image_quality": "standard",
        "mode": "professional",
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={_patched}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/projects?limit=100&offset=0")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, relisted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "relisted={relisted}");
    let edited_row = relisted
        .as_array()
        .and_then(|rows| {
            rows.iter()
                .find(|row| row["numeric_id"].as_i64() == Some(i64::from(numeric_id)))
        })
        .cloned()
        .expect("edited project row");
    assert_eq!(edited_row["name"].as_str(), Some(updated_name.as_str()));
    assert!(edited_row["intro"].is_null());
    assert_eq!(edited_row["project_type"].as_str(), Some("feature"));
    assert_eq!(edited_row["mode"].as_str(), Some("professional"));
    assert!(edited_row["art_style"].is_null());
    assert_eq!(
        edited_row["director_manual"].as_str(),
        Some("revised-manual")
    );
    assert_eq!(edited_row["video_ratio"].as_str(), Some("16:9"));
    assert_eq!(edited_row["image_model"].as_str(), Some("flux"));
    assert_eq!(edited_row["video_model"].as_str(), Some("kling"));
    assert_eq!(edited_row["image_quality"].as_str(), Some("standard"));

    let stored_mode: Option<String> = sqlx::query_scalar(
        "SELECT mode FROM public.app_project WHERE owner_user_id = $1 AND numeric_id = $2",
    )
    .bind(sub)
    .bind(numeric_id)
    .fetch_optional(&pool)
    .await
    .expect("select edited mode");
    assert_eq!(stored_mode.as_deref(), Some("professional"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    assert_eq!(status, StatusCode::NO_CONTENT, "delete status");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/projects?limit=100&offset=0")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, after_delete) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_delete={after_delete}");
    let still_present = after_delete.as_array().is_some_and(|rows| {
        rows.iter()
            .any(|row| row["numeric_id"].as_i64() == Some(i64::from(numeric_id)))
    });
    assert!(
        !still_present,
        "deleted row should be absent: {after_delete}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, missing_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "missing_delete={missing_delete}"
    );
}
