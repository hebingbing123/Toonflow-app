use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::storyboard_ops::ProductionStoryboardItem;

use super::super::types::StoryboardPreviewData;

pub(in crate::production::workbench::storyboard) async fn fetch_storyboard_item(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<ProductionStoryboardItem, ApiError> {
    sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.video_desc,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index,
          sb.metadata #>> '{voiceover,state}' AS voiceover_state,
          sb.metadata #>> '{voiceover,audioUrl}' AS voiceover_audio_url,
          sb.metadata #>> '{voiceover,error}' AS voiceover_error,
          ARRAY(
            SELECT jsonb_array_elements_text(
              COALESCE(sb.metadata #> '{shortVideo,liveAction,referenceShotUrls}', '[]'::jsonb)
            )
          ) AS live_action_reference_shot_urls,
          sb.metadata #>> '{shortVideo,liveAction,performanceNotes}' AS live_action_performance_notes,
          sb.metadata #>> '{shortVideo,lastWriteback,status}' AS short_video_writeback_status,
          sb.metadata #>> '{shortVideo,lastWriteback,at}' AS short_video_writeback_at,
          sb.metadata #>> '{shortVideo,lastWriteback,errorCode}' AS short_video_writeback_error_code,
          sb.metadata #>> '{shortVideo,export,artifactUrl}' AS short_video_export_artifact_url,
          sb.character_id,
          sb.metadata #> '{shortVideo}' AS short_video_metadata
        FROM app_storyboard sb
        WHERE sb.id = $1
        "#,
    )
    .bind(storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

pub(in crate::production::workbench::storyboard) async fn list_storyboard_items_by_script(
    pool: &sqlx::PgPool,
    script_id: Uuid,
) -> Result<Vec<ProductionStoryboardItem>, ApiError> {
    sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.video_desc,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index,
          sb.metadata #>> '{voiceover,state}' AS voiceover_state,
          sb.metadata #>> '{voiceover,audioUrl}' AS voiceover_audio_url,
          sb.metadata #>> '{voiceover,error}' AS voiceover_error,
          ARRAY(
            SELECT jsonb_array_elements_text(
              COALESCE(sb.metadata #> '{shortVideo,liveAction,referenceShotUrls}', '[]'::jsonb)
            )
          ) AS live_action_reference_shot_urls,
          sb.metadata #>> '{shortVideo,liveAction,performanceNotes}' AS live_action_performance_notes,
          sb.metadata #>> '{shortVideo,lastWriteback,status}' AS short_video_writeback_status,
          sb.metadata #>> '{shortVideo,lastWriteback,at}' AS short_video_writeback_at,
          sb.metadata #>> '{shortVideo,lastWriteback,errorCode}' AS short_video_writeback_error_code,
          sb.metadata #>> '{shortVideo,export,artifactUrl}' AS short_video_export_artifact_url,
          sb.character_id,
          sb.metadata #> '{shortVideo}' AS short_video_metadata
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC
        "#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(in crate::production::workbench::storyboard) async fn fetch_storyboard_preview_data(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<StoryboardPreviewData, ApiError> {
    let (file_path, prompt): (Option<String>, Option<String>) =
        sqlx::query_as(r#"SELECT file_path, prompt FROM app_storyboard WHERE id = $1"#)
            .bind(storyboard_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StoryboardPreviewData { file_path, prompt })
}
