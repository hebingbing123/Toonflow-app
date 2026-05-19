use base64::Engine;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use super::super::common::download_image_bytes_capped;
use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::asset_image::production::grid_split::{
    split_grid_image_bytes, validate_grid_dimensions,
};
use crate::jobs::worker::common::{generation_job_is_cancelled, JobRunError};
use crate::jobs::JobRow;
use crate::llm::{
    images_generation_or_edit_url, resolve_openai_image_model, resolve_openai_image_size, LlmConfig,
};
use crate::state::AppState;

use super::super::common::payload_json_i32;

const MAX_DATA_URI_BYTES: usize = 600_000;

struct StoryboardShotPrompt {
    numeric_id: i32,
    prompt: String,
}

pub(crate) async fn run_production_storyboard_grid_generate_and_assign(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
    cfg: &LlmConfig,
    p: &Value,
) -> Result<serde_json::Value, JobRunError> {
    if generation_job_is_cancelled(pool, job_id).await? {
        return Err(JobRunError::Cancelled);
    }

    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, p).await?;
    let script_numeric_id = payload_json_i32(p, "script_id")?;
    let rows = payload_json_u32(p, "rows")?;
    let cols = payload_json_u32(p, "cols")?;
    let storyboard_numeric_ids = payload_storyboard_numeric_ids(p)?;
    validate_grid_dimensions(rows, cols, storyboard_numeric_ids.len())?;

    let model_in = p
        .get("model")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model".into()))?;
    let resolution = p
        .get("resolution")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing resolution".into()))?;

    let shots = fetch_storyboard_prompts(
        pool,
        row.owner_user_id,
        project_numeric_id,
        script_numeric_id,
        &storyboard_numeric_ids,
    )
    .await?;

    let base_prompt = p
        .get("base_prompt")
        .and_then(|x| x.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let grid_prompt = build_grid_prompt(rows, cols, base_prompt, &shots);
    let image_model = resolve_openai_image_model(model_in);
    let size = resolve_openai_image_size(&image_model, resolution);

    let (grid_url, revised) = images_generation_or_edit_url(
        cfg,
        &state.http_client,
        image_model.as_str(),
        grid_prompt.as_str(),
        size,
        None,
    )
    .await
    .map_err(JobRunError::Failed)?;

    let grid_bytes = download_image_bytes_capped(&state.http_client, &grid_url).await?;
    let cells = split_grid_image_bytes(&grid_bytes, rows, cols)?;

    let mut assigned = Vec::with_capacity(shots.len());
    for (shot, cell_bytes) in shots.iter().zip(cells.iter()) {
        if generation_job_is_cancelled(pool, job_id).await? {
            return Err(JobRunError::Cancelled);
        }

        let file_path =
            persist_storyboard_cell(state, row.owner_user_id, shot.numeric_id, cell_bytes).await?;

        let sb_id: Uuid = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script s ON s.id = sb.script_id
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND s.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(row.owner_user_id)
        .bind(project_numeric_id)
        .bind(script_numeric_id)
        .bind(shot.numeric_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?
        .ok_or_else(|| JobRunError::Failed("storyboard not in scope".into()))?;

        sqlx::query(
            r#"
            UPDATE app_storyboard
            SET file_path = $2,
                state = '已完成',
                metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                    'gridAssign',
                    jsonb_build_object(
                        'jobId', $3::text,
                        'rows', $4::int,
                        'cols', $5::int,
                        'cellIndex', $6::int
                    )
                ),
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(sb_id)
        .bind(&file_path)
        .bind(job_id)
        .bind(rows as i32)
        .bind(cols as i32)
        .bind(assigned.len() as i32)
        .execute(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;

        assigned.push(json!({
            "storyboardNumericId": shot.numeric_id,
            "imageUrl": file_path,
        }));
    }

    let mut result = json!({
        "source": "production.storyboard.grid-generate-and-assign",
        "projectNumericId": project_numeric_id,
        "scriptNumericId": script_numeric_id,
        "rows": rows,
        "cols": cols,
        "gridImageUrl": grid_url,
        "revisedPrompt": revised,
        "assigned": assigned,
    });
    if let Some(project_uuid) = payload_project_uuid(p) {
        result["projectUuid"] = json!(project_uuid);
    }
    Ok(result)
}

fn payload_json_u32(p: &Value, key: &str) -> Result<u32, JobRunError> {
    let n = p
        .get(key)
        .and_then(|x| x.as_u64())
        .ok_or_else(|| JobRunError::Failed(format!("payload missing {key}")))?;
    u32::try_from(n).map_err(|_| JobRunError::Failed(format!("payload {key} out of range")))
}

fn payload_storyboard_numeric_ids(p: &Value) -> Result<Vec<i32>, JobRunError> {
    let raw = p
        .get("storyboard_numeric_ids")
        .and_then(|x| x.as_array())
        .ok_or_else(|| JobRunError::Failed("payload missing storyboard_numeric_ids".into()))?;
    let mut ids = Vec::with_capacity(raw.len());
    for item in raw {
        let n = item
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|&v| v > 0)
            .ok_or_else(|| JobRunError::Failed("invalid storyboard_numeric_ids entry".into()))?;
        ids.push(n);
    }
    Ok(ids)
}

async fn fetch_storyboard_prompts(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_ids: &[i32],
) -> Result<Vec<StoryboardShotPrompt>, JobRunError> {
    let rows: Vec<(i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT sb.numeric_id, sb.prompt
        FROM app_storyboard sb
        INNER JOIN app_script s ON s.id = sb.script_id
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
          )
          AND p.numeric_id = $2
          AND s.numeric_id = $3
          AND sb.numeric_id = ANY($4::int4[])
        ORDER BY sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
        "#,
    )
    .bind(owner_user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_numeric_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;

    if rows.len() != storyboard_numeric_ids.len() {
        return Err(JobRunError::Failed("storyboard not in scope".into()));
    }

    Ok(rows
        .into_iter()
        .map(|(numeric_id, prompt)| StoryboardShotPrompt {
            numeric_id,
            prompt: prompt.unwrap_or_default().trim().to_string(),
        })
        .collect())
}

fn build_grid_prompt(
    rows: u32,
    cols: u32,
    base_prompt: Option<&str>,
    shots: &[StoryboardShotPrompt],
) -> String {
    let mut lines = vec![format!(
        "Create ONE composite storyboard image with a {rows}x{cols} grid of equal panels, no thick borders, consistent style and lighting."
    )];
    lines.push("Read panels left-to-right, top-to-bottom.".into());
    for (index, shot) in shots.iter().enumerate() {
        let panel = index + 1;
        let detail = if shot.prompt.is_empty() {
            "cinematic storyboard frame".to_string()
        } else {
            shot.prompt.clone()
        };
        lines.push(format!("Panel {panel}: {detail}"));
    }
    if let Some(base) = base_prompt {
        lines.push(format!("Overall scene: {base}"));
    }
    lines.join("\n")
}

async fn persist_storyboard_cell(
    state: &AppState,
    owner_user_id: Uuid,
    storyboard_numeric_id: i32,
    bytes: &[u8],
) -> Result<String, JobRunError> {
    if let Some(root) = state.local_asset_image_dir.as_deref() {
        let rel = format!("storyboard-grid/{storyboard_numeric_id}.png");
        let user_dir = root.join(owner_user_id.to_string());
        tokio::fs::create_dir_all(&user_dir)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        let disk_path = user_dir.join(&rel);
        tokio::fs::write(&disk_path, bytes)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        return Ok(format!("/storyboard-local/{rel}"));
    }

    if bytes.len() > MAX_DATA_URI_BYTES {
        return Err(JobRunError::Failed(
            "grid cell too large without OPENFLOW_LOCAL_ASSET_IMAGE_DIR; configure local image storage or use fewer/larger grid cells"
                .into(),
        ));
    }
    let encoded = base64::engine::general_purpose::STANDARD.encode(bytes);
    Ok(format!("data:image/png;base64,{encoded}"))
}
