    {
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"chapter":"pg_contract_chap"}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, novel_row) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "novel_row={novel_row}");
            let novel_leg = novel_row["numeric_id"].as_i64().expect("novel numeric_id") as i32;
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, stats_with_novel) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "stats_with_novel={stats_with_novel}"
            );
            assert_eq!(stats_with_novel["novel_count"], 1);
            assert_eq!(stats_with_novel["role_count"], 1);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?search=pg_contract&page=1&limit=10"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, novel_list) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "novel_list={novel_list}");
            assert!(novel_list["total"].as_i64().unwrap_or(0) >= 1);
        
            // REST `GET/POST/PATCH/DELETE …/projects/{uuid}/novels*` parity on the same rows.
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?page=1&limit=200"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, list_all) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "list_all={list_all}");
            let rows = list_all["items"].as_array().expect("novel items");
            assert!(
                rows.iter()
                    .any(|r| r["numeric_id"].as_i64() == Some(i64::from(novel_leg))),
                "expected novel numeric_id in list: {list_all}"
            );
            assert!(
                rows.iter().any(|r| {
                    r["numeric_id"].as_i64() == Some(i64::from(novel_leg))
                        && r["chapter_index"].is_number()
                        && r["chapter"].is_string()
                }),
                "expected index/chapter fields (get-novel-index shape): {list_all}"
            );
        
            let non_zero: Vec<&serde_json::Value> = rows
                .iter()
                .filter(|r| {
                    r["numeric_id"].as_i64() == Some(i64::from(novel_leg))
                        && r["event_state"].as_i64().unwrap_or(0) != 0
                })
                .collect();
            assert!(
                non_zero.is_empty(),
                "fresh novels should not expose non-zero event_state: {list_all}"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, get_pg) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "get_novel={get_pg}");
            assert_eq!(get_pg["total"].as_i64(), Some(1));
            let page_rows = get_pg["items"].as_array().expect("paged items");
            assert_eq!(
                page_rows[0]["numeric_id"].as_i64(),
                Some(i64::from(novel_leg))
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(
                            r#"{"chapter_index":99,"reel":"lr","chapter":"pg_novel_add_chapter","chapter_data":"d0"}"#,
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, _) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "add novel via REST");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, two_rows) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "two_rows={two_rows}");
            assert_eq!(two_rows["total"].as_i64(), Some(2));
            let added_leg = two_rows["items"]
                .as_array()
                .expect("items")
                .iter()
                .find(|r| r["chapter"].as_str() == Some("pg_novel_add_chapter"))
                .expect("added chapter row")["numeric_id"]
                .as_i64()
                .expect("added numeric id") as i32;
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PATCH)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{added_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(
                            r#"{"chapter":"pg_novel_patched","chapter_data":"d1","reel":"","event":""}"#,
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, _) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "patch novel");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?search=pg_novel_pat&page=1&limit=10"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, search_pg) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "search_novel={search_pg}");
            assert!(search_pg["total"].as_i64().unwrap_or(0) >= 1);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::DELETE)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{added_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            assert_eq!(res.status(), StatusCode::NO_CONTENT, "delete novel");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels?page=1&limit=10"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, one_again) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "one_again={one_again}");
            assert_eq!(one_again["total"].as_i64(), Some(1));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, one_novel) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "one_novel={one_novel}");
            assert_eq!(one_novel["chapter"].as_str(), Some("pg_contract_chap"));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PATCH)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"chapter":"pg_contract_patched"}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, patched_novel) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "patched={patched_novel}");
            assert_eq!(
                patched_novel["chapter"].as_str(),
                Some("pg_contract_patched")
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::DELETE)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, del_novel) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NO_CONTENT, "del_novel={del_novel}");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, stats_no_novel) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "stats_no_novel={stats_no_novel}");
            assert_eq!(stats_no_novel["novel_count"], 0);
            assert_eq!(stats_no_novel["role_count"], 1);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/novels/{novel_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, novel_gone) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NOT_FOUND, "novel_gone={novel_gone}");
        
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
            let (status, empty) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NO_CONTENT, "body={empty}");
        
            let res = app
                .oneshot(
                    Request::builder()
                        .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, err) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NOT_FOUND, "err={err}");
    }
