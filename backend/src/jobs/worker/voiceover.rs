use std::collections::HashMap;
use std::path::Path;

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::JobRunError;
use crate::jobs::JobRow;
use crate::llm::LlmConfig;
use crate::settings::agent_deploy::load_agent_deploy_config;
use crate::short_video::voice::{
    parse_dialogue_segments, resolve_tts_voice_name, resolve_voice_config,
    scene_context_from_metadata, synthesize_speech, VoiceResolveInput,
};
use crate::state::AppState;
use crate::vendor::catalog::lookup_vendor_catalog;
use crate::vendor::credential::decrypt;

const DEFAULT_SPEED: f32 = 1.0;

#[derive(Debug, sqlx::FromRow)]
struct StoryboardVoiceoverSeedRow {
    prompt: Option<String>,
    video_desc: Option<String>,
    character_id: Option<Uuid>,
    metadata: Value,
}

#[derive(Debug, sqlx::FromRow)]
struct VendorCredentialRow {
    api_key_encrypted: Option<Vec<u8>>,
    api_secret_encrypted: Option<Vec<u8>>,
    api_token_encrypted: Option<Vec<u8>>,
}

pub(crate) async fn run_voiceover_generate(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<Value, JobRunError> {
    let payload = &row.payload;
    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, payload).await?;
    let script_numeric_id = payload_json_i32(payload, "script_numeric_id")?;
    let storyboard_numeric_id = payload_json_i32(payload, "storyboard_numeric_id")?;
    let storyboard_id = load_storyboard_uuid(
        pool,
        row.owner_user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await?;

    let project_voice_profile =
        load_project_voice_profile(pool, row.owner_user_id, project_numeric_id).await?;

    let process = async {
        let seed = load_storyboard_seed(pool, storyboard_id).await?;
        let narration_text = resolve_narration_text(&seed).ok_or_else(|| {
            JobRunError::Failed(
                "storyboard has neither explicit narration nor prompt fallback for voiceover"
                    .into(),
            )
        })?;

        let character_voice = if let Some(character_id) = seed.character_id {
            load_character_voice_config(pool, character_id).await?
        } else {
            None
        };
        let scene = scene_context_from_metadata(&seed.metadata);
        let mut voice_cfg = resolve_voice_config(VoiceResolveInput {
            project_voice_profile: project_voice_profile.as_deref(),
            character_voice_config: character_voice.as_ref(),
            explicit_voice: payload.get("voice").and_then(|v| v.as_str()),
            explicit_emotion: payload.get("emotion").and_then(|v| v.as_str()),
            explicit_speed: payload
                .get("speed")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .filter(|v| *v >= 0.25 && *v <= 4.0),
            explicit_provider: payload
                .get("provider")
                .and_then(|v| v.as_str())
                .or_else(|| payload.get("vendor_id").and_then(|v| v.as_str())),
            scene,
        });
        if payload.get("multi_track").and_then(|v| v.as_bool()) == Some(true) {
            voice_cfg.multi_track = true;
        }
        let voice = resolve_tts_voice_name(&voice_cfg);

        let openai_cfg = load_tts_llm_config_for_user(state, pool, row.owner_user_id).await?;
        let root = state.local_voiceover_audio_dir.as_ref().ok_or_else(|| {
            JobRunError::Failed(
                "TOONFLOW_LOCAL_VOICEOVER_AUDIO_DIR is not set; cannot persist voiceover artifact"
                    .into(),
            )
        })?;

        let multi_track =
            voice_cfg.multi_track && parse_dialogue_segments(&narration_text).len() > 1;
        let speaker_voice_map = if multi_track {
            load_project_character_voices_by_speaker_name(
                pool,
                payload_project_uuid(payload),
                project_numeric_id,
            )
            .await?
        } else {
            HashMap::new()
        };
        let (file_name, relative_api_url, audio_meta) = if multi_track {
            synthesize_multi_track_audio(MultiTrackSynthesisContext {
                openai_cfg: &openai_cfg,
                state,
                root,
                owner_user_id: row.owner_user_id,
                job_id,
                narration_text: &narration_text,
                base_cfg: &voice_cfg,
                character_voice: &character_voice,
                speaker_voice_map: &speaker_voice_map,
                project_voice_profile: project_voice_profile.as_deref(),
                metadata: &seed.metadata,
            })
            .await?
        } else {
            let synthesis = synthesize_speech(
                &openai_cfg,
                &state.http_client,
                &narration_text,
                &voice_cfg,
                None,
            )
            .await
            .map_err(JobRunError::Failed)?;
            let file_name = format!("{job_id}.mp3");
            let relative_api_url = format!("/api/v1/jobs/{job_id}/file");
            persist_voiceover_audio(root, row.owner_user_id, &file_name, &synthesis.audio).await?;
            (
                file_name,
                relative_api_url,
                json!({
                    "voice": voice,
                    "speed": voice_cfg.speed.unwrap_or(DEFAULT_SPEED),
                    "model": synthesis.model,
                    "provider": synthesis.provider.as_str(),
                    "emotion": voice_cfg.emotion,
                    "style": voice_cfg.style,
                }),
            )
        };

        persist_storyboard_voiceover_metadata(
            pool,
            storyboard_id,
            &json!({
                "state": "completed",
                "audioUrl": relative_api_url,
                "fileName": file_name,
                "contentType": "audio/mpeg",
                "voice": voice,
                "speed": voice_cfg.speed.unwrap_or(DEFAULT_SPEED),
                "model": audio_meta.get("model").cloned().unwrap_or(json!(openai_cfg.model)),
                "provider": audio_meta.get("provider").cloned(),
                "emotion": voice_cfg.emotion,
                "style": voice_cfg.style,
                "multiTrack": multi_track,
                "tracks": audio_meta.get("tracks").cloned(),
                "vendorId": payload.get("vendor_id").and_then(|value| value.as_str()),
                "updatedAt": chrono::Utc::now().to_rfc3339(),
                "sourceText": narration_text,
                "error": null,
            }),
        )
        .await?;

        let mut result = json!({
            "source": "voiceover.generate",
            "storyboard_numeric_id": storyboard_numeric_id,
            "project_numeric_id": project_numeric_id,
            "script_numeric_id": script_numeric_id,
            "audio_url": relative_api_url,
            "storage": "local",
            "file_name": file_name,
            "content_type": "audio/mpeg",
            "voice": voice,
            "speed": voice_cfg.speed.unwrap_or(DEFAULT_SPEED),
            "model": audio_meta.get("model").cloned().unwrap_or(json!(openai_cfg.model)),
            "text": narration_text,
            "multi_track": multi_track,
        });
        if let Some(project_uuid) = payload_project_uuid(payload) {
            result["project_uuid"] = json!(project_uuid);
        }
        Ok(result)
    }
    .await;

    match process {
        Ok(result) => Ok(result),
        Err(err) => {
            let error_message = match &err {
                JobRunError::Failed(message) => message.clone(),
                JobRunError::FailedStructured { message, .. } => message.clone(),
                JobRunError::Cancelled => "voiceover generation cancelled".to_string(),
            };
            let _ = persist_storyboard_voiceover_metadata(
                pool,
                storyboard_id,
                &json!({
                    "state": "failed",
                    "error": error_message,
                    "updatedAt": chrono::Utc::now().to_rfc3339(),
                }),
            )
            .await;
            Err(err)
        }
    }
}

async fn load_project_voice_profile(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
) -> Result<Option<String>, JobRunError> {
    let row = sqlx::query_scalar::<_, Option<String>>(
        r#"
        SELECT voice_profile
        FROM app_project
        WHERE numeric_id = $2
          AND EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = app_project.workspace_id
                  AND wm.user_id = $1
          )
        "#,
    )
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;

    Ok(row.unwrap_or_default())
}

fn payload_json_i32(payload: &Value, key: &str) -> Result<i32, JobRunError> {
    payload
        .get(key)
        .and_then(|value| value.as_i64())
        .and_then(|value| i32::try_from(value).ok())
        .ok_or_else(|| JobRunError::Failed(format!("payload missing {key}")))
}

async fn load_storyboard_uuid(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<Uuid, JobRunError> {
    sqlx::query_scalar(
        r#"
        SELECT sb.id
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE EXISTS (
                SELECT 1
                FROM app_workspace_member wm
                WHERE wm.workspace_id = p.workspace_id
                  AND wm.user_id = $1
          )
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = $4
        "#,
    )
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| JobRunError::Failed("storyboard not found in workspace member scope".into()))
}

async fn load_project_character_voices_by_speaker_name(
    pool: &PgPool,
    project_uuid: Option<Uuid>,
    project_numeric_id: i32,
) -> Result<HashMap<String, Value>, JobRunError> {
    let project_id = if let Some(id) = project_uuid {
        id
    } else {
        sqlx::query_scalar("SELECT id FROM app_project WHERE numeric_id = $1")
            .bind(project_numeric_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?
            .ok_or_else(|| JobRunError::Failed("project not found for voice map".into()))?
    };
    let rows: Vec<(String, Value)> = sqlx::query_as(
        r#"
        SELECT LOWER(TRIM(name)) AS name, voice_config
        FROM app_project_character
        WHERE project_id = $1
          AND TRIM(name) <> ''
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;
    Ok(rows.into_iter().collect())
}

async fn load_character_voice_config(
    pool: &PgPool,
    character_id: Uuid,
) -> Result<Option<Value>, JobRunError> {
    sqlx::query_scalar("SELECT voice_config FROM app_project_character WHERE id = $1")
        .bind(character_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))
}

struct MultiTrackSynthesisContext<'a> {
    openai_cfg: &'a LlmConfig,
    state: &'a AppState,
    root: &'a Path,
    owner_user_id: Uuid,
    job_id: Uuid,
    narration_text: &'a str,
    base_cfg: &'a crate::short_video::voice::VoiceProfileConfig,
    character_voice: &'a Option<Value>,
    speaker_voice_map: &'a HashMap<String, Value>,
    project_voice_profile: Option<&'a str>,
    metadata: &'a Value,
}

async fn synthesize_multi_track_audio(
    ctx: MultiTrackSynthesisContext<'_>,
) -> Result<(String, String, Value), JobRunError> {
    let MultiTrackSynthesisContext {
        openai_cfg,
        state,
        root,
        owner_user_id,
        job_id,
        narration_text,
        base_cfg,
        character_voice,
        speaker_voice_map,
        project_voice_profile,
        metadata,
    } = ctx;
    let segments = parse_dialogue_segments(narration_text);
    let scene = scene_context_from_metadata(metadata);
    let mut tracks = Vec::new();
    let mut primary_audio: Option<Vec<u8>> = None;
    for (index, segment) in segments.iter().enumerate() {
        let speaker_key = segment.speaker.trim().to_lowercase();
        let speaker_voice = (!speaker_key.is_empty())
            .then(|| speaker_voice_map.get(&speaker_key))
            .flatten();
        let segment_cfg = resolve_voice_config(VoiceResolveInput {
            project_voice_profile,
            character_voice_config: speaker_voice.or(character_voice.as_ref()),
            explicit_voice: None,
            explicit_emotion: base_cfg.emotion.as_deref(),
            explicit_speed: base_cfg.speed,
            explicit_provider: Some(base_cfg.provider.as_str()),
            scene: scene.clone(),
        });
        let synthesis = synthesize_speech(
            openai_cfg,
            &state.http_client,
            &segment.text,
            &segment_cfg,
            None,
        )
        .await
        .map_err(JobRunError::Failed)?;
        let track_file = format!("{job_id}_track_{index}.mp3");
        persist_voiceover_audio(root, owner_user_id, &track_file, &synthesis.audio).await?;
        if index == 0 {
            primary_audio = Some(synthesis.audio);
        }
        tracks.push(json!({
            "speaker": segment.speaker,
            "text": segment.text,
            "fileName": track_file,
            "voice": segment_cfg.voice,
            "provider": synthesis.provider.as_str(),
        }));
    }
    let file_name = format!("{job_id}.mp3");
    let relative_api_url = format!("/api/v1/jobs/{job_id}/file");
    persist_voiceover_audio(
        root,
        owner_user_id,
        &file_name,
        primary_audio.as_deref().unwrap_or(&[]),
    )
    .await?;
    Ok((
        file_name,
        relative_api_url,
        json!({
            "model": openai_cfg.model,
            "provider": base_cfg.provider.as_str(),
            "tracks": tracks,
        }),
    ))
}

async fn load_storyboard_seed(
    pool: &PgPool,
    storyboard_id: Uuid,
) -> Result<StoryboardVoiceoverSeedRow, JobRunError> {
    sqlx::query_as(
        r#"
        SELECT prompt, video_desc, character_id, COALESCE(metadata, '{}'::jsonb) AS metadata
        FROM app_storyboard
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .fetch_one(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))
}

fn resolve_narration_text(seed: &StoryboardVoiceoverSeedRow) -> Option<String> {
    seed.video_desc
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .or_else(|| {
            seed.prompt
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string)
        })
}

pub(crate) async fn load_tts_llm_config_for_user(
    state: &AppState,
    pool: &PgPool,
    owner_user_id: Uuid,
) -> Result<LlmConfig, JobRunError> {
    let cfg = load_agent_deploy_config(pool, owner_user_id)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    let tts = cfg
        .rows
        .get("ttsDubbing")
        .ok_or_else(|| JobRunError::Failed("ttsDubbing model is not configured".into()))?;
    let model = tts.model.trim();
    if model.is_empty() {
        return Err(JobRunError::Failed(
            "ttsDubbing model is configured with an empty model value".into(),
        ));
    }

    let vendor_secret = if let Some(vendor_id) = tts.vendor_id.as_deref() {
        let candidates = vendor_candidates(vendor_id);
        load_vendor_secret(pool, owner_user_id, &candidates).await?
    } else {
        None
    };

    if let Some(api_key) = vendor_secret {
        let base_url = std::env::var("OPENAI_BASE_URL")
            .unwrap_or_else(|_| "https://api.openai.com/v1".to_string())
            .trim_end_matches('/')
            .to_string();
        return Ok(LlmConfig {
            api_key,
            base_url,
            model: model.to_string(),
        });
    }

    let Some(server_llm) = state.llm.as_ref() else {
        return Err(JobRunError::Failed(
            "voiceover generation requires configured ttsDubbing credentials or OPENAI_API_KEY / LLM_API_KEY".into(),
        ));
    };
    Ok(LlmConfig {
        api_key: server_llm.api_key.clone(),
        base_url: server_llm.base_url.clone(),
        model: model.to_string(),
    })
}

fn vendor_candidates(raw_vendor_id: &str) -> Vec<String> {
    let trimmed = raw_vendor_id.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    let mut candidates = vec![trimmed.to_string()];
    if let Some(vendor) = lookup_vendor_catalog(trimmed) {
        let numeric = vendor.numeric_id.to_string();
        if candidates.iter().all(|value| value != &numeric) {
            candidates.push(numeric);
        }
        if candidates.iter().all(|value| value != &vendor.slug) {
            candidates.push(vendor.slug);
        }
    }
    candidates
}

async fn load_vendor_secret(
    pool: &PgPool,
    owner_user_id: Uuid,
    candidates: &[String],
) -> Result<Option<String>, JobRunError> {
    for vendor_id in candidates {
        let row: Option<VendorCredentialRow> = sqlx::query_as(
            r#"
            SELECT api_key_encrypted, api_secret_encrypted, api_token_encrypted
            FROM app_vendor_credential
            WHERE owner_user_id = $1 AND vendor_id = $2
            "#,
        )
        .bind(owner_user_id)
        .bind(vendor_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;
        let Some(row) = row else {
            continue;
        };
        for encrypted in [
            row.api_key_encrypted.as_deref(),
            row.api_token_encrypted.as_deref(),
            row.api_secret_encrypted.as_deref(),
        ]
        .into_iter()
        .flatten()
        {
            if let Some(secret) = decrypt(encrypted) {
                let trimmed = secret.trim();
                if !trimmed.is_empty() {
                    return Ok(Some(trimmed.to_string()));
                }
            }
        }
    }
    Ok(None)
}

async fn persist_voiceover_audio(
    root: &Path,
    owner_user_id: Uuid,
    file_name: &str,
    audio_bytes: &[u8],
) -> Result<(), JobRunError> {
    let dir = root.join(owner_user_id.to_string());
    tokio::fs::create_dir_all(&dir)
        .await
        .map_err(|e| JobRunError::Failed(format!("failed to create voiceover dir: {e}")))?;
    let path = dir.join(file_name);
    tokio::fs::write(path, audio_bytes)
        .await
        .map_err(|e| JobRunError::Failed(format!("failed to persist voiceover audio: {e}")))
}

async fn persist_storyboard_voiceover_metadata(
    pool: &PgPool,
    storyboard_id: Uuid,
    voiceover_payload: &Value,
) -> Result<(), JobRunError> {
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{voiceover}', $2::jsonb, true),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(voiceover_payload)
    .execute(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::{resolve_narration_text, vendor_candidates, StoryboardVoiceoverSeedRow};

    #[test]
    fn resolve_narration_text_prefers_explicit_narration() {
        let seed = StoryboardVoiceoverSeedRow {
            prompt: Some("prompt fallback".into()),
            video_desc: Some("  explicit narration  ".into()),
            character_id: None,
            metadata: json!({}),
        };

        assert_eq!(
            resolve_narration_text(&seed).as_deref(),
            Some("explicit narration")
        );
    }

    #[test]
    fn resolve_narration_text_falls_back_to_prompt() {
        let seed = StoryboardVoiceoverSeedRow {
            prompt: Some("  prompt fallback  ".into()),
            video_desc: Some("   ".into()),
            character_id: None,
            metadata: json!({}),
        };

        assert_eq!(
            resolve_narration_text(&seed).as_deref(),
            Some("prompt fallback")
        );
    }

    #[test]
    fn vendor_candidates_expand_known_vendor_aliases() {
        let candidates = vendor_candidates("1");
        assert_eq!(candidates, vec!["1", "openai"]);
    }

    #[test]
    fn vendor_candidates_preserve_unknown_vendor_and_trim_blank() {
        assert!(vendor_candidates("   ").is_empty());
        assert_eq!(
            vendor_candidates(" custom-endpoint "),
            vec!["custom-endpoint"]
        );
    }
}
