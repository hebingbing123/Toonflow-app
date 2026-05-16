use super::assert_database_error;

#[tokio::test]
async fn production_get_flow_data_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/get-flow-data",
        r#"{"projectId":1,"episodesId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_save_flow_data_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/save-flow-data",
        r#"{"projectId":1,"episodesId":1,"data":{}}"#,
    )
    .await;
}

#[tokio::test]
async fn production_workbench_generate_video_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/workbench/generate-video",
        r#"{"projectId":1,"scriptId":1,"uploadData":[{"id":1,"sources":"assets"}],"prompt":"p","model":"1:x","mode":"std","resolution":"720p","duration":5,"trackId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_workbench_batch_generate_candidate_clips_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/workbench/batch-generate-candidate-clips",
        r#"{"projectId":1,"scriptId":1}"#,
    )
    .await;
}

#[tokio::test]
async fn production_export_image_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/export-image",
        r#"{"projectId":1,"scriptId":1,"shotId":[{"id":"1"}]}"#,
    )
    .await;
}

#[tokio::test]
async fn production_workbench_storyboard_media_op_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/production/workbench/storyboard-media-op",
        r#"{"op":"selectVideo","projectId":1,"scriptId":1,"storyboardId":1,"videoUrl":"https://example.com/p.mp4"}"#,
    )
    .await;
}
