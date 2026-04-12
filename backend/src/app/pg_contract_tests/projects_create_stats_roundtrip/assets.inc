    {
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, script_row) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "script={script_row}");
            let script_leg = script_row["numeric_id"]
                .as_i64()
                .expect("script numeric_id") as i32;
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(
                            r#"{"name":"pg_contract_role_asset","type":"role"}"#,
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, asset_row) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
            let asset_leg = asset_row["numeric_id"].as_i64().expect("asset numeric_id") as i32;
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, one_asset) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "one_asset={one_asset}");
            assert_eq!(
                one_asset["numeric_id"].as_i64().expect("numeric_id"),
                i64::from(asset_leg)
            );
            assert_eq!(one_asset["name"].as_str(), Some("pg_contract_role_asset"));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner1) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "corner1={corner1}");
            let c1 = corner1["items"].as_array().expect("corner1 items");
            assert_eq!(c1.len(), 1);
            assert_eq!(
                c1[0]["numeric_id"].as_i64().expect("leg"),
                i64::from(asset_leg)
            );
            assert_eq!(c1[0]["asset_type"].as_str(), Some("role"));
            assert!(
                c1[0]["history_images"]
                    .as_array()
                    .is_some_and(|a| a.is_empty()),
                "history_images empty before app_asset_image row"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(
                            r#"{"file_path":"pg_contract/corner_hist.png","state":"已完成","sort_index":0}"#,
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, img_row) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "img_row={img_row}");
            assert_eq!(
                img_row["file_path"].as_str(),
                Some("pg_contract/corner_hist.png")
            );
            assert_eq!(img_row["state"].as_str(), Some("已完成"));
        
            let img_uuid = img_row["id"].as_str().expect("image id");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, list_img) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "list_img={list_img}");
            assert!(
                list_img["cover_numeric_image_id"].is_null(),
                "API-created asset has no metadata.imageId cover"
            );
            let lim = list_img["items"].as_array().expect("image list items");
            assert_eq!(lim.len(), 1);
            assert_eq!(lim[0]["id"].as_str(), Some(img_uuid));
            assert_eq!(lim[0]["selected"], false);
            assert!(
                lim[0]["numeric_image_id"].is_null(),
                "API-created image has no numeric_image_id"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/workbench/image-bundle"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(format!(r#"{{"assetsId":{asset_leg}}}"#)))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, workbench_get_image) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "workbench_get_image={workbench_get_image}"
            );
            assert_eq!(
                workbench_get_image["id"].as_i64(),
                Some(i64::from(asset_leg))
            );
            assert!(workbench_get_image["imageId"].is_null());
            let workbench_temp_assets = workbench_get_image["tempAssets"]
                .as_array()
                .expect("workbench get-image tempAssets");
            assert_eq!(workbench_temp_assets.len(), 1);
            assert_eq!(
                workbench_temp_assets[0]["assetsId"].as_i64(),
                Some(i64::from(asset_leg))
            );
            assert_eq!(workbench_temp_assets[0]["selected"], false);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, one_img) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "one_img={one_img}");
            assert_eq!(one_img["id"].as_str(), Some(img_uuid));
            assert_eq!(
                one_img["file_path"].as_str(),
                Some("pg_contract/corner_hist.png")
            );
            assert_eq!(one_img["state"].as_str(), Some("已完成"));
            assert!(one_img["numeric_image_id"].is_null());
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PATCH)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"cover_numeric_image_id":424242}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, bad_cov) = read_json_response(res).await;
            assert_eq!(status, StatusCode::BAD_REQUEST, "bad_cov={bad_cov}");
            assert_eq!(bad_cov["code"].as_str(), Some("bad_request"));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner1_hist) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "corner1_hist={corner1_hist}");
            let c1h = corner1_hist["items"]
                .as_array()
                .expect("corner1_hist items");
            assert_eq!(c1h.len(), 1);
            let hi = c1h[0]["history_images"].as_array().expect("history");
            assert_eq!(hi.len(), 1);
            assert_eq!(
                hi[0]["file_path"].as_str(),
                Some("pg_contract/corner_hist.png")
            );
            assert_eq!(hi[0]["state"].as_str(), Some("已完成"));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PATCH)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"state":""}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, patched) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "patched={patched}");
            assert!(patched["state"].is_null());
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_no_hist) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "corner_no_hist={corner_no_hist}");
            let cn = corner_no_hist["items"].as_array().expect("items");
            assert_eq!(cn.len(), 1);
            assert!(
                cn[0]["history_images"]
                    .as_array()
                    .is_some_and(|a| a.is_empty()),
                "NULL state excludes row from corner-scape history"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PATCH)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_uuid}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"state":"已完成"}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, restored) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "restored={restored}");
            assert_eq!(restored["state"].as_str(), Some("已完成"));
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(
                            r#"{"name":"pg_contract_scene_asset","type":"scene"}"#,
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, scene_row) = read_json_response(res).await;
            assert_eq!(status, StatusCode::CREATED, "scene_row={scene_row}");
            let scene_leg = scene_row["numeric_id"].as_i64().expect("scene numeric_id") as i32;
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner2) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "corner2={corner2}");
            let c2 = corner2["items"].as_array().expect("corner2 items");
            assert_eq!(c2.len(), 2);
            assert_eq!(c2[0]["asset_type"].as_str(), Some("role"));
            assert_eq!(c2[1]["asset_type"].as_str(), Some("scene"));
            assert_eq!(c2[0]["history_images"].as_array().map(|a| a.len()), Some(1));
            assert!(
                c2[1]["history_images"]
                    .as_array()
                    .is_some_and(|a| a.is_empty()),
                "scene has no history row"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"types":["scene"]}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_scene_only) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "corner_scene_only={corner_scene_only}"
            );
            let cs = corner_scene_only["items"]
                .as_array()
                .expect("corner scene filter");
            assert_eq!(cs.len(), 1);
            assert_eq!(
                cs[0]["numeric_id"].as_i64().expect("leg"),
                i64::from(scene_leg)
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"types":["scene"," SCENE ","scene",""]}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_scene_dedup) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "corner_scene_dedup={corner_scene_dedup}"
            );
            let csd = corner_scene_dedup["items"]
                .as_array()
                .expect("corner scene dedup filter");
            assert_eq!(csd.len(), 1);
            assert_eq!(
                csd[0]["numeric_id"].as_i64().expect("leg"),
                i64::from(scene_leg)
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from(r#"{"types":[" ","\n\t",""]}"#))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_blank_types) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "corner_blank_types={corner_blank_types}"
            );
            assert_eq!(
                corner_blank_types["items"].as_array().map(|a| a.len()),
                Some(2),
                "blank-only types should behave like no filter"
            );
        
            let n = sqlx::query(
                r#"
                UPDATE app_asset a
                SET metadata = jsonb_build_object('assetsId', 999999)
                FROM app_project p
                WHERE a.project_id = p.id
                  AND p.numeric_id = $1
                  AND p.owner_user_id = $2
                  AND a.numeric_id = $3
                "#,
            )
            .bind(numeric_id)
            .bind(sub)
            .bind(scene_leg)
            .execute(&pool_sql)
            .await
            .expect("mark scene row as child asset via metadata.assetsId");
            assert_eq!(n.rows_affected(), 1, "expected one scene row updated");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_child_hidden) = read_json_response(res).await;
            assert_eq!(
                status,
                StatusCode::OK,
                "corner_child_hidden={corner_child_hidden}"
            );
            let ch = corner_child_hidden["items"]
                .as_array()
                .expect("corner after child metadata");
            assert_eq!(ch.len(), 1);
            assert_eq!(
                ch[0]["numeric_id"].as_i64().expect("leg"),
                i64::from(asset_leg)
            );
            assert_eq!(ch[0]["history_images"].as_array().map(|a| a.len()), Some(1));
        
            let n = sqlx::query(
                r#"
                UPDATE app_asset a
                SET metadata = '{}'::jsonb
                FROM app_project p
                WHERE a.project_id = p.id
                  AND p.numeric_id = $1
                  AND p.owner_user_id = $2
                  AND a.numeric_id = $3
                "#,
            )
            .bind(numeric_id)
            .bind(sub)
            .bind(scene_leg)
            .execute(&pool_sql)
            .await
            .expect("reset scene metadata");
            assert_eq!(n.rows_affected(), 1);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::POST)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets/corner-scape"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .header(header::CONTENT_TYPE, "application/json")
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::from("{}"))
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, corner_restored) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "corner_restored={corner_restored}");
            assert_eq!(
                corner_restored["items"].as_array().map(|a| a.len()),
                Some(2)
            );
            let cr = corner_restored["items"]
                .as_array()
                .expect("corner restored items");
            assert_eq!(cr[0]["history_images"].as_array().map(|a| a.len()), Some(1));
        
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
            let (status, stats_mid) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "stats_mid={stats_mid}");
            assert_eq!(stats_mid["script_count"], 1);
            assert_eq!(stats_mid["storyboard_count"], 0);
            assert_eq!(stats_mid["role_count"], 1);
            assert_eq!(stats_mid["novel_count"], 0);
            assert_eq!(stats_mid["video_count"], 0);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri("/api/v1/projects/summary")
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, sum_mid) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "sum_mid={sum_mid}");
            assert_eq!(sum_mid["video_count"], 0);
            let g_role = sum_mid["role_count"].as_i64().expect("summary role_count");
            let p_role = stats_mid["role_count"].as_i64().expect("stats role_count");
            assert!(
                g_role >= p_role,
                "projects/summary role_count ({g_role}) should be >= per-project stats ({p_role})"
            );
            let g_script = sum_mid["script_count"]
                .as_i64()
                .expect("summary script_count");
            let p_script = stats_mid["script_count"]
                .as_i64()
                .expect("stats script_count");
            assert!(
                g_script >= p_script,
                "projects/summary script_count ({g_script}) should be >= per-project stats ({p_script})"
            );
            let g_asset = sum_mid["asset_count"]
                .as_i64()
                .expect("summary asset_count");
            assert!(
                g_asset >= 1,
                "expected at least one app_asset row in summary"
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets?asset_type=role&name=pg_contract"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, by_type_name) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "by_type_name={by_type_name}");
            assert_eq!(by_type_name["total"], 1);
            let items = by_type_name["items"].as_array().expect("items");
            assert_eq!(items.len(), 1);
            assert_eq!(
                items[0]["numeric_id"].as_i64().expect("numeric_id"),
                i64::from(asset_leg)
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets?asset_type=tool&name=pg_contract"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, wrong_type) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "wrong_type={wrong_type}");
            assert_eq!(wrong_type["total"], 0);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets?script_numeric_id={script_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, linked_before) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "linked_before={linked_before}");
            assert_eq!(linked_before["total"], 0);
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::PUT)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/scripts/{script_leg}/assets/{asset_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, empty_put) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NO_CONTENT, "put body={empty_put}");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets?script_numeric_id={script_leg}&limit=10&page=1"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, linked_after) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "linked_after={linked_after}");
            assert_eq!(linked_after["total"], 1);
            assert_eq!(
                linked_after["items"]
                    .as_array()
                    .map(|a| a.len())
                    .unwrap_or(0),
                1
            );
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .method(Method::DELETE)
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/scripts/{script_leg}/assets/{asset_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, empty_unlink) = read_json_response(res).await;
            assert_eq!(status, StatusCode::NO_CONTENT, "unlink={empty_unlink}");
        
            let res = app
                .clone()
                .oneshot(
                    Request::builder()
                        .uri(format!(
                            "/api/v1/projects/{project_uuid}/assets?script_numeric_id={script_leg}"
                        ))
                        .header(header::AUTHORIZATION, format!("Bearer {token}"))
                        .extension(ConnectInfo(test_addr()))
                        .body(Body::empty())
                        .unwrap(),
                )
                .await
                .unwrap();
            let (status, unlinked) = read_json_response(res).await;
            assert_eq!(status, StatusCode::OK, "unlinked={unlinked}");
            assert_eq!(unlinked["total"], 0);
    }
