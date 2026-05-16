//! Director manual parsing, cue matching, and anchor selection.

use super::*;

mod cues;

#[allow(unused_imports)]
pub(in crate::production::workbench::meta::generate) use cues::{
    art_style_director_profile, compact_director_emotion_fragment_group,
    fragile_turn_director_emotion_cue_bonus, motion_style_anchor_lags_fragile_emotional_turn,
    parse_director_emotion_cues, parse_director_environment_cues,
    parse_director_environment_texture_cues, parse_director_motion_cue,
    score_director_emotion_cue_match, score_director_emotion_fragment,
    score_director_environment_cue_match, score_director_environment_texture_cue_match,
    storyboard_environment_dynamic_density, ArtStyleDirectorProfile, DirectorEmotionCue,
    DirectorEmotionFragmentGroup, DirectorEnvironmentTextureCue, ART_STYLE_DIRECTOR_PROFILES,
};

impl GenerateVideoPromptDiagnostics {
    pub(super) fn with_runtime_notes(
        mut self,
        selection: Option<&AutoNegativePromptSelection>,
        observation_note: Option<&str>,
        observation_source: Option<&str>,
        runtime: Option<&StoryboardNegativePromptRuntime>,
    ) -> Self {
        let negative_prompt = selection.and_then(|value| value.prompt.as_deref());
        let negative_constraint_count = selection.map(|value| value.fragment_count).unwrap_or(0);
        let negative_budget_tier = selection.map(|value| value.budget_tier);
        let auto_negative_source = selection
            .and_then(AutoNegativePromptSelection::source_label)
            .map(str::to_string)
            .or_else(|| {
                observation_note.and_then(|note| {
                    (!normalize_prompt_text(note).is_empty()).then(|| {
                        observation_source
                            .unwrap_or("pending_observation_note")
                            .to_string()
                    })
                })
            });
        let auto_negative_review_fragment_count = selection
            .map(|value| value.review_fragment_count)
            .unwrap_or(0);
        let auto_negative_memory_fragment_count = selection
            .map(|value| value.rejected_memory_fragment_count)
            .unwrap_or(0);
        self.negative_prompt_chars = negative_prompt
            .map(normalize_prompt_text)
            .map(|value| value.chars().count())
            .unwrap_or(0);
        self.negative_constraint_count = negative_constraint_count;
        self.negative_candidate_fragment_count = selection
            .map(|value| value.candidate_fragment_count)
            .unwrap_or(0);
        self.negative_saved_fragment_count = selection
            .map(|value| value.saved_fragment_count)
            .unwrap_or(0);
        self.negative_saved_chars = selection.map(|value| value.saved_chars).unwrap_or(0);
        self.negative_budget_tier = negative_budget_tier.unwrap_or("lean").to_string();
        self.auto_negative_source = auto_negative_source;
        self.auto_negative_review_fragment_count = auto_negative_review_fragment_count;
        self.auto_negative_memory_fragment_count = auto_negative_memory_fragment_count;
        self.observation_note_chars = observation_note
            .map(normalize_prompt_text)
            .map(|value: String| value.chars().count())
            .unwrap_or(0);
        let scope_counts = runtime
            .map(|value| summarize_prompt_support_memory_scope_rows(&value.prompt_support_rows));
        self.memory_project_scope_row_count = scope_counts
            .as_ref()
            .map(|counts| counts.project_scope_rows)
            .unwrap_or(0);
        self.memory_script_scope_row_count = scope_counts
            .as_ref()
            .map(|counts| counts.script_scope_rows)
            .unwrap_or(0);
        self.memory_role_scope_row_count = scope_counts
            .as_ref()
            .map(|counts| counts.role_scope_rows)
            .unwrap_or(0);
        self
    }

    pub(super) fn with_memory_optimization(
        mut self,
        project_result: &crate::settings::agent_memory::MemoryBudgetOptimizeResult,
        scoped_result: Option<
            &crate::production::workbench::video_prompt_memory::VideoMemoryOptimizationResult,
        >,
    ) -> Self {
        let scoped_removed_rows = scoped_result.map(|result| result.removed_rows).unwrap_or(0);
        let scoped_removed_chars = scoped_result
            .map(|result| result.removed_chars)
            .unwrap_or(0);
        let scoped_removed_visual_rows = scoped_result
            .map(|result| result.removed_visual_rows)
            .unwrap_or(0);
        let scoped_removed_duplicate_rows = scoped_result
            .map(|result| result.removed_duplicate_rows)
            .unwrap_or(0);
        self.memory_optimization_removed_rows = project_result.removed_rows + scoped_removed_rows;
        self.memory_optimization_removed_chars =
            project_result.removed_chars + scoped_removed_chars;
        self.memory_optimization_removed_visual_rows = scoped_removed_visual_rows;
        self.memory_optimization_removed_duplicate_rows =
            project_result.removed_duplicate_rows + scoped_removed_duplicate_rows;
        self.memory_optimization_removed_low_value_rows = project_result.removed_low_value_rows;
        self.memory_optimization_applied = self.memory_optimization_removed_rows > 0;
        self
    }
}

#[derive(Debug, Default)]
struct PromptSupportMemoryScopeCounts {
    project_scope_rows: usize,
    script_scope_rows: usize,
    role_scope_rows: usize,
}

fn summarize_prompt_support_memory_scope_rows(
    rows: &[crate::production::workbench::video_prompt_memory::AgentMemoryRow],
) -> PromptSupportMemoryScopeCounts {
    rows.iter().fold(
        PromptSupportMemoryScopeCounts::default(),
        |mut counts, row| {
            if row.name.starts_with("project_") {
                counts.project_scope_rows += 1;
            } else {
                counts.script_scope_rows += 1;
            }
            if row.name.contains("_role_") {
                counts.role_scope_rows += 1;
            }
            counts
        },
    )
}

pub(super) fn resolve_performance_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.subject.trim().is_empty() || fields.mood.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_emotion_cues(profile.director_storyboard)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_emotion_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score.cmp(right_score).then_with(|| {
                right_cue
                    .emotion_terms
                    .len()
                    .cmp(&left_cue.emotion_terms.len())
            })
        })?
        .1;

    let mut fragments = Vec::new();
    for (group, fragment) in [
        (DirectorEmotionFragmentGroup::Face, cue.face.as_str()),
        (DirectorEmotionFragmentGroup::Eyes, cue.eyes.as_str()),
        (
            DirectorEmotionFragmentGroup::MicroExpression,
            cue.micro_expression.as_str(),
        ),
    ] {
        let Some(fragment) = compact_director_emotion_fragment_group(fragment, group) else {
            continue;
        };
        let Some(fragment) = trim_director_performance_fragment_against_storyboard_fields(
            &fragment,
            &[fields.action.as_str(), fields.dialogue.as_str()],
        ) else {
            continue;
        };
        if prompt_fragment_is_covered(&fragment, prompt_coverage)
            || fragments.iter().any(|existing| existing == &fragment)
        {
            continue;
        }
        fragments.push(fragment);
    }

    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join(", "),
        VIDEO_PROMPT_PERFORMANCE_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_environment_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.setting.trim().is_empty() {
        return None;
    }
    if storyboard_environment_dynamic_density(fields) >= 3 {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_environment_cues(profile.director_storyboard_table_style)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_environment_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score
                .cmp(right_score)
                .then_with(|| right_cue.chars().count().cmp(&left_cue.chars().count()))
        })?
        .1;

    if prompt_fragment_is_covered(&cue, prompt_coverage)
        || fields.setting.contains(&cue)
        || fields.action.contains(&cue)
        || fields.sound.contains(&cue)
    {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_ENVIRONMENT_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_guardrail_performance_anchor(
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let fields = structured_fields?;
    let pressure = constraint_pressure.filter(|pressure| {
        pressure.has_dialogue_guardrail
            || pressure.has_emotion_guardrail
            || pressure.has_identity_guardrail
    });
    let has_fragile_turn = current_storyboard_is_fragile_emotional_turn(fields);
    let has_visible_dialogue_risk = storyboard_has_visible_speech_performance_risk(fields, None);
    let should_add_proactive_anchor = has_fragile_turn
        && (has_visible_dialogue_risk || video_prompt_scene_needs_identity_memory(fields));

    if pressure.is_none() && !should_add_proactive_anchor {
        return None;
    }

    let normalized_coverage = prompt_coverage
        .iter()
        .map(|fragment| normalize_prompt_text(fragment))
        .collect::<Vec<_>>();
    let has_face_signal = normalized_coverage.iter().any(|fragment| {
        guardrail_coverage_fragment_is_style_like(fragment)
            && coverage_has_specific_guardrail_face_signal(fragment)
    });
    let has_delivery_signal = normalized_coverage.iter().any(|fragment| {
        guardrail_coverage_fragment_is_style_like(fragment)
            && coverage_has_specific_guardrail_delivery_signal(fragment)
    });
    let storyboard_already_has_face_signal =
        coverage_has_specific_guardrail_face_signal(&fields.action)
            || coverage_has_specific_guardrail_face_signal(&fields.dialogue);
    let storyboard_already_has_delivery_signal =
        coverage_has_specific_guardrail_delivery_signal(&fields.action)
            || coverage_has_specific_guardrail_delivery_signal(&fields.dialogue);

    let mut fragments = Vec::new();
    if !storyboard_dialogue_is_empty(&fields.dialogue)
        && pressure.is_some_and(|pressure| pressure.has_dialogue_guardrail)
    {
        if !has_face_signal && !storyboard_already_has_face_signal {
            fragments.push(if has_fragile_turn {
                "开口前先压住气息".to_string()
            } else {
                "眼神先动再开口".to_string()
            });
        }
        if !has_delivery_signal && !storyboard_already_has_delivery_signal {
            fragments.push(if has_fragile_turn {
                "尾音带轻颤".to_string()
            } else {
                "气息带情绪起伏".to_string()
            });
        }
    } else if pressure.is_some_and(|pressure| {
        pressure.has_emotion_guardrail
            || (pressure.has_identity_guardrail && video_prompt_scene_needs_identity_memory(fields))
    }) {
        if has_face_signal || storyboard_already_has_face_signal {
            return None;
        }
        fragments.push("眼神嘴角细微递进".to_string());
    } else if has_visible_dialogue_risk {
        if !has_face_signal && (!storyboard_already_has_face_signal || has_fragile_turn) {
            fragments.push(if has_fragile_turn {
                "开口前先压住气息".to_string()
            } else {
                "眼神先动再开口".to_string()
            });
        }
        if !has_delivery_signal && has_fragile_turn {
            fragments.push("尾音带轻颤".to_string());
        }
    } else if has_fragile_turn && video_prompt_scene_needs_identity_memory(fields) {
        if has_face_signal || storyboard_already_has_face_signal {
            return None;
        }
        fragments.push("眼神嘴角细微递进".to_string());
    }

    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join(", "),
        VIDEO_PROMPT_GUARDRAIL_PERFORMANCE_ANCHOR_MAX_CHARS,
    ))
}

fn coverage_has_specific_guardrail_face_signal(fragment: &str) -> bool {
    [
        "抬眼",
        "垂眼",
        "喉结",
        "呼吸",
        "发颤",
        "停顿",
        "欲言又止",
        "哽咽",
        "抽气",
        "眼眶发红",
        "指尖发颤",
        "嘴角发僵",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

fn coverage_has_specific_guardrail_delivery_signal(fragment: &str) -> bool {
    ["气息", "换气", "尾音", "发颤", "哽咽", "抽气", "失声"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

fn guardrail_coverage_fragment_is_style_like(fragment: &str) -> bool {
    [
        "表演", "语气", "情绪", "动作", "神情", "眼神", "目光", "眼底", "眉心", "嘴角", "唇线",
    ]
    .iter()
    .any(|prefix| fragment.starts_with(prefix))
}

pub(super) fn resolve_environment_texture_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.setting.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_environment_texture_cues(profile.director_storyboard_table_style)
        .into_iter()
        .filter_map(|cue| {
            let score = score_director_environment_texture_cue_match(fields, &cue);
            (score > 0).then_some((score, cue))
        })
        .max_by(|(left_score, left_cue), (right_score, right_cue)| {
            left_score.cmp(right_score).then_with(|| {
                right_cue
                    .cue
                    .chars()
                    .count()
                    .cmp(&left_cue.cue.chars().count())
            })
        })?
        .1
        .cue;

    if prompt_fragment_is_covered(&cue, prompt_coverage)
        || fields.setting.contains(&cue)
        || fields.action.contains(&cue)
        || fields.sound.contains(&cue)
    {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_ENVIRONMENT_TEXTURE_ANCHOR_MAX_CHARS,
    ))
}

pub(super) fn resolve_motion_style_anchor(
    project_art_style: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let fields = structured_fields?;
    if fields.subject.trim().is_empty() || fields.action.trim().is_empty() {
        return None;
    }

    let profile = art_style_director_profile(project_art_style?)?;
    let cue = parse_director_motion_cue(profile.director_storyboard_table_style)?;
    if motion_style_anchor_lags_fragile_emotional_turn(&cue, fields) {
        return None;
    }
    if prompt_fragment_is_covered(&cue, prompt_coverage) || fields.action.contains(&cue) {
        return None;
    }

    Some(clip_prompt_fragment(
        &cue,
        VIDEO_PROMPT_MOTION_ANCHOR_MAX_CHARS,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn guardrail_performance_anchor_keeps_fragile_dialogue_cues_without_pressure() {
        let fields = StructuredStoryboardDescription {
            subject: "林晚".to_string(),
            setting: "病房门口".to_string(),
            subject_refs: "林晚".to_string(),
            duration_seconds: Some(4),
            shot: "近景".to_string(),
            camera_move: "缓推".to_string(),
            action: "抽气后低声说我没事".to_string(),
            mood: "压抑".to_string(),
            lighting: "冷白侧光".to_string(),
            dialogue: "我没事".to_string(),
            sound: "空调低鸣".to_string(),
        };

        let anchor = resolve_guardrail_performance_anchor(
            Some(&fields),
            &["神情低落, 眼神黯淡, 眉心轻蹙".to_string()],
            None,
        )
        .expect("anchor");

        assert!(anchor.contains("开口前先压住气息"), "{anchor}");
        assert!(anchor.contains("尾音带轻颤"), "{anchor}");
    }
}
