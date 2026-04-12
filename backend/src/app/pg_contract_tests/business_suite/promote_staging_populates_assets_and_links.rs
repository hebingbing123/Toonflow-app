use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn promote_staging_populates_assets_and_links() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    cleanup_promote_staging_fixtures(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    sqlx::query(
        r#"INSERT INTO public.import_user_map (import_user_id, supabase_user_id)
           VALUES ($1, $2)
           ON CONFLICT (import_user_id) DO UPDATE SET supabase_user_id = EXCLUDED.supabase_user_id"#,
    )
    .bind(PROMO_IMPORT_USER)
    .bind(sub)
    .execute(&pool)
    .await
    .expect("import_user_map insert (requires existing auth.users id = CONTRACT_USER_SUB)");

    let project = serde_json::json!({
        "id": PROMO_PROJECT_LEG,
        "userId": PROMO_IMPORT_USER,
        "name": "pg_promote_project",
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_project', 'pg_promote_proj', $1)"#,
    )
    .bind(Json(project))
    .execute(&pool)
    .await
    .expect("staging o_project");

    let script = serde_json::json!({
        "id": PROMO_SCRIPT_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_script",
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_script', 'pg_promote_script', $1)"#,
    )
    .bind(Json(script))
    .execute(&pool)
    .await
    .expect("staging o_script");

    let asset = serde_json::json!({
        "id": PROMO_ASSET_LEG,
        "projectId": PROMO_PROJECT_LEG,
        "name": "pg_promote_hero",
        "type": "character",
        "describe": "promoted lead",
        "imageId": PROMO_IMAGE_LEG,
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_assets', 'pg_promote_asset', $1)"#,
    )
    .bind(Json(asset))
    .execute(&pool)
    .await
    .expect("staging o_assets");

    let link = serde_json::json!({
        "scriptId": PROMO_SCRIPT_LEG,
        "assetId": PROMO_ASSET_LEG,
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_scriptAssets', 'pg_promote_script_asset', $1)"#,
    )
    .bind(Json(link))
    .execute(&pool)
    .await
    .expect("staging o_scriptAssets");

    let art_style = serde_json::json!({
        "id": PROMO_ART_STYLE_LEG,
        "name": "pg_promote_style",
        "fileUrl": "/art/promo.jpg",
        "label": "pg_label",
        "prompt": "pg_prompt",
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_artStyle', 'pg_promote_art_style', $1)"#,
    )
    .bind(Json(art_style))
    .execute(&pool)
    .await
    .expect("staging o_artStyle");

    let o_prompt_row = serde_json::json!({
        "id": 1,
        "name": "事件提取",
        "type": "eventExtraction",
        "data": "pg_promoted_prompt_body_evt",
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_prompt', 'pg_promote_prompt', $1)"#,
    )
    .bind(Json(o_prompt_row))
    .execute(&pool)
    .await
    .expect("staging o_prompt");

    let o_image_row = serde_json::json!({
        "id": PROMO_IMAGE_LEG,
        "assetsId": PROMO_ASSET_LEG,
        "filePath": "/promo/history_corner.png",
        "state": "已完成",
    });
    sqlx::query(
        r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
           VALUES ('o_image', 'pg_promote_image', $1)"#,
    )
    .bind(Json(o_image_row))
    .execute(&pool)
    .await
    .expect("staging o_image");

    sqlx::query("SELECT 1 FROM public.promote_import_snapshots() LIMIT 1")
        .execute(&pool)
        .await
        .expect("promote_import_snapshots");

    let asset_rows: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM public.app_asset WHERE numeric_id = $1")
            .bind(PROMO_ASSET_LEG)
            .fetch_one(&pool)
            .await
            .expect("count app_asset");
    assert_eq!(asset_rows, 1, "expected one promoted app_asset row");

    let link_rows: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM public.app_script_asset sa
           INNER JOIN public.app_script sc ON sc.id = sa.script_id
           INNER JOIN public.app_asset a ON a.id = sa.asset_id
           WHERE sc.numeric_id = $1 AND a.numeric_id = $2"#,
    )
    .bind(PROMO_SCRIPT_LEG)
    .bind(PROMO_ASSET_LEG)
    .fetch_one(&pool)
    .await
    .expect("count script_asset link");
    assert_eq!(link_rows, 1, "expected one promoted app_script_asset row");

    let promoted_img: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_asset_image WHERE numeric_image_id = $1",
    )
    .bind(PROMO_IMAGE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_asset_image by numeric_image_id");
    assert_eq!(promoted_img, 1, "expected one promoted app_asset_image row");

    let style_rows: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE numeric_id = $1",
    )
    .bind(PROMO_ART_STYLE_LEG)
    .fetch_one(&pool)
    .await
    .expect("count app_art_style");
    assert_eq!(style_rows, 1, "expected one promoted app_art_style row");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let promo_project_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id FROM public.app_project WHERE numeric_id = $1 AND owner_user_id = $2"#,
    )
    .bind(PROMO_PROJECT_LEG)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("promoted project pk");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, styles_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "art_styles={styles_body}");
    let sitems = styles_body["items"].as_array().expect("style items");
    let sfound = sitems
        .iter()
        .find(|row| row["numeric_id"].as_i64() == Some(i64::from(PROMO_ART_STYLE_LEG)));
    let srow = sfound.expect("promoted art style in list");
    assert_eq!(srow["name"].as_str(), Some("pg_promote_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{}/assets", promo_project_uuid))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets list={list}");
    let items = list["items"].as_array().expect("items");
    let found = items
        .iter()
        .find(|row| row["numeric_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)));
    let row = found.expect("promoted asset in list");
    assert_eq!(row["name"].as_str(), Some("pg_promote_hero"));
    assert_eq!(row["asset_type"].as_str(), Some("role"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets?script_numeric_id={}",
                    promo_project_uuid, PROMO_SCRIPT_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    assert_eq!(linked["total"], 1);
    assert_eq!(
        linked["items"][0]["numeric_id"].as_i64(),
        Some(i64::from(PROMO_ASSET_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{}/assets/corner-scape",
                    promo_project_uuid
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, corner) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "corner={corner}");
    let citems = corner["items"].as_array().expect("corner items");
    let hero = citems
        .iter()
        .find(|row| row["numeric_id"].as_i64() == Some(i64::from(PROMO_ASSET_LEG)))
        .expect("promoted asset in corner-scape");
    let hist = hero["history_images"].as_array().expect("history_images");
    assert_eq!(hist.len(), 1);
    assert_eq!(
        hist[0]["file_path"].as_str(),
        Some("/promo/history_corner.png")
    );
    assert_eq!(hist[0]["state"].as_str(), Some("已完成"));
    assert_eq!(
        hist[0]["numeric_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, promo_list_img) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "promo_list_img={promo_list_img}");
    assert_eq!(
        promo_list_img["cover_numeric_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let plim = promo_list_img["items"]
        .as_array()
        .expect("promoted image list items");
    assert_eq!(plim.len(), 1);
    assert_eq!(plim[0]["selected"], true);
    assert_eq!(
        plim[0]["numeric_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"cover_numeric_image_id":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "clear cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared_list={cleared_list}");
    assert!(cleared_list["cover_numeric_image_id"].is_null());
    let clim = cleared_list["items"].as_array().expect("cleared items");
    assert_eq!(clim[0]["selected"], false);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"cover_numeric_image_id":{}}}"#,
                    PROMO_IMAGE_LEG
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restore cover via PATCH");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{}/assets/{}/images",
                    promo_project_uuid, PROMO_ASSET_LEG
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restored_list={restored_list}");
    assert_eq!(
        restored_list["cover_numeric_image_id"].as_i64(),
        Some(i64::from(PROMO_IMAGE_LEG))
    );
    let rlim = restored_list["items"].as_array().expect("restored items");
    assert_eq!(rlim[0]["selected"], true);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, prompts_body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "prompts={prompts_body}");
    let parr = prompts_body.as_array().expect("prompts json array");
    assert_eq!(parr.len(), 3);
    let p1 = parr
        .iter()
        .find(|row| row["id"].as_i64() == Some(1))
        .expect("prompt numeric id 1");
    assert_eq!(
        p1["data"].as_str(),
        Some("pg_promoted_prompt_body_evt"),
        "promoted o_prompt body should override file default"
    );

    cleanup_promote_staging_fixtures(&pool).await;
}
