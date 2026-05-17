use super::builder_parts::continuity::compact::compact_continuity_note;
use super::{
    continuity_note_matches_storyboard_risk, current_storyboard_is_fragile_emotional_turn,
    storyboard_dialogue_is_empty, video_prompt_scene_has_motion_risk,
    StructuredStoryboardDescription, VideoPromptConstraintPressure, VideoPromptMemoryBudgetTier,
};
use crate::production::workbench::generation_profile::GenerationProfileTier;

fn apply_generation_profile_to_memory_budget(
    decision: &mut VideoPromptMemoryBudgetDecision,
    profile: GenerationProfileTier,
) {
    match profile {
        GenerationProfileTier::Draft => {
            decision.tier = VideoPromptMemoryBudgetTier::Lean;
            decision
                .reasons
                .push("generation_profile_draft_lean_cap".into());
        }
        GenerationProfileTier::Premium => {
            if decision.tier == VideoPromptMemoryBudgetTier::Lean && decision.risk_score >= 1 {
                decision.tier = VideoPromptMemoryBudgetTier::Expanded;
                decision
                    .reasons
                    .push("generation_profile_premium_expanded_boost".into());
            }
        }
        GenerationProfileTier::Standard => {}
    }
}

#[derive(Debug, Clone)]
pub(crate) struct VideoPromptMemoryBudgetDecision {
    pub(super) tier: VideoPromptMemoryBudgetTier,
    pub(super) risk_score: i32,
    pub(super) reasons: Vec<String>,
    pub(super) compact_silent_low_risk: bool,
}

#[allow(clippy::too_many_arguments)]
pub(super) fn resolve_video_prompt_memory_budget(
    image_url: Option<&str>,
    continuity_notes: &[String],
    structured_fields: Option<&StructuredStoryboardDescription>,
    role_anchors: &[String],
    scene_anchors: &[String],
    tool_anchors: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
    generation_profile: Option<GenerationProfileTier>,
) -> VideoPromptMemoryBudgetDecision {
    let mut risk_score: i32 = 0;
    let mut reasons = Vec::new();

    if image_url.is_none() {
        risk_score += 2;
        reasons.push("missing_reference_frame".to_string());
    }
    if role_anchors.is_empty() && structured_fields.is_some_and(|fields| !fields.subject.is_empty())
    {
        risk_score += 1;
        reasons.push("missing_role_anchor".to_string());
    }
    if scene_anchors.is_empty()
        && tool_anchors.is_empty()
        && structured_fields.is_some_and(|fields| !fields.setting.is_empty())
    {
        risk_score += 1;
        reasons.push("missing_scene_anchor".to_string());
    }

    let has_effective_continuity_note = continuity_notes.iter().any(|note| {
        compact_continuity_note(note, structured_fields, &[]).is_some_and(|compacted| {
            continuity_note_matches_storyboard_risk(&compacted, structured_fields)
        })
    });
    if has_effective_continuity_note {
        risk_score += 1;
        reasons.push("continuity_pressure".to_string());
    }

    let emotional_risk =
        structured_fields.is_some_and(super::video_prompt_scene_needs_emotional_memory);
    if emotional_risk {
        risk_score += 1;
        reasons.push("emotional_risk".to_string());
    }

    let grounded_low_risk =
        structured_fields.is_some_and(super::video_prompt_scene_is_grounded_low_risk);
    if image_url.is_none()
        && grounded_low_risk
        && !role_anchors.is_empty()
        && (!scene_anchors.is_empty() || !tool_anchors.is_empty())
        && !has_effective_continuity_note
    {
        risk_score = risk_score.saturating_sub(2);
        reasons.push("grounded_anchor_credit".to_string());
    }
    let anchored_follow_shot_credit = structured_fields.is_some_and(|fields| {
        image_url.is_none()
            && !role_anchors.is_empty()
            && !scene_anchors.is_empty()
            && storyboard_dialogue_is_empty(&fields.dialogue)
            && video_prompt_scene_has_motion_risk(fields)
            && !current_storyboard_is_fragile_emotional_turn(fields)
            && !has_effective_continuity_note
    });
    if anchored_follow_shot_credit {
        risk_score = risk_score.saturating_sub(2);
        reasons.push("anchored_follow_shot_credit".to_string());
    }

    if constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory) {
        risk_score = risk_score.saturating_sub(1);
        reasons.push("compact_pressure_credit".to_string());
    }
    if constraint_pressure.is_some_and(|pressure| {
        pressure.has_active_guardrail()
            && !role_anchors.is_empty()
            && (!scene_anchors.is_empty() || !tool_anchors.is_empty())
    }) {
        risk_score = risk_score.saturating_sub(1);
        reasons.push("guardrail_anchor_credit".to_string());
    }

    let compact_silent_low_risk = structured_fields.is_some_and(|fields| {
        grounded_low_risk
            && fields.dialogue.trim().is_empty()
            && !fields.subject.trim().is_empty()
            && !role_anchors.is_empty()
    });
    if compact_silent_low_risk {
        reasons.push("silent_low_risk_compact_mode".to_string());
    }

    let tier = if risk_score >= 2 {
        VideoPromptMemoryBudgetTier::Expanded
    } else {
        VideoPromptMemoryBudgetTier::Lean
    };

    let mut decision = VideoPromptMemoryBudgetDecision {
        tier,
        risk_score,
        reasons,
        compact_silent_low_risk,
    };
    if let Some(profile) = generation_profile {
        apply_generation_profile_to_memory_budget(&mut decision, profile);
    }
    decision
}
