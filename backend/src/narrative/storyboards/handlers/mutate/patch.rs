//! 分镜行 JSON Patch 合并与 UPDATE。

use axum::Json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::http_kit::json_patch::{
    parse_optional_i32_field, parse_optional_text_field, FieldPatch,
};

use super::super::super::dto::{PatchStoryboardBody, StoryboardRow};
use super::super::common::{fetch_storyboard_row, resolve_owned_storyboard_id};

pub(super) async fn patch_storyboard_row(
    pool: &PgPool,
    uid: Uuid,
    numeric_id: i32,
    body: PatchStoryboardBody,
    project_id: Uuid,
) -> Result<Json<StoryboardRow>, ApiError> {
    let p_prompt = parse_optional_text_field(body.prompt, "prompt")?;
    let p_file = parse_optional_text_field(body.file_path, "file_path")?;
    let p_dur = parse_optional_text_field(body.duration, "duration")?;
    let p_state = parse_optional_text_field(body.state, "state")?;
    let p_reason = parse_optional_text_field(body.reason, "reason")?;
    let p_track = parse_optional_text_field(body.track, "track")?;
    let p_video = parse_optional_text_field(body.video_desc, "video_desc")?;
    let p_lsid = parse_optional_i32_field(body.numeric_script_id, "numeric_script_id")?;
    let p_tid = parse_optional_i32_field(body.track_id, "track_id")?;
    let p_sgi = parse_optional_i32_field(body.should_generate_image, "should_generate_image")?;
    let p_lpid = parse_optional_i32_field(body.numeric_project_id, "numeric_project_id")?;
    let p_fid = parse_optional_i32_field(body.flow_id, "flow_id")?;
    let p_sbi = parse_optional_i32_field(body.sb_index, "sb_index")?;

    if matches!(p_prompt, FieldPatch::Absent)
        && matches!(p_file, FieldPatch::Absent)
        && matches!(p_dur, FieldPatch::Absent)
        && matches!(p_state, FieldPatch::Absent)
        && matches!(p_reason, FieldPatch::Absent)
        && matches!(p_track, FieldPatch::Absent)
        && matches!(p_video, FieldPatch::Absent)
        && matches!(p_lsid, FieldPatch::Absent)
        && matches!(p_tid, FieldPatch::Absent)
        && matches!(p_sgi, FieldPatch::Absent)
        && matches!(p_lpid, FieldPatch::Absent)
        && matches!(p_fid, FieldPatch::Absent)
        && matches!(p_sbi, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field".into(),
        ));
    }

    let storyboard_id = resolve_owned_storyboard_id(pool, uid, project_id, numeric_id).await?;
    let current = fetch_storyboard_row(pool, storyboard_id).await?;

    let merge_t = |patch: &FieldPatch<String>, cur: &Option<String>| -> Option<String> {
        match patch {
            FieldPatch::Absent => cur.clone(),
            FieldPatch::Set(v) => v.clone(),
        }
    };
    let merge_i = |patch: &FieldPatch<i32>, cur: Option<i32>| -> Option<i32> {
        match patch {
            FieldPatch::Absent => cur,
            FieldPatch::Set(v) => *v,
        }
    };

    let new_prompt = merge_t(&p_prompt, &current.prompt);
    let new_file = merge_t(&p_file, &current.file_path);
    let new_dur = merge_t(&p_dur, &current.duration);
    let new_state = merge_t(&p_state, &current.state);
    let new_reason = merge_t(&p_reason, &current.reason);
    let new_track = merge_t(&p_track, &current.track);
    let new_video = merge_t(&p_video, &current.video_desc);
    let new_lsid = merge_i(&p_lsid, current.numeric_script_id);
    let new_tid = merge_i(&p_tid, current.track_id);
    let new_sgi = merge_i(&p_sgi, current.should_generate_image);
    let new_lpid = merge_i(&p_lpid, current.numeric_project_id);
    let new_fid = merge_i(&p_fid, current.flow_id);
    let new_sbi = merge_i(&p_sbi, current.sb_index);

    let row = sqlx::query_as::<_, StoryboardRow>(
        r#"
        UPDATE app_storyboard
        SET
          prompt = $1,
          file_path = $2,
          duration = $3,
          state = $4,
          reason = $5,
          track = $6,
          video_desc = $7,
          numeric_script_id = $8,
          track_id = $9,
          should_generate_image = $10,
          numeric_project_id = $11,
          flow_id = $12,
          sb_index = $13,
          updated_at = NOW()
        WHERE id = $14
        RETURNING
          id, script_id, numeric_id, numeric_script_id, prompt, file_path,
          duration, state, track_id, reason, track, video_desc,
          should_generate_image, numeric_project_id, flow_id, sb_index, create_time_ms
        "#,
    )
    .bind(&new_prompt)
    .bind(&new_file)
    .bind(&new_dur)
    .bind(&new_state)
    .bind(&new_reason)
    .bind(&new_track)
    .bind(&new_video)
    .bind(new_lsid)
    .bind(new_tid)
    .bind(new_sgi)
    .bind(new_lpid)
    .bind(new_fid)
    .bind(new_sbi)
    .bind(current.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}
