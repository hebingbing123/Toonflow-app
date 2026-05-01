use super::*;

const AUTO_SCOPE_MEMORY_NAME: &str = "auto_scope_memory";
const AUTO_SCOPE_MEMORY_KEEP_ROWS: i64 = 18;

pub(crate) fn build_auto_scope_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;

    // Only store continuity guidance when the scene itself is at risk (otherwise the selector
    // will drop it and it becomes noise + token burn).
    let subject_count = fields
        .subject
        .split(['/', '／', '，', ',', '、'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .count()
        .max(1);

    let shot = normalize_prompt_text(&fields.shot);
    let camera_move = normalize_prompt_text(&fields.camera_move);
    let action = normalize_prompt_text(&fields.action);
    let dialogue = normalize_prompt_text(&fields.dialogue);
    let lighting = normalize_prompt_text(&fields.lighting);
    let setting = normalize_prompt_text(&fields.setting);

    let is_close = [
        "特写",
        "近景",
        "近特写",
        "大特写",
        "close-up",
        "portrait",
        "face",
    ]
    .iter()
    .any(|keyword| shot.contains(keyword));
    let is_motion_scene = [
        camera_move.as_str(),
        action.as_str(),
        fields.sound.as_str(),
        fields.setting.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍", "推进", "拉远", "摇镜", "手持", "奔跑", "跑", "冲", "追", "快步", "转身",
                "踉跄", "急退", "闯入", "夺门",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    let has_lighting_risk = [lighting.as_str(), setting.as_str()]
        .into_iter()
        .any(|value| {
            !value.is_empty()
                && [
                    "逆光",
                    "剪影",
                    "霓虹",
                    "反光",
                    "反射",
                    "玻璃",
                    "雨",
                    "车灯",
                    "闪烁",
                    "曝光",
                    "backlight",
                    "silhouette",
                    "reflection",
                    "flicker",
                    "exposure",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        });
    let has_eyeline_axis_risk = subject_count > 1
        && (is_motion_scene
            || ["对视", "视线", "回头", "转身", "看向", "凝视"]
                .iter()
                .any(|keyword| action.contains(keyword) || fields.subject.contains(keyword)));

    let has_identity_risk = is_close
        && subject_count >= 1
        && !shot.is_empty()
        && !matches!(
            dialogue.as_str(),
            "无台词" | "无对白" | "无旁白" | "无语音" | "no dialogue" | "silent"
        );

    let mut fragments: Vec<String> = Vec::new();
    if has_eyeline_axis_risk {
        fragments.push("站位不要跳轴".to_string());
        // Only add eyeline when it is actually present; otherwise it becomes generic noise.
        if ["对视", "视线", "看向", "凝视"]
            .iter()
            .any(|keyword| action.contains(keyword))
        {
            fragments.push("视线方向一致".to_string());
        }
    } else if is_motion_scene && subject_count > 1 {
        fragments.push("镜头方向连续".to_string());
    }
    if has_lighting_risk {
        fragments.push("保持光影连续".to_string());
    }
    if has_identity_risk {
        fragments.push("脸部与服装一致".to_string());
    }

    fragments.dedup();
    fragments.truncate(2);
    let summary = fragments.join("，");
    if summary.is_empty() {
        return None;
    }

    let mut parts = vec![
        // Match existing selector expectations in `meta/generate/builder.rs`.
        "tool=run_sub_agent_production_supervision".to_string(),
        format!("scope=storyboardIds={storyboard_numeric_id}"),
        format!("summary={summary}"),
    ];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!(
            "storyboardPromptSeeds={storyboard_numeric_id}:{prompt_seed}"
        ));
    }
    Some(parts.join(" | "))
}

pub(crate) async fn persist_auto_scope_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    if normalize_prompt_text(content).is_empty() {
        return Ok(());
    }
    let Some(storyboard_numeric_id) = extract_key_value(content, "scope")
        .and_then(|scope| extract_key_value(&scope, "storyboardIds"))
        .or_else(|| extract_key_value(content, "storyboardIds"))
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let storyboard_key = format!("scope=storyboardIds={storyboard_numeric_id}");

    // Deduplicate per storyboard scope: keep latest.
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
    .bind(AUTO_SCOPE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(AUTO_SCOPE_MEMORY_NAME)
    .bind(content)
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
    .bind(AUTO_SCOPE_MEMORY_NAME)
    .bind(AUTO_SCOPE_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_auto_scope_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let storyboard_key = format!("scope=storyboardIds={storyboard_numeric_id}");
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
    .bind(AUTO_SCOPE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
