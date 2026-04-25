use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::scope::http::require_authenticated;
use crate::scope::http::require_owned_numeric_script_access;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateVideoPromptBody {
    project_id: i32,
    script_id: i32,
    #[serde(default)]
    #[allow(dead_code)]
    image_url: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    duration_hint: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptResponse {
    prompt: String,
    model: String,
    duration: i32,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video-prompt",
    operation_id = "postProductionWorkbenchGenerateVideoPromptV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_generate_video_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateVideoPromptBody>,
) -> Result<JsonResponse<GenerateVideoPromptResponse>, ApiError> {
    require_owned_numeric_script_access(&state, &headers, body.project_id, body.script_id).await?;

    let prompt = build_video_prompt(body.description.as_deref(), body.image_url.as_deref());
    let duration = resolve_video_prompt_duration(body.duration_hint, body.description.as_deref());

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt,
        model: "runway-gen-2".to_string(),
        duration,
    }))
}

fn build_video_prompt(description: Option<&str>, image_url: Option<&str>) -> String {
    let mut clauses = Vec::new();
    clauses.push("Single cinematic shot.".to_string());

    match description.and_then(parse_structured_storyboard_description) {
        Some(fields) => {
            if !fields.subject.is_empty() {
                clauses.push(format!(
                    "Subject: {}.",
                    clip_prompt_fragment(&fields.subject, 72)
                ));
            }
            if !fields.setting.is_empty() {
                clauses.push(format!(
                    "Setting: {}.",
                    clip_prompt_fragment(&fields.setting, 48)
                ));
            }
            if !fields.action.is_empty() {
                clauses.push(format!(
                    "Action: {}.",
                    clip_prompt_fragment(&fields.action, 72)
                ));
            }
            let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<Vec<_>>()
                .join(", ");
            if !camera.is_empty() {
                clauses.push(format!("Camera: {}.", clip_prompt_fragment(&camera, 40)));
            }
            if !fields.mood.is_empty() {
                clauses.push(format!("Mood: {}.", clip_prompt_fragment(&fields.mood, 36)));
            }
            if !fields.lighting.is_empty() {
                clauses.push(format!(
                    "Lighting: {}.",
                    clip_prompt_fragment(&fields.lighting, 44)
                ));
            }
            if !fields.dialogue.is_empty() && !looks_like_silence(&fields.dialogue) {
                clauses.push(format!(
                    "Dialogue or voice-over: {}.",
                    clip_prompt_fragment(&fields.dialogue, 60)
                ));
            }
            if !fields.sound.is_empty() && !looks_like_silence(&fields.sound) {
                clauses.push(format!(
                    "Sound: {}.",
                    clip_prompt_fragment(&fields.sound, 44)
                ));
            }
        }
        None => {
            let fallback = description
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .unwrap_or_else(|| "Clear subject, natural motion, stable continuity.".to_string());
            clauses.push(format!("Scene: {}.", clip_prompt_fragment(&fallback, 160)));
        }
    }

    if image_url.is_some() {
        clauses.push("Use the supplied frame as the visual reference.".to_string());
    }
    clauses.push("Natural motion, stable continuity, no extra shot changes.".to_string());
    clauses.join(" ")
}

fn resolve_video_prompt_duration(duration_hint: Option<i32>, description: Option<&str>) -> i32 {
    if let Some(value) = duration_hint.filter(|value| *value > 0) {
        return value.clamp(2, 16);
    }
    if let Some(parsed) = description
        .and_then(parse_structured_storyboard_description)
        .and_then(|fields| fields.duration_seconds)
    {
        return parsed.clamp(2, 16);
    }
    5
}

#[derive(Debug, Clone)]
struct StructuredStoryboardDescription {
    subject: String,
    setting: String,
    duration_seconds: Option<i32>,
    shot: String,
    camera_move: String,
    action: String,
    mood: String,
    lighting: String,
    dialogue: String,
    sound: String,
}

fn parse_structured_storyboard_description(
    description: &str,
) -> Option<StructuredStoryboardDescription> {
    let normalized = description
        .trim()
        .trim_start_matches(['（', '('])
        .trim_end_matches(['）', ')'])
        .trim();
    if normalized.is_empty() {
        return None;
    }
    let parts = normalized
        .split('、')
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();
    if parts.len() < 8 {
        return None;
    }
    Some(StructuredStoryboardDescription {
        subject: parts.first().cloned().unwrap_or_default(),
        setting: parts.get(1).cloned().unwrap_or_default(),
        duration_seconds: parts.get(3).and_then(|value| parse_positive_int(value)),
        shot: parts.get(4).cloned().unwrap_or_default(),
        camera_move: parts.get(5).cloned().unwrap_or_default(),
        action: parts.get(6).cloned().unwrap_or_default(),
        mood: parts.get(7).cloned().unwrap_or_default(),
        lighting: parts.get(8).cloned().unwrap_or_default(),
        dialogue: parts.get(9).cloned().unwrap_or_default(),
        sound: parts.get(10).cloned().unwrap_or_default(),
    })
}

fn normalize_prompt_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn clip_prompt_fragment(text: &str, max_chars: usize) -> String {
    let normalized = normalize_prompt_text(text);
    let mut chars = normalized.chars();
    let clipped = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

fn looks_like_silence(text: &str) -> bool {
    let normalized = text.trim().to_lowercase();
    normalized.is_empty()
        || normalized == "无"
        || normalized == "无台词"
        || normalized == "无音效"
        || normalized == "none"
        || normalized == "no dialogue"
        || normalized == "no sound"
}

fn parse_positive_int(text: &str) -> Option<i32> {
    let mut digits = String::new();
    for ch in text.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }
    digits.parse::<i32>().ok().filter(|value| *value > 0)
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct VideoModelDetailResponse {
    model_id: String,
    model_name: String,
    provider: String,
    max_duration: i32,
    resolutions: Vec<String>,
    features: Vec<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-video-model-detail",
    operation_id = "postProductionWorkbenchGetVideoModelDetailV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_get_video_model_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VideoModelDetailResponse>, ApiError> {
    require_authenticated(&state, &headers)?;

    Ok(JsonResponse(VideoModelDetailResponse {
        model_id: "gen-2".to_string(),
        model_name: "Gen-2".to_string(),
        provider: "runway".to_string(),
        max_duration: 16,
        resolutions: vec!["720p".to_string(), "1080p".to_string()],
        features: vec![
            "text-to-video".to_string(),
            "image-to-video".to_string(),
            "motion-brush".to_string(),
        ],
    }))
}

#[cfg(test)]
mod tests {
    use super::{
        build_video_prompt, parse_structured_storyboard_description, resolve_video_prompt_duration,
    };

    #[test]
    fn build_video_prompt_compacts_structured_storyboard_description() {
        let prompt = build_video_prompt(
            Some("（主角独立城楼远眺苍茫大地、城楼、主角/城楼、4s、全景、缓慢推进、负手而立衣袂翻飞、坚定压抑、黄昏冷调侧逆光、无台词、风声衣袂声、A001/A003）"),
            Some("https://example.com/frame.png"),
        );

        assert!(prompt.contains("Single cinematic shot."));
        assert!(prompt.contains("Subject: 主角独立城楼远眺苍茫大地."));
        assert!(prompt.contains("Camera: 全景, 缓慢推进."));
        assert!(prompt.contains("Use the supplied frame as the visual reference."));
        assert!(!prompt.contains("A001/A003"));
    }

    #[test]
    fn parse_structured_storyboard_description_extracts_duration() {
        let fields = parse_structured_storyboard_description(
            "（雨夜街角对峙、旧街、主角/反派、6秒、中景、手持跟拍、彼此逼近、紧张、霓虹潮湿反光、你终于来了、雨声脚步声、A1/A2）",
        )
        .expect("structured description");

        assert_eq!(fields.duration_seconds, Some(6));
        assert_eq!(fields.setting, "旧街");
        assert_eq!(fields.dialogue, "你终于来了");
    }

    #[test]
    fn resolve_video_prompt_duration_prefers_hint_then_description_then_default() {
        assert_eq!(
            resolve_video_prompt_duration(
                Some(8),
                Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            ),
            8
        );
        assert_eq!(
            resolve_video_prompt_duration(
                None,
                Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            ),
            4
        );
        assert_eq!(resolve_video_prompt_duration(None, Some("普通描述")), 5);
    }
}
