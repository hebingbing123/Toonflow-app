//! **`job_sub_kind`** + **`production_phase`** on **`JobRow`** (L2 / MP-W2).
//!
//! - Stored inside **`payload`** for DB‑only consumers and historical rows.
//! - Mirrored on **`JobRow`** (`#[sqlx(skip)]`) after **`hydrate_job_row`** for task center / WS JSON.

use serde_json::{json, Value};

use super::dto::JobRow;
use super::kinds::{
    JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE, JOB_KIND_ASSET_POLISH_BATCH,
    JOB_KIND_ASSET_POLISH_PROMPT, JOB_KIND_BGM_GENERATE, JOB_KIND_FLUTTER_PROBE,
    JOB_KIND_SETTINGS_VENDOR_MODEL_TEST, JOB_KIND_SUBTITLE_GENERATE, JOB_KIND_VIDEO_EXPORT,
    JOB_KIND_VIDEO_GENERATE, JOB_KIND_VOICEOVER_GENERATE,
};

/// TTS / speech synthesis leg of narration (**`voiceover.generate`** worker).
pub const JOB_SUB_KIND_VOICEOVER_TTS: &str = "voiceover.tts";
/// Timed captions / burn‑in (**future** **`subtitle.generate`**).
pub const JOB_SUB_KIND_SUBTITLE_CAPTIONS: &str = "subtitle.captions";
/// Music bed / ducking (**future** **`bgm.generate`**).
pub const JOB_SUB_KIND_BGM_MIX: &str = "bgm.mix";
pub const JOB_SUB_KIND_VIDEO_CLIP: &str = "video.generate.clip";
pub const JOB_SUB_KIND_VIDEO_EXPORT_RENDER: &str = "video.export.render";
pub const JOB_SUB_KIND_ASSET_IMAGE_SINGLE: &str = "asset.image.single";
pub const JOB_SUB_KIND_ASSET_IMAGE_BATCH: &str = "asset.image.batch";
pub const JOB_SUB_KIND_ASSET_POLISH_SINGLE: &str = "asset.polish.single";
pub const JOB_SUB_KIND_ASSET_POLISH_BATCH: &str = "asset.polish.batch";
pub const JOB_SUB_KIND_SYSTEM_PROBE: &str = "system.probe";
pub const JOB_SUB_KIND_SETTINGS_VENDOR_TEST: &str = "settings.vendor.model_test";

pub const PRODUCTION_PHASE_NARRATION: &str = "post_production.narration";
pub const PRODUCTION_PHASE_SUBTITLE: &str = "post_production.subtitle";
pub const PRODUCTION_PHASE_BGM: &str = "post_production.bgm";
pub const PRODUCTION_PHASE_VIDEO: &str = "production.video";
pub const PRODUCTION_PHASE_EXPORT: &str = "post_production.export";
pub const PRODUCTION_PHASE_ASSETS: &str = "production.assets";
pub const PRODUCTION_PHASE_SYSTEM: &str = "system.maintenance";

#[inline]
fn default_job_sub_kind(kind: &str) -> Option<&'static str> {
    Some(match kind {
        k if k == JOB_KIND_VOICEOVER_GENERATE => JOB_SUB_KIND_VOICEOVER_TTS,
        k if k == JOB_KIND_SUBTITLE_GENERATE => JOB_SUB_KIND_SUBTITLE_CAPTIONS,
        k if k == JOB_KIND_BGM_GENERATE => JOB_SUB_KIND_BGM_MIX,
        k if k == JOB_KIND_VIDEO_GENERATE => JOB_SUB_KIND_VIDEO_CLIP,
        k if k == JOB_KIND_VIDEO_EXPORT => JOB_SUB_KIND_VIDEO_EXPORT_RENDER,
        k if k == JOB_KIND_ASSET_GENERATE_IMAGE => JOB_SUB_KIND_ASSET_IMAGE_SINGLE,
        k if k == JOB_KIND_ASSET_GENERATE_BATCH => JOB_SUB_KIND_ASSET_IMAGE_BATCH,
        k if k == JOB_KIND_ASSET_POLISH_PROMPT => JOB_SUB_KIND_ASSET_POLISH_SINGLE,
        k if k == JOB_KIND_ASSET_POLISH_BATCH => JOB_SUB_KIND_ASSET_POLISH_BATCH,
        k if k == JOB_KIND_FLUTTER_PROBE => JOB_SUB_KIND_SYSTEM_PROBE,
        k if k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => JOB_SUB_KIND_SETTINGS_VENDOR_TEST,
        _ => return None,
    })
}

#[inline]
fn default_production_phase(kind: &str) -> Option<&'static str> {
    Some(match kind {
        k if k == JOB_KIND_VOICEOVER_GENERATE => PRODUCTION_PHASE_NARRATION,
        k if k == JOB_KIND_SUBTITLE_GENERATE => PRODUCTION_PHASE_SUBTITLE,
        k if k == JOB_KIND_BGM_GENERATE => PRODUCTION_PHASE_BGM,
        k if k == JOB_KIND_VIDEO_GENERATE => PRODUCTION_PHASE_VIDEO,
        k if k == JOB_KIND_VIDEO_EXPORT => PRODUCTION_PHASE_EXPORT,
        k if k == JOB_KIND_ASSET_GENERATE_IMAGE
            || k == JOB_KIND_ASSET_GENERATE_BATCH
            || k == JOB_KIND_ASSET_POLISH_PROMPT
            || k == JOB_KIND_ASSET_POLISH_BATCH =>
        {
            PRODUCTION_PHASE_ASSETS
        }
        k if k == JOB_KIND_FLUTTER_PROBE || k == JOB_KIND_SETTINGS_VENDOR_MODEL_TEST => {
            PRODUCTION_PHASE_SYSTEM
        }
        _ => return None,
    })
}

/// Ensures **`payload`** carries stable track metadata when keys are absent (caller may override).
pub fn merge_default_track_metadata(kind: &str, payload: &mut Value) {
    let Some(obj) = payload.as_object_mut() else {
        return;
    };
    if !obj.contains_key("job_sub_kind") {
        if let Some(s) = default_job_sub_kind(kind) {
            obj.insert("job_sub_kind".into(), json!(s));
        }
    }
    if !obj.contains_key("production_phase") {
        if let Some(p) = default_production_phase(kind) {
            obj.insert("production_phase".into(), json!(p));
        }
    }
}

/// Fills **`#[sqlx(skip)]`** mirror fields from **`payload`** or kind defaults (for pre‑L2 rows).
pub fn hydrate_job_row(row: &mut JobRow) {
    row.job_sub_kind = row
        .payload
        .get("job_sub_kind")
        .and_then(|v| v.as_str())
        .map(str::to_owned)
        .or_else(|| default_job_sub_kind(row.kind.as_str()).map(str::to_owned));
    row.production_phase = row
        .payload
        .get("production_phase")
        .and_then(|v| v.as_str())
        .map(str::to_owned)
        .or_else(|| default_production_phase(row.kind.as_str()).map(str::to_owned));
}

#[inline]
pub fn hydrate_job_rows(rows: &mut [JobRow]) {
    for row in rows.iter_mut() {
        hydrate_job_row(row);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::jobs::dto::JobRow;
    use serde_json::json;
    use uuid::Uuid;

    #[test]
    fn merge_inserts_voiceover_defaults() {
        let mut p = json!({"storyboard_numeric_id": 1});
        merge_default_track_metadata(JOB_KIND_VOICEOVER_GENERATE, &mut p);
        assert_eq!(p["job_sub_kind"], json!(JOB_SUB_KIND_VOICEOVER_TTS));
        assert_eq!(p["production_phase"], json!(PRODUCTION_PHASE_NARRATION));
    }

    #[test]
    fn merge_does_not_override_explicit_sub_kind() {
        let mut p = json!({"job_sub_kind": "custom.voiceover"});
        merge_default_track_metadata(JOB_KIND_VOICEOVER_GENERATE, &mut p);
        assert_eq!(p["job_sub_kind"], json!("custom.voiceover"));
        assert_eq!(p["production_phase"], json!(PRODUCTION_PHASE_NARRATION));
    }

    #[test]
    fn hydrate_falls_back_when_payload_omits_keys() {
        let mut row = JobRow {
            numeric_task_id: 1,
            id: Uuid::nil(),
            owner_user_id: Uuid::nil(),
            kind: JOB_KIND_VOICEOVER_GENERATE.into(),
            status: "queued".into(),
            payload: json!({}),
            result: None,
            error_message: None,
            error_details: None,
            idempotency_key: None,
            claimed_by: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            job_sub_kind: None,
            production_phase: None,
        };
        hydrate_job_row(&mut row);
        assert_eq!(
            row.job_sub_kind.as_deref(),
            Some(JOB_SUB_KIND_VOICEOVER_TTS)
        );
        assert_eq!(
            row.production_phase.as_deref(),
            Some(PRODUCTION_PHASE_NARRATION)
        );
    }
}
