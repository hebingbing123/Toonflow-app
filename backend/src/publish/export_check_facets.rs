//! Publish **cover / platform** facets for **`GET …/short-video-export-check`** (deliver gate).

use chrono::Utc;
use serde::Serialize;
use sqlx::types::Json;
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::ApiError;
use crate::publish::platform_registry::spec_for_platform;
use crate::publish::store::{list_drafts, list_targets};
use crate::publish::types::{PublishDraftRow, PublishPrepareIssue, PublishTargetRow};
use crate::publish::validation::prepare_check_for_draft;

/// Per-platform publish readiness (cover + platform_copy), aligned with publish prepare-check.
#[derive(Debug, Clone, Default, Serialize, ToSchema)]
pub struct ShortVideoExportPlatformFacet {
    pub platform_id: String,
    pub missing_cover: bool,
    pub missing_platform_copy: bool,
    pub has_blocking: bool,
    pub gap_codes: Vec<String>,
}

/// Project-level publish facets on export-check (complements per-shot `storyboard_gaps`).
#[derive(Debug, Clone, Default, Serialize, ToSchema)]
pub struct ShortVideoExportPublishFacets {
    pub missing_cover: bool,
    pub missing_target_platforms: bool,
    pub platform_facets: Vec<ShortVideoExportPlatformFacet>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct ShortVideoExportPublishIssue {
    /// **`blocking`** \| **`warning`**
    pub severity: String,
    pub code: String,
    pub detail: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platform_id: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct PublishExportFacetEvaluation {
    pub facets: ShortVideoExportPublishFacets,
    pub issues: Vec<ShortVideoExportPublishIssue>,
}

fn issue_from_prepare(p: &PublishPrepareIssue) -> ShortVideoExportPublishIssue {
    ShortVideoExportPublishIssue {
        severity: p.severity.clone(),
        code: p.code.clone(),
        detail: p.message.clone(),
        platform_id: p.platform_id.clone(),
    }
}

fn synthetic_target_rows(platform_ids: &[String], draft_id: Uuid) -> Vec<PublishTargetRow> {
    let now = Utc::now();
    platform_ids
        .iter()
        .enumerate()
        .map(|(i, pid)| PublishTargetRow {
            id: Uuid::nil(),
            draft_id,
            platform_id: pid.clone(),
            automation_mode: "semi_auto".into(),
            serial_order: i as i32,
            extra: Json(serde_json::Value::Object(Default::default())),
            created_at: now,
            updated_at: now,
        })
        .collect()
}

fn effective_platform_ids(
    project_platforms: &[String],
    targets: &[PublishTargetRow],
) -> Vec<String> {
    if !targets.is_empty() {
        return targets.iter().map(|t| t.platform_id.clone()).collect();
    }
    project_platforms.to_vec()
}

fn is_missing_platform_copy_code(code: &str) -> bool {
    matches!(
        code,
        "missing_platform_copy_block"
            | "platform_copy_not_object"
            | "platform_copy_block_not_object"
    ) || code.starts_with("adapter_")
        || code.starts_with("unknown_platform_copy")
}

fn build_platform_facets(
    issues: &[ShortVideoExportPublishIssue],
) -> Vec<ShortVideoExportPlatformFacet> {
    use std::collections::BTreeMap;

    let mut by_platform: BTreeMap<String, ShortVideoExportPlatformFacet> = BTreeMap::new();

    for issue in issues {
        let pid = issue
            .platform_id
            .as_deref()
            .unwrap_or("__project__")
            .to_string();
        let entry =
            by_platform
                .entry(pid.clone())
                .or_insert_with(|| ShortVideoExportPlatformFacet {
                    platform_id: if pid == "__project__" {
                        String::new()
                    } else {
                        pid.clone()
                    },
                    ..Default::default()
                });
        if !entry.gap_codes.iter().any(|c| c == &issue.code) {
            entry.gap_codes.push(issue.code.clone());
        }
        if issue.code == "missing_cover" {
            entry.missing_cover = true;
        }
        if is_missing_platform_copy_code(&issue.code) {
            entry.missing_platform_copy = true;
        }
        if issue.severity == "blocking" {
            entry.has_blocking = true;
        }
    }

    by_platform
        .into_values()
        .filter(|f| !f.platform_id.is_empty())
        .collect()
}

fn project_only_issues(project_platforms: &[String]) -> Vec<ShortVideoExportPublishIssue> {
    let mut issues = Vec::new();
    if project_platforms.is_empty() {
        issues.push(ShortVideoExportPublishIssue {
            severity: "blocking".into(),
            code: "missing_target_platforms".into(),
            detail: "Project target_platforms is empty; configure at least one publish platform."
                .into(),
            platform_id: None,
        });
        return issues;
    }

    for pid in project_platforms {
        let Some(spec) = spec_for_platform(pid) else {
            issues.push(ShortVideoExportPublishIssue {
                severity: "blocking".into(),
                code: "unknown_platform".into(),
                detail: format!("Unknown platform `{pid}` (not in publish matrix)."),
                platform_id: Some(pid.clone()),
            });
            continue;
        };
        if spec.requires_cover {
            issues.push(ShortVideoExportPublishIssue {
                severity: "blocking".into(),
                code: "missing_cover".into(),
                detail: format!(
                    "{} requires a cover (cover_asset_key); no publish draft is configured yet.",
                    spec.label_zh
                ),
                platform_id: Some(pid.clone()),
            });
        }
        issues.push(ShortVideoExportPublishIssue {
            severity: "warning".into(),
            code: "missing_platform_copy_block".into(),
            detail: format!(
                "No publish draft platform_copy for {}; configure publish copy before distribution.",
                spec.label_zh
            ),
            platform_id: Some(pid.clone()),
        });
    }

    issues
}

/// Evaluate cover/platform publish facets for export-check (reuses publish prepare-check when a draft exists).
#[must_use]
pub fn evaluate_publish_export_facets(
    project_target_platforms: &[String],
    draft: Option<&PublishDraftRow>,
    draft_targets: &[PublishTargetRow],
) -> PublishExportFacetEvaluation {
    let project_platforms: Vec<String> = project_target_platforms
        .iter()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .collect();

    let prepare_issues: Vec<PublishPrepareIssue> = match draft {
        None => project_only_issues(&project_platforms)
            .into_iter()
            .map(|i| PublishPrepareIssue {
                code: i.code,
                message: i.detail,
                platform_id: i.platform_id,
                severity: i.severity,
            })
            .collect(),
        Some(d) => {
            let platform_ids = effective_platform_ids(&project_platforms, draft_targets);
            let targets = if draft_targets.is_empty() {
                synthetic_target_rows(&platform_ids, d.id)
            } else {
                draft_targets.to_vec()
            };
            let mut issues = prepare_check_for_draft(d, &targets);
            if project_platforms.is_empty() {
                issues.insert(
                    0,
                    PublishPrepareIssue {
                        code: "missing_target_platforms".into(),
                        message: "项目未配置 target_platforms；请至少选择一个发布平台。".into(),
                        platform_id: None,
                        severity: "blocking".into(),
                    },
                );
            }
            issues
        }
    };

    let issues: Vec<ShortVideoExportPublishIssue> =
        prepare_issues.iter().map(issue_from_prepare).collect();

    let platform_facets = build_platform_facets(&issues);
    let missing_cover = platform_facets.iter().any(|f| f.missing_cover)
        || issues.iter().any(|i| i.code == "missing_cover");
    let missing_target_platforms =
        project_platforms.is_empty() || issues.iter().any(|i| i.code == "missing_target_platforms");

    PublishExportFacetEvaluation {
        facets: ShortVideoExportPublishFacets {
            missing_cover,
            missing_target_platforms,
            platform_facets,
        },
        issues,
    }
}

/// Load project publish context from Postgres and evaluate export-check publish facets.
pub(crate) async fn load_publish_export_facet_evaluation(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<PublishExportFacetEvaluation, ApiError> {
    let target_platforms: Option<Vec<String>> = sqlx::query_scalar(
        r#"
        SELECT target_platforms
        FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_platforms = target_platforms.unwrap_or_default();
    let drafts = list_drafts(pool, project_id, None).await?;
    let primary_draft = drafts
        .iter()
        .find(|d| d.draft_status.trim() != "archived")
        .or(drafts.first());
    let draft_targets = if let Some(d) = primary_draft {
        list_targets(pool, d.id).await?
    } else {
        Vec::new()
    };

    Ok(evaluate_publish_export_facets(
        &project_platforms,
        primary_draft,
        &draft_targets,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::publish::types::PublishDraftRow;
    use chrono::Utc;
    use serde_json::Value;
    use sqlx::types::Json;

    fn sample_draft(cover: Option<&str>) -> PublishDraftRow {
        PublishDraftRow {
            id: Uuid::new_v4(),
            project_id: Uuid::new_v4(),
            profile_id: None,
            script_id: None,
            video_asset_key: Some("video/demo.mp4".into()),
            cover_asset_key: cover.map(str::to_string),
            title: "title".into(),
            description: "desc".into(),
            tags: vec![],
            platform_copy: Json(Value::Object(Default::default())),
            scheduled_at: None,
            draft_status: "draft".into(),
            metadata: Json(Value::Object(Default::default())),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn missing_target_platforms_blocks() {
        let eval = evaluate_publish_export_facets(&[], None, &[]);
        assert!(eval.facets.missing_target_platforms);
        assert!(eval
            .issues
            .iter()
            .any(|i| i.code == "missing_target_platforms"));
    }

    #[test]
    fn draft_missing_cover_surfaces_per_platform() {
        let draft = sample_draft(None);
        let targets = synthetic_target_rows(&["douyin".to_string()], draft.id);
        let eval = evaluate_publish_export_facets(&["douyin".to_string()], Some(&draft), &targets);
        assert!(eval.facets.missing_cover);
        assert!(eval
            .facets
            .platform_facets
            .iter()
            .any(|f| f.platform_id == "douyin" && f.missing_cover));
    }

    #[test]
    fn draft_with_cover_passes_cover_facet() {
        let draft = sample_draft(Some("cover/demo.png"));
        let targets = synthetic_target_rows(&["douyin".to_string()], draft.id);
        let eval = evaluate_publish_export_facets(&["douyin".to_string()], Some(&draft), &targets);
        assert!(!eval.facets.missing_cover);
    }
}
