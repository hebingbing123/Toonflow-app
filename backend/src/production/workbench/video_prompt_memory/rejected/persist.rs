use super::*;
use super::super::storage::{
    storyboard_scope_signature, summary_memory_allowed, VIDEO_SCOPED_MEMORY_TIER,
};

fn storyboard_memory_key(storyboard_numeric_id: i32) -> Option<String> {
    if storyboard_numeric_id > 0 {
        Some(format!("storyboardIds={storyboard_numeric_id}"))
    } else {
        None
    }
}

pub(crate) async fn persist_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let selection_bias = selected_optimization_bias_to_rejected_selection_bias(
        load_selected_video_memory_optimization_bias(
            pool,
            user_id,
            project_numeric_id,
            script_numeric_id,
        )
        .await?,
    );
    let Some(content) = prepare_rejected_video_negative_memory_for_storage(content, selection_bias)
    else {
        return Ok(());
    };
    let Some(storyboard_numeric_id) = extract_key_value(&content, "storyboardIds")
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_content = if let Some(latest) = latest.as_deref() {
        merge_rejected_video_negative_memory_with_bias(latest, &content, selection_bias)
    } else {
        content
    };
    let scope_signature = storyboard_scope_signature(
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
        REJECTED_VIDEO_NEGATIVE_MEMORY_NAME,
        &next_content,
    );
    if !summary_memory_allowed(
        pool,
        user_id,
        project_numeric_id,
        REJECTED_VIDEO_NEGATIVE_MEMORY_NAME,
        &next_content,
        VIDEO_SCOPED_MEMORY_TIER,
        &scope_signature,
    )
    .await?
    {
        clear_rejected_video_negative_memory(
            pool,
            user_id,
            project_numeric_id,
            script_numeric_id,
            storyboard_numeric_id,
        )
        .await?;
        return Ok(());
    }

    if latest.as_deref() == Some(next_content.as_str()) {
        return Ok(());
    }

    clear_rejected_video_negative_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000, $6, $7)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(&next_content)
    .bind(VIDEO_SCOPED_MEMORY_TIER)
    .bind(&scope_signature)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let Some(storyboard_key) = storyboard_memory_key(storyboard_numeric_id) else {
        return Ok(());
    };
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) fn rejected_video_negative_rejection_count(content: &str) -> u32 {
    extract_key_value(content, "rejectionCount")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|count| *count > 0)
        .unwrap_or(1)
}

fn rejected_video_memory_prompt_seed(content: &str) -> Option<String> {
    extract_key_value(content, "promptSeed")
}

pub(in crate::production::workbench::video_prompt_memory) fn extract_rejected_video_risk_tags(
    content: &str,
) -> Vec<String> {
    extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .filter(|tags| !tags.is_empty())
        .unwrap_or_else(|| {
            extract_key_value(content, "avoid")
                .map(|avoid| rejected_video_risk_tags_from_avoid(&avoid))
                .unwrap_or_default()
        })
}

pub(in crate::production::workbench::video_prompt_memory) fn storyboard_risk_tags_for_subject_fallback(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Vec::new();
    };
    let mut tags = Vec::new();
    if selected_memory_scene_has_motion_risk(&fields) {
        tags.push("motion".to_string());
    }
    if rejected_negative_scene_has_identity_risk(&fields) {
        tags.push("identity".to_string());
    }
    if rejected_negative_scene_has_framing_risk(&fields) {
        tags.push("framing".to_string());
    }
    if rejected_negative_scene_has_lighting_risk(&fields) {
        tags.push("lighting".to_string());
    }
    if rejected_negative_scene_needs_emotional_guard(&fields) {
        tags.push("emotion".to_string());
    }
    if rejected_negative_scene_needs_expressive_performance_guard(&fields) {
        tags.push("performance".to_string());
    }
    if rejected_negative_scene_has_dialogue_guard(&fields) {
        tags.push("dialogue".to_string());
    }
    tags
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_video_risk_tag_overlap(
    content: &str,
    storyboard_tags: &[String],
) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    memory_tags
        .iter()
        .filter(|memory_tag| storyboard_tags.iter().any(|tag| tag == *memory_tag))
        .count()
}

pub(in crate::production::workbench::video_prompt_memory) fn fragment_storyboard_risk_overlap(
    fragment: &str,
    storyboard_tags: &[String],
) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    negative_fragment_storyboard_risk_tags(fragment)
        .iter()
        .filter(|tag| storyboard_tags.iter().any(|value| value == **tag))
        .count()
}

pub(in crate::production::workbench::video_prompt_memory) fn negative_fragment_storyboard_risk_tags(
    fragment: &str,
) -> &'static [&'static str] {
    match canonical_observation_note(fragment).as_str() {
        "avoid rushed motion"
        | "avoid rushed or jerky motion"
        | "avoid flicker"
        | "avoid flicker or motion jitter" => &["motion"],
        "avoid unnecessary shot changes"
        | "avoid extra shot changes or wrong framing"
        | "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => &["framing"],
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette"
        | "avoid distracting neon reflections" => &["lighting"],
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => &["identity"],
        "avoid lip-sync mismatch" => &["dialogue"],
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => &["performance", "dialogue", "emotion"],
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => &["emotion"],
        _ => &[],
    }
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_scene_has_identity_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let has_subject = !normalize_prompt_text(&fields.subject).is_empty();
    if !has_subject {
        return false;
    }

    if rejected_negative_scene_needs_expressive_performance_guard(fields)
        || rejected_negative_scene_has_dialogue_guard(fields)
    {
        return true;
    }

    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "近景",
                "中近景",
                "半身",
                "特写",
                "脸部",
                "面部",
                "肖像",
                "抬眼",
                "回头",
                "对视",
                "凝视",
                "眼神",
                "唇",
                "喉结",
                "眉",
                "泪",
                "close-up",
                "medium close-up",
                "portrait",
                "face",
                "eye",
                "gaze",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(in crate::production::workbench::video_prompt_memory) fn memory_matches_rejected_video_risk_tags(
    content: &str,
    storyboard_tags: &[String],
) -> bool {
    if storyboard_tags.is_empty() {
        return false;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    !memory_tags.is_empty()
        && memory_tags
            .iter()
            .any(|memory_tag| storyboard_tags.iter().any(|tag| tag == memory_tag))
}

pub(in crate::production::workbench::video_prompt_memory) fn storyboard_fallback_priority(
    content: &str,
    storyboard_numeric_id: i32,
    allow_subject_scoped_fallback: bool,
) -> u8 {
    if memory_matches_storyboard(content, storyboard_numeric_id) {
        0
    } else if allow_subject_scoped_fallback {
        1
    } else {
        0
    }
}

fn merged_subject_aliases(existing: &str, incoming: &str, subject: &str) -> String {
    let mut aliases = role_memory_subject_candidates(existing);
    aliases.extend(role_memory_subject_candidates(incoming));
    aliases.retain(|alias| alias != subject);
    aliases.sort();
    aliases.dedup();
    aliases.join("/")
}

#[allow(dead_code)]
pub(in crate::production::workbench::video_prompt_memory) fn merge_rejected_video_negative_memory(
    existing: &str,
    incoming: &str,
) -> String {
    merge_rejected_video_negative_memory_with_bias(existing, incoming, None)
}

fn merge_rejected_video_negative_memory_with_bias(
    existing: &str,
    incoming: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> String {
    let incoming_prompt_seed = rejected_video_memory_prompt_seed(incoming);
    let existing_prompt_seed = rejected_video_memory_prompt_seed(existing);
    if incoming_prompt_seed != existing_prompt_seed {
        return incoming.to_string();
    }

    let storyboard_numeric_id = extract_key_value(incoming, "storyboardIds")
        .or_else(|| extract_key_value(existing, "storyboardIds"))
        .unwrap_or_default();
    let prompt_seed = incoming_prompt_seed
        .or(existing_prompt_seed)
        .unwrap_or_default();
    let subject = extract_key_value(incoming, "subject")
        .or_else(|| extract_key_value(existing, "subject"))
        .unwrap_or_default();
    let subject_aliases = merged_subject_aliases(existing, incoming, &subject);
    let rejection_count = rejected_video_negative_rejection_count(existing).saturating_add(1);
    let bad_case_category = extract_key_value(incoming, "badCaseCategory")
        .or_else(|| extract_key_value(existing, "badCaseCategory"))
        .unwrap_or_default();
    let review_summary = extract_key_value(incoming, "reviewSummary")
        .or_else(|| extract_key_value(existing, "reviewSummary"))
        .unwrap_or_default();
    let avoid = merge_rejected_negative_avoid_with_bias(
        extract_key_value(existing, "avoid").as_deref(),
        extract_key_value(incoming, "avoid").as_deref(),
        bias,
    );
    let risk_tags = merged_rejected_video_risk_tags(existing, incoming, &avoid);
    let focus_tags = merged_rejected_video_focus_tags(existing, incoming, &avoid);

    let mut parts = Vec::new();
    if !storyboard_numeric_id.is_empty() {
        parts.push(format!("storyboardIds={storyboard_numeric_id}"));
    }
    if !prompt_seed.is_empty() {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if !subject.is_empty() {
        parts.push(format!("subject={subject}"));
    }
    if !subject_aliases.is_empty() {
        parts.push(format!("subjectAliases={subject_aliases}"));
    }
    parts.push(format!("rejectionCount={rejection_count}"));
    if !bad_case_category.is_empty() {
        parts.push(format!("badCaseCategory={bad_case_category}"));
    }
    if !review_summary.is_empty() {
        parts.push(format!("reviewSummary={review_summary}"));
    }
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    if !avoid.is_empty() {
        parts.push(format!("avoid={avoid}"));
    }
    parts.join(" | ")
}

fn merged_rejected_video_risk_tags(existing: &str, incoming: &str, avoid: &str) -> Vec<String> {
    let mut tags = extract_rejected_video_risk_tags(existing);
    tags.extend(extract_rejected_video_risk_tags(incoming));
    tags.extend(rejected_video_risk_tags_from_avoid(avoid));
    tags.sort();
    tags.dedup();
    tags
}

fn merged_rejected_video_focus_tags(existing: &str, incoming: &str, avoid: &str) -> Vec<String> {
    let mut tags = extract_rejected_video_focus_tags(existing);
    tags.extend(extract_rejected_video_focus_tags(incoming));
    tags.extend(rejected_video_focus_tags_from_avoid(avoid));
    tags.sort();
    tags.dedup();
    tags
}

pub(in crate::production::workbench::video_prompt_memory) fn memory_matches_subject_candidates(
    content: &str,
    subject_candidates: &[String],
) -> bool {
    memory_subject_match_priority(content, subject_candidates) != usize::MAX
}

pub(in crate::production::workbench::video_prompt_memory) fn memory_subject_match_priority(
    content: &str,
    subject_candidates: &[String],
) -> usize {
    if subject_candidates.is_empty() {
        return usize::MAX;
    }
    let memory_subjects = role_memory_subject_candidates(content);
    if memory_subjects.is_empty() {
        return usize::MAX;
    }

    subject_candidates
        .iter()
        .enumerate()
        .find_map(|(idx, candidate)| {
            memory_subjects
                .iter()
                .any(|memory_subject| {
                    candidate == memory_subject
                        || candidate.contains(memory_subject)
                        || memory_subject.contains(candidate)
                })
                .then_some(idx)
        })
        .unwrap_or(usize::MAX)
}

pub(in crate::production::workbench::video_prompt_memory) fn merge_rejected_negative_avoid_with_bias(
    existing: Option<&str>,
    incoming: Option<&str>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> String {
    let mut fragments = Vec::new();
    for value in [existing, incoming].into_iter().flatten() {
        for fragment in split_prompt_note_fragments(value) {
            if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
                continue;
            }
            fragments.push(fragment);
        }
    }
    compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, bias).join(", ")
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_video_risk_tags_from_avoid(
    avoid: &str,
) -> Vec<String> {
    let mut tags = split_prompt_note_fragments(avoid)
        .flat_map(|fragment| {
            negative_fragment_storyboard_risk_tags(&fragment)
                .iter()
                .map(|tag| (*tag).to_string())
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    tags.sort();
    tags.dedup();
    tags
}

pub(in crate::production::workbench::video_prompt_memory) fn rejected_video_focus_tags_from_avoid(
    avoid: &str,
) -> Vec<String> {
    let mut tags = Vec::new();
    let mut push_tag = |candidate: &str| {
        if !tags.iter().any(|existing| existing == candidate) {
            tags.push(candidate.to_string());
        }
    };

    for fragment in split_prompt_note_fragments(avoid) {
        match observation_note_family(&fragment) {
            "performance_delivery" | "lip_sync" | "mood_tone" => {
                push_tag("delivery_realism");
            }
            "camera_motion_stability" => {
                push_tag("identity_continuity");
            }
            "character_consistency"
            | "shot_change_only"
            | "shot_change_framing"
            | "camera_framing"
            | "rushed_motion"
            | "flicker_motion_jitter" => {
                push_tag("identity_continuity");
            }
            "lighting_backlight" | "lighting_reflection" => {
                push_tag("lighting_realism");
            }
            _ => {}
        }
    }

    tags
}

pub(in crate::production::workbench::video_prompt_memory) fn extract_rejected_video_focus_tags(
    content: &str,
) -> Vec<String> {
    extract_key_value(content, "focusTags")
        .map(|value| {
            value
                .split(['/', ',', ';', '，', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .filter(|tags| !tags.is_empty())
        .unwrap_or_else(|| {
            extract_key_value(content, "avoid")
                .map(|avoid| rejected_video_focus_tags_from_avoid(&avoid))
                .unwrap_or_default()
        })
}

#[allow(dead_code)]
pub(in crate::production::workbench::video_prompt_memory) fn negative_fragment_family(
    value: &str,
) -> &'static str {
    let canonical = canonical_negative_fragment(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" => "shot_change_only",
        "avoid extra shot changes or wrong framing" => "shot_change_framing",
        "avoid rushed motion" | "avoid rushed or jerky motion" => "rushed_motion",
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid distracting neon reflections" => "lighting_reflection",
        "avoid lip-sync mismatch" => "lip_sync_mismatch",
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => "",
    }
}

fn canonical_negative_fragment(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}
