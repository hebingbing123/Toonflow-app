//! 项目首页驾驶舱（基础版）：立项信息、readiness、onboarding。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{
    BrandBible, ProjectBrief, ProjectHomeChecklistItem, ProjectHomeOnboarding, ProjectHomeResponse,
    ProjectRow, ProjectStatsResponse,
};

#[derive(FromRow)]
struct ProjectHomeRow {
    id: Uuid,
    workspace_id: Option<Uuid>,
    numeric_id: i32,
    name: Option<String>,
    intro: Option<String>,
    project_type: Option<String>,
    image_model: Option<String>,
    image_quality: Option<String>,
    video_model: Option<String>,
    art_style: Option<String>,
    director_manual: Option<String>,
    mode: Option<String>,
    video_ratio: Option<String>,
    create_time_ms: Option<i64>,
    art_style_pack: Option<String>,
    story_style_pack: Option<String>,
    target_market: Option<String>,
    target_platforms: Option<Vec<String>>,
    duration_strategy: Option<String>,
    voice_profile: Option<String>,
    subtitle_style: Option<String>,
    bgm_strategy: Option<String>,
    quality_gate_strategy: Option<String>,
    project_brief: Option<Value>,
    brand_bible: Option<Value>,
}

fn has_text(value: Option<&str>) -> bool {
    value.is_some_and(|text| !text.trim().is_empty())
}

fn brief_ready(brief: Option<&ProjectBrief>) -> bool {
    let Some(brief) = brief else {
        return false;
    };
    [
        brief.premise.as_deref(),
        brief.target_audience.as_deref(),
        brief.emotional_tone.as_deref(),
        brief.core_hook.as_deref(),
        brief.visual_direction.as_deref(),
    ]
    .into_iter()
    .filter(|value| has_text(*value))
    .count()
        >= 3
}

fn brand_bible_ready(brand_bible: Option<&BrandBible>) -> bool {
    let Some(brand_bible) = brand_bible else {
        return false;
    };
    has_text(brand_bible.brand_name.as_deref())
        || has_text(brand_bible.brand_promise.as_deref())
        || !brand_bible.visual_motifs.is_empty()
        || !brand_bible.forbidden_elements.is_empty()
        || !brand_bible.continuity_rules.is_empty()
}

fn build_onboarding(
    brief_ready: bool,
    brand_bible_ready: bool,
    stats: &ProjectStatsResponse,
    style_bible_ready: bool,
) -> ProjectHomeOnboarding {
    let checklist = vec![
        ProjectHomeChecklistItem {
            key: "brief".into(),
            label: "补全项目立项信息".into(),
            done: brief_ready,
            detail: Some("至少写清 premise / audience / tone / hook 中的 3 项".into()),
        },
        ProjectHomeChecklistItem {
            key: "brand_bible".into(),
            label: "补全品牌圣经基础约束".into(),
            done: brand_bible_ready,
            detail: Some("先把品牌承诺、视觉母题或禁区写清，减少后续风格跑偏".into()),
        },
        ProjectHomeChecklistItem {
            key: "source".into(),
            label: "接入上游内容".into(),
            done: stats.novel_count > 0 || stats.script_count > 0,
            detail: Some("至少导入章节或已有剧本，项目才能继续向改写和分镜推进".into()),
        },
        ProjectHomeChecklistItem {
            key: "style_bible".into(),
            label: "准备风格基线".into(),
            done: style_bible_ready,
            detail: Some("项目级 style bible 模板已初始化并具备有效内容".into()),
        },
    ];
    let next_step = checklist
        .iter()
        .find(|item| !item.done)
        .map(|item| item.label.clone());
    ProjectHomeOnboarding {
        complete: next_step.is_none(),
        next_step,
        checklist,
    }
}

fn readiness_score(
    brief_ready: bool,
    brand_bible_ready: bool,
    style_bible_ready: bool,
    stats: &ProjectStatsResponse,
) -> i32 {
    let mut score = 0;
    if brief_ready {
        score += 25;
    }
    if brand_bible_ready {
        score += 20;
    }
    if style_bible_ready {
        score += 15;
    }
    if stats.novel_count > 0 || stats.script_count > 0 {
        score += 15;
    }
    if stats.script_count > 0 {
        score += 10;
    }
    if stats.storyboard_count > 0 {
        score += 10;
    }
    if stats.role_count > 0 {
        score += 5;
    }
    score.clamp(0, 100)
}

fn readiness_summary(score: i32, onboarding: &ProjectHomeOnboarding) -> String {
    if onboarding.complete {
        return "项目基础立项已就绪，可以继续推进内容接入、改写和分镜生产。".into();
    }
    if score >= 70 {
        return "项目基础信息已经接近可用，优先补最后一项 onboarding 缺口。".into();
    }
    if score >= 40 {
        return "项目已有部分基础，但仍缺少关键立项或风格约束，先补首页清单。".into();
    }
    "项目仍处在立项早期，先把 brief、brand bible 和上游内容入口补完整。".into()
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/home",
    operation_id = "getProjectHomeByIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectHomeResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_home_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectHomeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let row = sqlx::query_as::<_, ProjectHomeRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
               project_brief, brand_bible
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let script_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM app_script WHERE project_id = $1")
            .bind(project_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script s ON sb.script_id = s.id
        WHERE s.project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let role_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM app_asset WHERE project_id = $1 AND asset_type = 'role'",
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let novel_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM app_novel WHERE project_id = $1")
            .bind(project_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let video_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $2
          AND status = 'succeeded'
          AND (kind ILIKE '%video%' OR kind ILIKE '%workbench%')
          AND payload->>'project_numeric_id' = (
              SELECT numeric_id::text FROM app_project WHERE id = $1
          )
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let style_bible_ready: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
          SELECT 1
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND legacy_project_id = $2
            AND agent_type = 'productionAgent'
            AND name = 'style_bible:project'
            AND NULLIF(TRIM(content), '') IS NOT NULL
            AND content NOT LIKE '%"characters":[]%'
        )
        "#,
    )
    .bind(uid)
    .bind(row.numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_brief = row
        .project_brief
        .map(serde_json::from_value::<ProjectBrief>)
        .transpose()
        .map_err(|e| ApiError::BadRequest(format!("invalid project_brief in storage: {e}")))?;
    let brand_bible = row
        .brand_bible
        .map(serde_json::from_value::<BrandBible>)
        .transpose()
        .map_err(|e| ApiError::BadRequest(format!("invalid brand_bible in storage: {e}")))?;

    let stats = ProjectStatsResponse {
        script_count,
        storyboard_count,
        role_count,
        novel_count,
        video_count,
    };
    let brief_ready = brief_ready(project_brief.as_ref());
    let brand_bible_ready = brand_bible_ready(brand_bible.as_ref());
    let onboarding = build_onboarding(brief_ready, brand_bible_ready, &stats, style_bible_ready);
    let score = readiness_score(brief_ready, brand_bible_ready, style_bible_ready, &stats);

    Ok(Json(ProjectHomeResponse {
        project: ProjectRow {
            id: row.id,
            workspace_id: row.workspace_id,
            numeric_id: row.numeric_id,
            name: row.name,
            intro: row.intro,
            project_type: row.project_type,
            image_model: row.image_model,
            image_quality: row.image_quality,
            video_model: row.video_model,
            art_style: row.art_style,
            director_manual: row.director_manual,
            mode: row.mode,
            video_ratio: row.video_ratio,
            create_time_ms: row.create_time_ms,
            art_style_pack: row.art_style_pack,
            story_style_pack: row.story_style_pack,
            target_market: row.target_market,
            target_platforms: row.target_platforms,
            duration_strategy: row.duration_strategy,
            voice_profile: row.voice_profile,
            subtitle_style: row.subtitle_style,
            bgm_strategy: row.bgm_strategy,
            quality_gate_strategy: row.quality_gate_strategy,
        },
        stats,
        project_brief,
        brand_bible,
        readiness_score: score,
        readiness_summary: readiness_summary(score, &onboarding),
        onboarding,
        style_bible_ready,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn brief_ready_requires_three_meaningful_fields() {
        let brief = ProjectBrief {
            premise: Some("宫廷复仇".into()),
            target_audience: Some("女性向".into()),
            emotional_tone: Some("压抑反杀".into()),
            core_hook: None,
            visual_direction: None,
        };
        assert!(brief_ready(Some(&brief)));
    }

    #[test]
    fn onboarding_marks_early_project_incomplete() {
        let stats = ProjectStatsResponse {
            script_count: 0,
            storyboard_count: 0,
            role_count: 0,
            novel_count: 0,
            video_count: 0,
        };
        let onboarding = build_onboarding(false, false, &stats, false);
        assert!(!onboarding.complete);
        assert_eq!(onboarding.next_step.as_deref(), Some("补全项目立项信息"));
    }
}
