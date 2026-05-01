use serde::Serialize;
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::settings::agent_memory::replace_named_summary_memory_with_scope;

use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, parse_structured_storyboard_description, StoryboardPromptSeedRow,
    StructuredStoryboardDescription,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum QualityGateStage {
    StoryboardPanel,
    VideoPrompt,
    VideoGenerate,
}

impl QualityGateStage {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            Self::StoryboardPanel => "storyboard_panel",
            Self::VideoPrompt => "video_prompt",
            Self::VideoGenerate => "video_generate",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) enum QualityGateSeverity {
    Severe,
    Minor,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct QualityGateIssue {
    pub severity: QualityGateSeverity,
    pub issue_type: String,
    pub suggestion: String,
    pub scope: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct QualityGateDecision {
    pub blocked: bool,
    pub issues: Vec<QualityGateIssue>,
}

#[derive(Debug, sqlx::FromRow)]
struct StoryboardDbRow {
    numeric_id: i32,
    prompt: Option<String>,
    video_desc: Option<String>,
    duration: Option<String>,
}

fn scope_signature(storyboard_ids: &[i32]) -> Value {
    json!({ "storyboardIds": storyboard_ids })
}

fn scope_label(storyboard_ids: &[i32]) -> String {
    if storyboard_ids.is_empty() {
        "project".to_string()
    } else {
        format!(
            "storyboardIds={}",
            storyboard_ids
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join(",")
        )
    }
}

fn issue(
    severity: QualityGateSeverity,
    issue_type: &str,
    suggestion: &str,
    scope: &str,
) -> QualityGateIssue {
    QualityGateIssue {
        severity,
        issue_type: issue_type.to_string(),
        suggestion: suggestion.to_string(),
        scope: scope.to_string(),
    }
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

fn prompt_has_monotone_delivery_risk(text: &str) -> bool {
    contains_any(
        text,
        &[
            "平静地说",
            "缓缓说道",
            "面无表情",
            "没有情绪",
            "语气平",
            "机械",
            "朗读感",
        ],
    )
}

fn prompt_has_visual_conflict(text: &str) -> bool {
    (contains_any(text, &["冷光", "冷调", "冷色"]) && contains_any(text, &["暖光", "暖调", "暖色"]))
        || (text.contains("近景") && text.contains("远景"))
        || (text.contains("静止") && contains_any(text, &["狂奔", "猛冲", "高速跟拍"]))
}

fn evaluate_structured_fields(
    fields: &StructuredStoryboardDescription,
    scope: &str,
    issues: &mut Vec<QualityGateIssue>,
) {
    if fields.subject.trim().is_empty() {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "character_missing",
            "先补充主镜头人物主体和身份锚点，再继续进入高成本阶段。",
            scope,
        ));
    }
    if fields.mood.trim().is_empty()
        || contains_any(&fields.mood, &["平静", "普通", "淡淡", "无波澜"])
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "emotion_flat",
            "为当前镜头补一个明确情绪目标和表情/呼吸细节，避免人物全程同一状态。",
            scope,
        ));
    }
    if fields.camera_move.trim().is_empty()
        && !contains_any(
            &fields.action,
            &["转身", "停住", "逼近", "后退", "抬眼", "冲", "跑", "贴近"],
        )
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "pacing_flat",
            "补充镜头调度或动作变化，避免分镜节奏过平。",
            scope,
        ));
    }
    if prompt_has_visual_conflict(
        &[
            fields.shot.as_str(),
            fields.camera_move.as_str(),
            fields.lighting.as_str(),
        ]
        .join(" "),
    ) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "visual_conflict",
            "先统一镜头景别、灯光和运动方向，避免视觉指令互相冲突。",
            scope,
        ));
    }
    if !fields.dialogue.trim().is_empty()
        && !contains_any(
            &[
                fields.dialogue.as_str(),
                fields.action.as_str(),
                fields.mood.as_str(),
            ]
            .join(" "),
            &[
                "低声", "停顿", "哽咽", "抿唇", "抽气", "压着", "强忍", "冷笑", "含泪",
            ],
        )
    {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "monotone_dialogue_risk",
            "给台词补充情绪起伏或微表演线索，避免像机械朗读。",
            scope,
        ));
    }
}

fn quality_review_comment_issues(comment: &str, scope: &str) -> Vec<QualityGateIssue> {
    let mut issues = Vec::new();
    if contains_any(comment, &["跳轴", "视线错误", "站位错", "连续性错误"]) {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "visual_conflict",
            "先修复人物站位、视线或镜头方向连续性，再继续高成本生成。",
            scope,
        ));
    }
    if contains_any(comment, &["情绪平", "没情绪", "生硬", "朗读", "台词假"]) {
        issues.push(issue(
            QualityGateSeverity::Minor,
            "monotone_dialogue_risk",
            "先补充表情、呼吸、语气或节奏变化，提升人物真实感。",
            scope,
        ));
    }
    issues
}

async fn load_storyboard_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<Vec<(i32, StoryboardPromptSeedRow)>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(Vec::new());
    }
    let rows = sqlx::query_as::<_, StoryboardDbRow>(
        r#"
        SELECT sb.numeric_id, sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
        ORDER BY sb.numeric_id ASC
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows
        .into_iter()
        .map(|row| {
            (
                row.numeric_id,
                StoryboardPromptSeedRow {
                    prompt: row.prompt,
                    video_desc: row.video_desc,
                    duration: row.duration,
                },
            )
        })
        .collect())
}

async fn has_role_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
) -> Result<bool, ApiError> {
    sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        INNER JOIN app_script sc ON sc.id = sa.script_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND a.asset_type = 'role'
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_one(pool)
    .await
    .map(|count| count > 0)
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn load_recent_quality_comments(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
) -> Result<Vec<String>, ApiError> {
    let upstream_stage = match stage {
        QualityGateStage::StoryboardPanel => "storyboard_table",
        QualityGateStage::VideoPrompt => "storyboard_panel",
        QualityGateStage::VideoGenerate => "video_prompt",
    };
    let target_ids = storyboard_ids
        .iter()
        .map(i32::to_string)
        .collect::<Vec<_>>();
    sqlx::query_scalar(
        r#"
        SELECT comments
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND script_id = $3
          AND stage = $4
          AND comments IS NOT NULL
          AND (
            COALESCE(array_length($5::text[], 1), 0) = 0
            OR target_id = ANY($5)
          )
        ORDER BY created_at DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(upstream_stage)
    .bind(&target_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn persist_precheck_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
    decision: &QualityGateDecision,
) -> Result<(), ApiError> {
    if decision.issues.is_empty() {
        return Ok(());
    }
    let name = format!(
        "quality_precheck:{}:{}",
        stage.as_str(),
        if storyboard_ids.is_empty() {
            "project".to_string()
        } else {
            storyboard_ids
                .iter()
                .map(i32::to_string)
                .collect::<Vec<_>>()
                .join("_")
        }
    );
    let content = serde_json::to_string(&json!({
        "stage": stage.as_str(),
        "blocked": decision.blocked,
        "savedHighCostCallCount": if decision.blocked { 1 } else { 0 },
        "issues": decision.issues,
    }))
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    let signature = scope_signature(storyboard_ids);
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        Some(script_id),
        "productionAgent",
        "assistant",
        &name,
        &content,
        "delta_memory",
        Some(&signature),
        None,
    )
    .await
}

fn decision_message(stage: QualityGateStage, decision: &QualityGateDecision) -> String {
    let suggestion = decision
        .issues
        .iter()
        .find(|issue| issue.severity == QualityGateSeverity::Severe)
        .or_else(|| decision.issues.first())
        .map(|issue| issue.suggestion.as_str())
        .unwrap_or("请先最小修复上游质量问题。");
    format!(
        "quality precheck blocked {}: {}",
        stage.as_str(),
        suggestion
    )
}

pub(crate) async fn run_quality_gate(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    stage: QualityGateStage,
    storyboard_ids: &[i32],
    text_inputs: &[String],
) -> Result<QualityGateDecision, ApiError> {
    let storyboard_rows =
        load_storyboard_rows(pool, user_id, project_id, script_id, storyboard_ids).await?;
    let has_role_rows = has_role_rows(pool, user_id, project_id, script_id).await?;
    let quality_comments =
        load_recent_quality_comments(pool, user_id, project_id, script_id, stage, storyboard_ids)
            .await?;

    let mut issues = Vec::new();
    let scope = scope_label(storyboard_ids);

    if !has_role_rows && storyboard_rows.is_empty() {
        issues.push(issue(
            QualityGateSeverity::Severe,
            "character_missing",
            "项目还缺少可用角色锚点，先补角色资产或人物主体信息。",
            &scope,
        ));
    }

    for row in &storyboard_rows {
        if let Some(fields) = row
            .1
            .video_desc
            .as_deref()
            .and_then(parse_structured_storyboard_description)
        {
            evaluate_structured_fields(&fields, &format!("storyboardId={}", row.0), &mut issues);
        }
    }

    for input in text_inputs {
        let normalized = normalize_prompt_text(input);
        if normalized.is_empty() {
            continue;
        }
        if prompt_has_visual_conflict(&normalized) {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "visual_conflict",
                "先删掉互相冲突的镜头/灯光/动作指令，再继续生成。",
                &scope,
            ));
        }
        if prompt_has_monotone_delivery_risk(&normalized) {
            issues.push(issue(
                QualityGateSeverity::Minor,
                "monotone_dialogue_risk",
                "把台词表达改成带情绪和动作细节的表演指令，避免像朗读。",
                &scope,
            ));
        }
        if contains_any(&normalized, &["平稳推进", "轻轻看着前方", "安静站着"]) {
            issues.push(issue(
                QualityGateSeverity::Minor,
                "pacing_flat",
                "增加节奏变化或动作转折，别让整段镜头过于平铺。",
                &scope,
            ));
        }
    }

    for comment in quality_comments {
        issues.extend(quality_review_comment_issues(&comment, &scope));
    }

    issues.sort_by(|left, right| {
        let left_score = matches!(left.severity, QualityGateSeverity::Severe) as i32;
        let right_score = matches!(right.severity, QualityGateSeverity::Severe) as i32;
        right_score
            .cmp(&left_score)
            .then(left.issue_type.cmp(&right.issue_type))
            .then(left.scope.cmp(&right.scope))
    });
    issues.dedup_by(|left, right| {
        left.severity == right.severity
            && left.issue_type == right.issue_type
            && left.scope == right.scope
    });

    let decision = QualityGateDecision {
        blocked: issues
            .iter()
            .any(|issue| issue.severity == QualityGateSeverity::Severe),
        issues,
    };
    if !decision.issues.is_empty() {
        persist_precheck_memory(
            pool,
            user_id,
            project_id,
            script_id,
            stage,
            storyboard_ids,
            &decision,
        )
        .await?;
    }
    Ok(decision)
}

pub(crate) fn enforce_quality_gate(
    stage: QualityGateStage,
    decision: &QualityGateDecision,
) -> Result<(), ApiError> {
    if decision.blocked {
        return Err(ApiError::Conflict(decision_message(stage, decision)));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        enforce_quality_gate, issue, prompt_has_visual_conflict, scope_label, QualityGateDecision,
        QualityGateSeverity, QualityGateStage,
    };
    use crate::error::ApiError;

    #[test]
    fn scope_label_compacts_storyboard_ids() {
        assert_eq!(scope_label(&[3, 9]), "storyboardIds=3,9");
    }

    #[test]
    fn visual_conflict_detector_flags_cold_warm_mix() {
        assert!(prompt_has_visual_conflict("冷光近景同时切成暖光远景"));
    }

    #[test]
    fn enforce_quality_gate_blocks_severe_decision() {
        let decision = QualityGateDecision {
            blocked: true,
            issues: vec![issue(
                QualityGateSeverity::Severe,
                "visual_conflict",
                "先统一镜头语言。",
                "storyboardId=12",
            )],
        };
        let err = enforce_quality_gate(QualityGateStage::VideoPrompt, &decision)
            .expect_err("should block");
        match err {
            ApiError::Conflict(message) => assert!(message.contains("video_prompt")),
            other => panic!("unexpected error: {other:?}"),
        }
    }
}
