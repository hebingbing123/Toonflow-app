//! 实验启动前依赖校验逻辑。

use anyhow::{bail, Context, Result};
use sqlx::PgPool;
use std::collections::HashSet;
use uuid::Uuid;

use super::types::{CreateVariantBody, ExperimentVariant};

/// 依赖校验错误
#[derive(Debug)]
pub struct ValidationError {
    pub variant_label: String,
    pub missing_dependencies: Vec<String>,
}

impl std::fmt::Display for ValidationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Variant '{}' missing dependencies: {}",
            self.variant_label,
            self.missing_dependencies.join(", ")
        )
    }
}

impl std::error::Error for ValidationError {}

/// 校验变体快照完整性
pub fn validate_variant_snapshot(variant: &CreateVariantBody) -> Result<()> {
    let mut missing = Vec::new();

    if variant.label.trim().is_empty() {
        missing.push("label".to_string());
    }

    // 校验技能快照
    if variant.skill_snapshot.skill_files.is_empty() {
        missing.push("skill_snapshot.skill_files".to_string());
    }

    // 校验提示词快照
    if variant.prompt_snapshot.templates.is_empty() {
        missing.push("prompt_snapshot.templates".to_string());
    }

    // 校验记忆预算档
    if variant.memory_budget_snapshot.budget_tier.is_empty() {
        missing.push("memory_budget_snapshot.budget_tier".to_string());
    }

    // 校验观察治理策略
    if variant.observation_policy_snapshot.observation_note_limit <= 0 {
        missing.push("observation_policy_snapshot.observation_note_limit".to_string());
    }

    // 校验模型路由
    if variant.model_route_snapshot.model_name.is_empty() {
        missing.push("model_route_snapshot.model_name".to_string());
    }

    if !missing.is_empty() {
        bail!(ValidationError {
            variant_label: variant.label.clone(),
            missing_dependencies: missing,
        });
    }

    Ok(())
}

/// 校验实验运行启动前依赖
pub async fn validate_experiment_dependencies(
    pool: &PgPool,
    experiment_id: Uuid,
) -> Result<Vec<ValidationError>> {
    let variants = sqlx::query_as::<_, ExperimentVariant>(
        r#"
        SELECT id, experiment_run_id, label, is_baseline,
               skill_snapshot, prompt_snapshot, memory_budget_snapshot,
               observation_policy_snapshot, model_route_snapshot, notes
        FROM app_experiment_variant
        WHERE experiment_run_id = $1
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .context("Failed to fetch experiment variants")?;

    if variants.is_empty() {
        bail!("Experiment has no variants");
    }

    let mut errors = Vec::new();

    for variant in variants {
        if let Err(e) = validate_variant_snapshot_from_db(&variant) {
            if let Some(validation_error) = e.downcast_ref::<ValidationError>() {
                errors.push(ValidationError {
                    variant_label: validation_error.variant_label.clone(),
                    missing_dependencies: validation_error.missing_dependencies.clone(),
                });
            }
        }
    }

    Ok(errors)
}

/// 从数据库记录校验变体快照
fn validate_variant_snapshot_from_db(variant: &ExperimentVariant) -> Result<()> {
    let mut missing = Vec::new();

    // 校验技能快照
    if let Some(skill_files) = variant.skill_snapshot.get("skillFiles") {
        if !skill_files.is_array() || skill_files.as_array().unwrap().is_empty() {
            missing.push("skill_snapshot.skill_files".to_string());
        }
    } else {
        missing.push("skill_snapshot.skill_files".to_string());
    }

    // 校验提示词快照
    if let Some(templates) = variant.prompt_snapshot.get("templates") {
        if !templates.is_array() || templates.as_array().unwrap().is_empty() {
            missing.push("prompt_snapshot.templates".to_string());
        }
    } else {
        missing.push("prompt_snapshot.templates".to_string());
    }

    // 校验记忆预算档
    if let Some(budget_tier) = variant.memory_budget_snapshot.get("budgetTier") {
        if !budget_tier.is_string() || budget_tier.as_str().unwrap().is_empty() {
            missing.push("memory_budget_snapshot.budget_tier".to_string());
        }
    } else {
        missing.push("memory_budget_snapshot.budget_tier".to_string());
    }

    // 校验观察治理策略
    if let Some(note_limit) = variant
        .observation_policy_snapshot
        .get("observationNoteLimit")
    {
        if !note_limit.is_number() || note_limit.as_i64().unwrap_or(0) <= 0 {
            missing.push("observation_policy_snapshot.observation_note_limit".to_string());
        }
    } else {
        missing.push("observation_policy_snapshot.observation_note_limit".to_string());
    }

    // 校验模型路由
    if let Some(model_name) = variant.model_route_snapshot.get("modelName") {
        if !model_name.is_string() || model_name.as_str().unwrap().is_empty() {
            missing.push("model_route_snapshot.model_name".to_string());
        }
    } else {
        missing.push("model_route_snapshot.model_name".to_string());
    }

    if !missing.is_empty() {
        bail!(ValidationError {
            variant_label: variant.label.clone(),
            missing_dependencies: missing,
        });
    }

    Ok(())
}

/// 校验样本层级
pub fn validate_sample_tier(tier: &str) -> Result<()> {
    match tier {
        "smoke" | "core" | "full" => Ok(()),
        _ => bail!("Invalid sample_tier: must be 'smoke', 'core', or 'full' | 无效的 sample_tier：必须是 'smoke'、'core' 或 'full'"),
    }
}

/// 校验阶段范围
pub fn validate_stage_scope(stages: &[String]) -> Result<()> {
    if stages.is_empty() {
        bail!("stage_scope cannot be empty | stage_scope 不能为空");
    }

    let valid_stages = [
        "story_skeleton",
        "adaptation_strategy",
        "director_planning",
        "storyboard_table",
        "storyboard_panel",
        "video_prompt",
    ];

    let mut seen = HashSet::new();
    for stage in stages {
        if !valid_stages.contains(&stage.as_str()) {
            bail!("Invalid stage: {} | 无效的 stage：{}", stage, stage);
        }
        if !seen.insert(stage.as_str()) {
            bail!("Duplicate stage: {} | 重复的 stage：{}", stage, stage);
        }
    }

    Ok(())
}

pub fn validate_variant_labels(
    variants: &[CreateVariantBody],
    baseline_variant_label: Option<&str>,
) -> Result<()> {
    let mut seen = HashSet::new();
    for variant in variants {
        let label = variant.label.trim();
        if label.is_empty() {
            bail!("Variant label cannot be empty | 变体 label 不能为空");
        }
        if !seen.insert(label.to_string()) {
            bail!(
                "Duplicate variant label: {} | 重复的变体 label：{}",
                label,
                label
            );
        }
    }

    if let Some(baseline_label) = baseline_variant_label.map(str::trim) {
        if !baseline_label.is_empty() && !seen.contains(baseline_label) {
            bail!(
                "baseline_variant_label '{}' does not match any variant label | baseline_variant_label '{}' 未匹配到任何变体",
                baseline_label,
                baseline_label
            );
        }
    }

    Ok(())
}
