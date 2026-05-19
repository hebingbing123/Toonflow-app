//! 项目首页驾驶舱（基础版）：立项信息、readiness、onboarding。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use super::super::super::common::require_project_workspace_member_scope;
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{
    BrandBible, ProjectBrief, ProjectHomeAction, ProjectHomeChecklistItem, ProjectHomeCockpit,
    ProjectHomeLaunchIntent, ProjectHomeMetric, ProjectHomeOnboarding, ProjectHomeResponse,
    ProjectHomeStarterTemplate, ProjectRow, ProjectStatsResponse,
};
use super::super::super::video_count::count_completed_videos_for_project;

#[derive(FromRow)]
struct ProjectHomeRow {
    id: Uuid,
    workspace_id: Option<Uuid>,
    numeric_id: i32,
    name: Option<String>,
    intro: Option<String>,
    project_type: Option<String>,
    text_model: Option<String>,
    multimodal_model: Option<String>,
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
    voice_model: Option<String>,
    voice_profile: Option<String>,
    subtitle_style: Option<String>,
    bgm_strategy: Option<String>,
    quality_gate_strategy: Option<String>,
    project_access_mode: String,
    project_access_role: String,
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

#[derive(Debug, Clone, Copy)]
struct ProjectCockpitSignals {
    ready_storyboard_count: i64,
    blocked_storyboard_count: i64,
    running_generation_job_count: i64,
    pending_review_bad_case_count: i64,
}

fn step_intent(step: &str) -> ProjectHomeLaunchIntent {
    ProjectHomeLaunchIntent::step(step)
}

fn task_center_intent() -> ProjectHomeLaunchIntent {
    ProjectHomeLaunchIntent::action("open_task_center", Some("tasks"))
}

fn step_agent_intent(step: &str, agent_kind: &str) -> ProjectHomeLaunchIntent {
    ProjectHomeLaunchIntent::step_agent(step, agent_kind)
}

fn cockpit_subheadline(score: i32, onboarding: &ProjectHomeOnboarding) -> String {
    let score_line = format!("就绪度 {score}/100");
    match onboarding.next_step.as_deref() {
        Some(step) => format!("{score_line} · 建议：{step}"),
        None => score_line,
    }
}

fn build_cockpit(
    score: i32,
    onboarding: &ProjectHomeOnboarding,
    stats: &ProjectStatsResponse,
    signals: ProjectCockpitSignals,
) -> ProjectHomeCockpit {
    let primary_action = if !onboarding.complete {
        ProjectHomeAction {
            key: "finish_onboarding".into(),
            title: "补全立项信息".into(),
            detail: onboarding
                .next_step
                .as_ref()
                .map(|step| format!("先完成「{step}」，脚本、分镜与成片更顺。"))
                .unwrap_or_else(|| "补齐立项与风格约束，减少后续返工。".into()),
            target_step: "script".into(),
            cta_label: "去补项目设定".into(),
            launch_intent: step_intent("script"),
        }
    } else if stats.novel_count == 0 && stats.script_count == 0 {
        ProjectHomeAction {
            key: "import_source".into(),
            title: "先把上游内容接进来".into(),
            detail: "项目设定已经够用，下一步最值得做的是导入原著、章节或已有剧本，让改写和分镜开始有真实素材。".into(),
            target_step: "script".into(),
            cta_label: "进入脚本阶段".into(),
            launch_intent: step_intent("script"),
        }
    } else if stats.storyboard_count == 0 {
        ProjectHomeAction {
            key: "start_storyboard".into(),
            title: "把脚本推进到分镜".into(),
            detail: "现在已经有内容基础，但还没有可执行的分镜。先把脚本拆到 storyboard，后续出图和视频生成才能形成闭环。".into(),
            target_step: "storyboard".into(),
            cta_label: "去做分镜".into(),
            launch_intent: step_intent("storyboard"),
        }
    } else if signals.blocked_storyboard_count > 0 {
        ProjectHomeAction {
            key: "unblock_storyboards".into(),
            title: "优先补齐可出图镜头".into(),
            detail: format!(
                "当前已有 {} 个镜头，仍有 {} 个没达到可生成状态。先补画面、参考或候选确认，比盲目继续往后走更划算。",
                stats.storyboard_count, signals.blocked_storyboard_count
            ),
            target_step: "storyboard".into(),
            cta_label: "查看分镜缺口".into(),
            launch_intent: step_intent("storyboard"),
        }
    } else if stats.video_count == 0 {
        ProjectHomeAction {
            key: "generate_video".into(),
            title: "开始做第一轮视频结果".into(),
            detail:
                "镜头已经具备生成条件，现在最能提升项目吸引力的动作，就是尽快跑出第一轮视频样片。"
                    .into(),
            target_step: "video".into(),
            cta_label: "进入视频阶段".into(),
            launch_intent: step_intent("video"),
        }
    } else if signals.pending_review_bad_case_count > 0 {
        ProjectHomeAction {
            key: "resolve_quality".into(),
            title: "先清掉待处理质量问题".into(),
            detail: format!(
                "当前已有 {} 条成片结果，但还有 {} 条坏例待处理。先把质量问题收口，再推进交付和发布更稳。",
                stats.video_count, signals.pending_review_bad_case_count
            ),
            target_step: "deliver".into(),
            cta_label: "处理交付风险".into(),
            launch_intent: step_intent("deliver"),
        }
    } else if signals.running_generation_job_count > 0 {
        ProjectHomeAction {
            key: "watch_running_jobs".into(),
            title: "盯住正在跑的生成任务".into(),
            detail: format!(
                "当前有 {} 条任务正在运行，最值得做的是回到视频或交付阶段看进度、处理失败项和回收结果。",
                signals.running_generation_job_count
            ),
            target_step: "video".into(),
            cta_label: "查看生成进度".into(),
            launch_intent: step_intent("video"),
        }
    } else {
        ProjectHomeAction {
            key: "prepare_delivery".into(),
            title: "进入交付与发布检查".into(),
            detail: "项目已经穿过主要生产链路，现在更应该把注意力放在质量、导出和发布前检查上。"
                .into(),
            target_step: "deliver".into(),
            cta_label: "去做交付检查".into(),
            launch_intent: step_intent("deliver"),
        }
    };

    let headline = if stats.video_count > 0 {
        format!(
            "项目已经产出 {} 条视频结果，下一步重点转向收口与交付。",
            stats.video_count
        )
    } else if stats.storyboard_count > 0 {
        format!(
            "项目已有 {} 个镜头，已经进入可成片的中段。",
            stats.storyboard_count
        )
    } else if stats.script_count > 0 || stats.novel_count > 0 {
        "项目已经有内容种子，接下来要尽快把它推进到分镜。".into()
    } else {
        "先跑通第一条成片链路".into()
    };
    let subheadline = cockpit_subheadline(score, onboarding);
    let readiness_launch_intent = primary_action.launch_intent.clone();

    let secondary_actions = vec![
        ProjectHomeAction {
            key: "review_tasks".into(),
            title: "查看生产堵点".into(),
            detail: format!(
                "进行中任务 {} 条，坏例 {} 条，适合先清卡点再继续堆新任务。",
                signals.running_generation_job_count, signals.pending_review_bad_case_count
            ),
            target_step: if signals.pending_review_bad_case_count > 0 {
                "deliver".into()
            } else {
                "video".into()
            },
            cta_label: "看任务与风险".into(),
            launch_intent: task_center_intent(),
        },
        ProjectHomeAction {
            key: "advance_storyboard".into(),
            title: "推进镜头就绪率".into(),
            detail: format!(
                "可生成镜头 {} 个，仍阻塞 {} 个；提高这一项，最直接决定视频阶段效率。",
                signals.ready_storyboard_count, signals.blocked_storyboard_count
            ),
            target_step: "storyboard".into(),
            cta_label: "看镜头状态".into(),
            launch_intent: step_intent("storyboard"),
        },
    ];

    let metrics = vec![
        ProjectHomeMetric {
            key: "readiness".into(),
            label: "项目就绪度".into(),
            value: format!("{score}/100"),
            detail: readiness_summary(score, onboarding),
            launch_intent: readiness_launch_intent,
        },
        ProjectHomeMetric {
            key: "content".into(),
            label: "内容基线".into(),
            value: format!("小说 {} / 剧本 {}", stats.novel_count, stats.script_count),
            detail: "先有内容基线，后面的分镜、素材和视频才不会漂。".into(),
            launch_intent: step_intent("script"),
        },
        ProjectHomeMetric {
            key: "storyboard".into(),
            label: "镜头可执行率".into(),
            value: format!(
                "就绪 {} / 总计 {}",
                signals.ready_storyboard_count, stats.storyboard_count
            ),
            detail: format!(
                "仍有 {} 个镜头需要补素材、参考或候选确认。",
                signals.blocked_storyboard_count
            ),
            launch_intent: step_intent("storyboard"),
        },
        ProjectHomeMetric {
            key: "delivery".into(),
            label: "交付风险".into(),
            value: format!(
                "任务 {} / 坏例 {}",
                signals.running_generation_job_count, signals.pending_review_bad_case_count
            ),
            detail: "把运行中的任务和质量问题压平，项目节奏会稳很多。".into(),
            launch_intent: task_center_intent(),
        },
    ];

    let starter_templates = vec![
        ProjectHomeStarterTemplate {
            key: "starter_manga".into(),
            title: "漫剧改编起步线".into(),
            detail: "先补 brief，再导入原著和剧本，把第一轮分镜尽快拆出来。".into(),
            target_step: "script".into(),
            cta_label: "从脚本开跑".into(),
            launch_intent: step_intent("script"),
        },
        ProjectHomeStarterTemplate {
            key: "starter_trailer".into(),
            title: "样片先行路线".into(),
            detail: "如果目标是先打样，先盯住最少一批可出图镜头，尽快跑出第一条视频结果。".into(),
            target_step: "video".into(),
            cta_label: "先出第一条样片".into(),
            launch_intent: step_agent_intent("video", "grid_prompt_generator"),
        },
        ProjectHomeStarterTemplate {
            key: "starter_delivery".into(),
            title: "交付检查路线".into(),
            detail: "适合已有视频结果的项目，优先收口质量问题、导出阻塞和发布前检查。".into(),
            target_step: "deliver".into(),
            cta_label: "转入交付阶段".into(),
            launch_intent: step_intent("deliver"),
        },
    ];

    let cockpit = ProjectHomeCockpit {
        headline,
        subheadline,
        primary_action,
        secondary_actions,
        metrics,
        starter_templates,
    };
    debug_assert_cockpit_launch_intents(&cockpit);
    cockpit
}

fn debug_assert_cockpit_launch_intents(cockpit: &ProjectHomeCockpit) {
    debug_assert!(
        cockpit.primary_action.launch_intent.has_route(),
        "project home primary action must emit launch_intent",
    );
    debug_assert!(
        cockpit
            .secondary_actions
            .iter()
            .all(|action| action.launch_intent.has_route()),
        "project home secondary actions must emit launch_intent",
    );
    debug_assert!(
        cockpit
            .metrics
            .iter()
            .all(|metric| metric.launch_intent.has_route()),
        "project home metrics must emit launch_intent",
    );
    debug_assert!(
        cockpit
            .starter_templates
            .iter()
            .all(|starter| starter.launch_intent.has_route()),
        "project home starter templates must emit launch_intent",
    );
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
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
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
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let row = sqlx::query_as::<_, ProjectHomeRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
               text_model, multimodal_model, image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_model, voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
               $2 AS project_access_mode,
               $3 AS project_access_role,
               project_brief, brand_bible
        FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(scope.id)
    .bind(scope.access_mode_label())
    .bind(scope.access_role_label())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let script_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM app_script WHERE project_id = $1")
            .bind(scope.id)
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
    .bind(scope.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let role_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM app_asset WHERE project_id = $1 AND asset_type = 'role'",
    )
    .bind(scope.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let novel_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*)::bigint FROM app_novel WHERE project_id = $1")
            .bind(scope.id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let video_count = count_completed_videos_for_project(pool, scope.id)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let ready_storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sc.project_id = $1
          AND (sb.sb_index IS NOT NULL)
          AND (
            TRIM(COALESCE(sb.prompt, '')) <> ''
            OR TRIM(COALESCE(sb.video_desc, '')) <> ''
          )
          AND (TRIM(COALESCE(sb.file_path, '')) <> '')
          AND (
            TRIM(COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')) <> 'pending'
          )
          AND NOT EXISTS (
            SELECT 1
            FROM app_generation_job j
            WHERE j.owner_user_id = $2
              AND j.status IN ('queued', 'running')
              AND j.payload ? 'storyboard_numeric_id'
              AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
              AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
          )
        "#,
    )
    .bind(scope.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let running_generation_job_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT j.id)::bigint
        FROM app_generation_job j
        WHERE j.owner_user_id = $2
          AND j.status IN ('queued', 'running')
          AND (
            j.payload->>'project_numeric_id' = (
              SELECT numeric_id::text FROM app_project WHERE id = $1
            )
            OR EXISTS (
              SELECT 1
              FROM app_storyboard sb
              INNER JOIN app_script sc ON sc.id = sb.script_id
              WHERE sc.project_id = $1
                AND (j.payload->>'storyboard_numeric_id') IS NOT NULL
                AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
            )
          )
        "#,
    )
    .bind(scope.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let pending_review_bad_case_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_quality_review q
        WHERE q.user_id = $2
          AND q.is_bad_case = true
          AND q.project_id = (SELECT numeric_id FROM app_project WHERE id = $1)
        "#,
    )
    .bind(scope.id)
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
            AND numeric_project_id = $2
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
    let blocked_storyboard_count = (storyboard_count - ready_storyboard_count).max(0);
    let cockpit = build_cockpit(
        score,
        &onboarding,
        &stats,
        ProjectCockpitSignals {
            ready_storyboard_count,
            blocked_storyboard_count,
            running_generation_job_count,
            pending_review_bad_case_count,
        },
    );

    Ok(Json(ProjectHomeResponse {
        project: ProjectRow {
            id: row.id,
            workspace_id: row.workspace_id,
            numeric_id: row.numeric_id,
            name: row.name,
            intro: row.intro,
            project_type: row.project_type,
            text_model: row.text_model,
            multimodal_model: row.multimodal_model,
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
            voice_model: row.voice_model,
            voice_profile: row.voice_profile,
            subtitle_style: row.subtitle_style,
            bgm_strategy: row.bgm_strategy,
            quality_gate_strategy: row.quality_gate_strategy,
            project_access_mode: row.project_access_mode,
            project_access_role: row.project_access_role,
        },
        stats,
        project_brief,
        brand_bible,
        readiness_score: score,
        readiness_summary: readiness_summary(score, &onboarding),
        onboarding,
        style_bible_ready,
        cockpit,
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

    #[test]
    fn cockpit_prioritizes_onboarding_before_everything_else() {
        let stats = ProjectStatsResponse {
            script_count: 2,
            storyboard_count: 6,
            role_count: 1,
            novel_count: 1,
            video_count: 0,
        };
        let onboarding = build_onboarding(false, true, &stats, true);
        let cockpit = build_cockpit(
            48,
            &onboarding,
            &stats,
            ProjectCockpitSignals {
                ready_storyboard_count: 4,
                blocked_storyboard_count: 2,
                running_generation_job_count: 1,
                pending_review_bad_case_count: 0,
            },
        );
        assert_eq!(cockpit.primary_action.key, "finish_onboarding");
        assert_eq!(cockpit.primary_action.target_step, "script");
        assert_eq!(
            cockpit
                .metrics
                .first()
                .and_then(|metric| metric.launch_intent.target_step.as_deref()),
            Some("script")
        );
    }

    #[test]
    fn cockpit_readiness_metric_follows_primary_action_intent() {
        let stats = ProjectStatsResponse {
            script_count: 2,
            storyboard_count: 6,
            role_count: 1,
            novel_count: 1,
            video_count: 3,
        };
        let onboarding = build_onboarding(true, true, &stats, true);
        let cockpit = build_cockpit(
            92,
            &onboarding,
            &stats,
            ProjectCockpitSignals {
                ready_storyboard_count: 6,
                blocked_storyboard_count: 0,
                running_generation_job_count: 0,
                pending_review_bad_case_count: 2,
            },
        );
        assert_eq!(
            cockpit.primary_action.launch_intent.target_step.as_deref(),
            Some("deliver")
        );
        assert_eq!(
            cockpit
                .metrics
                .first()
                .and_then(|metric| metric.launch_intent.target_step.as_deref()),
            Some("deliver")
        );
    }

    #[test]
    fn cockpit_pushes_delivery_when_videos_exist_and_bad_cases_pending() {
        let stats = ProjectStatsResponse {
            script_count: 2,
            storyboard_count: 6,
            role_count: 1,
            novel_count: 1,
            video_count: 3,
        };
        let onboarding = build_onboarding(true, true, &stats, true);
        let cockpit = build_cockpit(
            92,
            &onboarding,
            &stats,
            ProjectCockpitSignals {
                ready_storyboard_count: 6,
                blocked_storyboard_count: 0,
                running_generation_job_count: 0,
                pending_review_bad_case_count: 2,
            },
        );
        assert_eq!(cockpit.primary_action.key, "resolve_quality");
        assert_eq!(cockpit.primary_action.target_step, "deliver");
        assert_eq!(
            cockpit.primary_action.launch_intent.target_step.as_deref(),
            Some("deliver")
        );
        assert_eq!(
            cockpit
                .secondary_actions
                .first()
                .and_then(|action| action.launch_intent.action.as_deref()),
            Some("open_task_center")
        );
        assert_eq!(
            cockpit
                .metrics
                .last()
                .and_then(|metric| metric.launch_intent.action.as_deref()),
            Some("open_task_center")
        );
        assert_eq!(
            cockpit
                .starter_templates
                .get(1)
                .and_then(|starter| starter.launch_intent.agent_kind.as_deref()),
            Some("grid_prompt_generator")
        );
    }

    #[test]
    fn cockpit_always_emits_launch_intents_for_actions_metrics_and_starters() {
        let stats = ProjectStatsResponse {
            script_count: 1,
            storyboard_count: 2,
            role_count: 1,
            novel_count: 1,
            video_count: 0,
        };
        let onboarding = build_onboarding(true, true, &stats, true);
        let cockpit = build_cockpit(
            64,
            &onboarding,
            &stats,
            ProjectCockpitSignals {
                ready_storyboard_count: 1,
                blocked_storyboard_count: 1,
                running_generation_job_count: 2,
                pending_review_bad_case_count: 0,
            },
        );

        assert!(cockpit.primary_action.launch_intent.has_route());
        assert!(cockpit
            .secondary_actions
            .iter()
            .all(|action| action.launch_intent.has_route()));
        assert!(cockpit
            .metrics
            .iter()
            .all(|metric| metric.launch_intent.has_route()));
        assert!(cockpit
            .starter_templates
            .iter()
            .all(|starter| starter.launch_intent.has_route()));
    }
}
