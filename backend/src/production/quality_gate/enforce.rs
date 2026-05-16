//! Quality gate enforcement: DB loading, run_quality_gate, enforce_quality_gate.

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, parse_structured_storyboard_description, StoryboardPromptSeedRow,
};
use crate::settings::agent_memory::{
    load_project_style_bible_character_anchors, replace_named_summary_memory_with_scope,
};

use super::strategy::QualityGateStrategy;
use super::{
    anti_ai::check_anti_ai_artifacts,
    attribution::{decision_prefers_patch_scope, decision_suggests_attribution},
    contains_any, issue,
    rules::{
        evaluate_storyboard_progression, evaluate_structured_fields, prompt_has_conflict_pair,
        prompt_has_monotone_delivery_risk, prompt_has_visual_conflict,
        quality_review_comment_issues,
    },
    scope_label, scope_signature, QualityGateDecision, QualityGateSeverity, QualityGateStage,
    StoryboardDbRow,
};

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
        WHERE p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
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

async fn load_quality_gate_strategy(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
) -> Result<QualityGateStrategy, ApiError> {
    let strategy_str = sqlx::query_scalar::<_, Option<String>>(
        r#"
        SELECT quality_gate_strategy
        FROM app_project p
        WHERE p.numeric_id = $2
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();

    match strategy_str {
        Some(s) => s.parse().map_err(|e: String| {
            ApiError::BadRequest(format!("invalid quality_gate_strategy: {e}"))
        }),
        None => Ok(QualityGateStrategy::default()),
    }
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
        WHERE p.numeric_id = $2
          AND sc.numeric_id = $3
          AND a.asset_type = 'role'
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
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
        "preferredPatchScope": decision_prefers_patch_scope(decision),
        "attributionModeSuggested": decision_suggests_attribution(decision),
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
) -> Result<(QualityGateDecision, QualityGateStrategy), ApiError> {
    // Load quality gate strategy first
    let strategy = load_quality_gate_strategy(pool, user_id, project_id).await?;

    // If strategy is "off", skip all checks and return empty decision
    if strategy.should_skip_checks() {
        tracing::debug!(
            project_id = project_id,
            stage = stage.as_str(),
            "quality gate checks skipped (strategy=off)"
        );
        return Ok((
            QualityGateDecision {
                blocked: false,
                issues: Vec::new(),
            },
            strategy,
        ));
    }

    let storyboard_rows =
        load_storyboard_rows(pool, user_id, project_id, script_id, storyboard_ids).await?;
    let has_role_rows = has_role_rows(pool, user_id, project_id, script_id).await?;
    let character_anchors =
        load_project_style_bible_character_anchors(pool, user_id, project_id).await?;
    let quality_comments =
        load_recent_quality_comments(pool, user_id, project_id, script_id, stage, storyboard_ids)
            .await?;

    let mut issues = Vec::new();
    let mut storyboard_states = Vec::new();
    let scope = scope_label(storyboard_ids);

    if !has_role_rows && character_anchors.is_empty() && storyboard_rows.is_empty() {
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
            let row_scope = format!("storyboardId={}", row.0);
            if let Some(state) = evaluate_structured_fields(
                &fields,
                row.1.prompt.as_deref(),
                &row_scope,
                &character_anchors,
                &mut issues,
            ) {
                storyboard_states.push(state);
            }
            issues.extend(check_anti_ai_artifacts(
                &fields,
                row.1.prompt.as_deref(),
                &row_scope,
            ));
        }
    }
    issues.extend(evaluate_storyboard_progression(&storyboard_states));

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
        if prompt_has_conflict_pair(&normalized, &super::GAZE_CONFLICT_PAIRS) {
            issues.push(issue(
                QualityGateSeverity::Severe,
                "gaze_direction_error",
                &super::rework_suggestion("文本里已经出现明显视线冲突，先修正人物目光方向。"),
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
    Ok((decision, strategy))
}

pub(crate) fn enforce_quality_gate(
    stage: QualityGateStage,
    decision: &QualityGateDecision,
    strategy: QualityGateStrategy,
) -> Result<(), ApiError> {
    // If strategy is "off", skip all enforcement
    if strategy.should_skip_checks() {
        return Ok(());
    }

    let severe_detected = decision
        .issues
        .iter()
        .any(|issue| issue.severity == QualityGateSeverity::Severe);

    // If strategy is "warn", log issues but don't block
    if strategy.should_warn() {
        if decision.blocked || severe_detected {
            tracing::warn!(
                stage = stage.as_str(),
                blocked = decision.blocked,
                severe_count = decision
                    .issues
                    .iter()
                    .filter(|i| i.severity == QualityGateSeverity::Severe)
                    .count(),
                minor_count = decision
                    .issues
                    .iter()
                    .filter(|i| i.severity == QualityGateSeverity::Minor)
                    .count(),
                "quality gate issues detected (warn mode - allowing operation to proceed)"
            );
        }
        return Ok(());
    }

    // Strategy is "block" - enforce blocking behavior
    if decision.blocked || severe_detected {
        return Err(ApiError::Conflict(decision_message(stage, decision)));
    }
    Ok(())
}
