use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_generate_events_async_fallback_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    for body in [
        r#"{"chapter_index":1,"reel":"卷一","chapter":"第一章","chapter_data":"第一章内容"}"#,
        r#"{"chapter_index":2,"reel":"卷一","chapter":"第二章","chapter_data":"第二章内容"}"#,
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "add novel for generate-events test"
        );
    }

    let novel_rows: Vec<(i32,)> = sqlx::query_as(
        r#"
        SELECT n.numeric_id
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.numeric_id = $1
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        ORDER BY n.chapter_index ASC, n.numeric_id ASC
        "#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .fetch_all(&pool)
    .await
    .expect("list novel numeric ids");
    let novel_numeric_ids: Vec<i32> = novel_rows.into_iter().map(|(id,)| id).collect();
    assert_eq!(novel_numeric_ids.len(), 2, "expected two novels");

    sqlx::query(
        r#"
        UPDATE public.app_novel n
        SET event = '历史事件', event_state = 1, error_reason = NULL
        FROM public.app_project p
        WHERE n.project_id = p.id
          AND p.numeric_id = $1
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
          AND n.numeric_id = ANY($3)
        "#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .bind(&novel_numeric_ids)
    .execute(&pool)
    .await
    .expect("seed existing events");

    let payload = serde_json::json!({
        "novelIds": novel_numeric_ids,
        "concurrentCount": 2
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novel-events/generate-events"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate-events body={body}");
    assert_eq!(body["message"].as_str(), Some("生成事件成功"));

    let reset_rows: Vec<(Option<String>, i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT n.event, n.event_state, n.error_reason
        FROM public.app_novel n
        INNER JOIN public.app_project p ON p.id = n.project_id
        WHERE p.numeric_id = $1
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
          AND n.numeric_id = ANY($3)
        ORDER BY n.chapter_index ASC, n.numeric_id ASC
        "#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .bind(&novel_numeric_ids)
    .fetch_all(&pool)
    .await
    .expect("rows immediately after enqueue");
    assert!(
        reset_rows
            .iter()
            .all(|(event, state, reason)| event.is_none() && *state == 0 && reason.is_none()),
        "expected reset to pending before async extraction: {reset_rows:?}"
    );

    let mut final_rows: Vec<(i32, Option<String>, i32, Option<String>)> = Vec::new();
    for _ in 0..40 {
        final_rows = sqlx::query_as(
            r#"
            SELECT n.numeric_id, n.event, n.event_state, n.error_reason
            FROM public.app_novel n
            INNER JOIN public.app_project p ON p.id = n.project_id
            WHERE p.numeric_id = $1
              AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $2
              )
              AND n.numeric_id = ANY($3)
            ORDER BY n.chapter_index ASC, n.numeric_id ASC
            "#,
        )
        .bind(project_numeric_id)
        .bind(sub)
        .bind(&novel_numeric_ids)
        .fetch_all(&pool)
        .await
        .expect("poll extraction rows");
        if final_rows
            .iter()
            .all(|(_, _, state, _)| *state == -1 || *state == 1)
        {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(25)).await;
    }

    assert!(
        final_rows.iter().all(|(_, event, state, reason)| {
            event.is_none() && *state == -1 && reason.as_deref() == Some("llm_not_configured")
        }),
        "expected llm_not_configured fallback rows: {final_rows:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novels?page=1&limit=50"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, novel_json) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "novel_json={novel_json}");
    let items = novel_json["items"].as_array().expect("novel items");
    let non_zero: Vec<&serde_json::Value> = items
        .iter()
        .filter(|row| {
            let Some(lid) = row["numeric_id"].as_i64() else {
                return false;
            };
            let lid = lid as i32;
            novel_numeric_ids.contains(&lid) && row["event_state"].as_i64().unwrap_or(0) != 0
        })
        .collect();
    assert_eq!(
        non_zero.len(),
        2,
        "both novels should appear with non-zero event_state: {novel_json:?}"
    );
    assert!(
        non_zero
            .iter()
            .all(|row| row["event_state"].as_i64() == Some(-1)),
        "event_state should expose fallback failures: {novel_json:?}"
    );

    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE numeric_id = $1)")
        .bind(project_numeric_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_numeric_id)
        .execute(&pool)
        .await;
}
