//! 项目级统一资产总览（C5）：按 **`asset_type`** 分组，附带 **`candidate_status`** 与关联剧本 **`numeric_id`**。
//!
//! 分镜维度的资产挂载暂无一等 FK；**`linked_script_numeric_ids`** 通过 **`app_script_asset`** 推导，供 Space / 制作编排引用。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::FromRow;
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::super::types::{
    AssetsOverviewCandidateCounts, AssetsOverviewCharacterSummary, AssetsOverviewHub,
    AssetsOverviewHubAction, AssetsOverviewHubMetric, AssetsOverviewItem,
    AssetsOverviewRoleSummary, AssetsOverviewTypeGroup, ProjectAssetsOverviewResponse,
    ProjectHomeLaunchIntent,
};

#[derive(Debug, FromRow)]
struct AssetOverviewDbRow {
    asset_id: Uuid,
    numeric_id: i32,
    name: String,
    asset_type: String,
    candidate_status: Option<String>,
    script_numeric_ids: Vec<i32>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn role_row(
        name: &str,
        script_numeric_ids: &[i32],
        candidate_status: Option<&str>,
    ) -> AssetOverviewDbRow {
        AssetOverviewDbRow {
            asset_id: Uuid::nil(),
            numeric_id: 1,
            name: name.to_string(),
            asset_type: "role".into(),
            candidate_status: candidate_status.map(str::to_string),
            script_numeric_ids: script_numeric_ids.to_vec(),
        }
    }

    fn character_row(
        name: &str,
        asset_id: Option<Uuid>,
        voice_config: serde_json::Value,
    ) -> ProjectCharacterOverviewRow {
        ProjectCharacterOverviewRow {
            character_id: Uuid::nil(),
            name: name.to_string(),
            asset_id,
            asset_name: asset_id.map(|_| "Hero Asset".to_string()),
            voice_config,
            script_numeric_ids: vec![11],
        }
    }

    #[test]
    fn assets_hub_prioritizes_character_anchoring() {
        let hub = build_assets_hub(
            &[role_row("Hero", &[11], Some("linked"))],
            &[character_row("Lead", None, json!({}))],
            &AssetsOverviewCandidateCounts {
                pending: 0,
                linked: 1,
                ignored: 0,
                unset: 0,
            },
        );

        assert_eq!(hub.primary_action.key, "anchor_characters");
        assert_eq!(hub.primary_action.target_step, "assets");
        assert_eq!(
            hub.primary_action.launch_intent.asset_target.as_deref(),
            Some("anchor_characters")
        );
    }

    #[test]
    fn assets_hub_pushes_storyboard_after_asset_library_is_ready() {
        let asset_id = Uuid::new_v4();
        let hub = build_assets_hub(
            &[AssetOverviewDbRow {
                asset_id,
                numeric_id: 1,
                name: "Hero".into(),
                asset_type: "role".into(),
                candidate_status: Some("linked".into()),
                script_numeric_ids: vec![11, 12],
            }],
            &[character_row(
                "Lead",
                Some(asset_id),
                json!({"voice":"alloy"}),
            )],
            &AssetsOverviewCandidateCounts {
                pending: 0,
                linked: 1,
                ignored: 0,
                unset: 0,
            },
        );

        assert_eq!(hub.primary_action.key, "carry_roles_into_storyboard");
        assert_eq!(hub.primary_action.target_step, "storyboard");
        assert_eq!(
            hub.primary_action.launch_intent.target_step.as_deref(),
            Some("storyboard")
        );
        assert_eq!(
            hub.metrics
                .last()
                .and_then(|metric| metric.launch_intent.asset_target.as_deref()),
            Some("carry_roles_into_storyboard")
        );
    }

    #[test]
    fn assets_hub_always_emits_launch_intents_for_primary_and_metrics() {
        let hub = build_assets_hub(
            &[role_row("Hero", &[11, 12], Some("linked"))],
            &[character_row(
                "Lead",
                Some(Uuid::nil()),
                json!({"voice":"alloy"}),
            )],
            &AssetsOverviewCandidateCounts {
                pending: 1,
                linked: 1,
                ignored: 0,
                unset: 0,
            },
        );

        assert!(hub.primary_action.launch_intent.has_route());
        assert!(hub
            .metrics
            .iter()
            .all(|metric| metric.launch_intent.has_route()));
    }
}

#[derive(Debug, FromRow)]
struct ProjectCharacterOverviewRow {
    character_id: Uuid,
    name: String,
    asset_id: Option<Uuid>,
    asset_name: Option<String>,
    voice_config: serde_json::Value,
    script_numeric_ids: Vec<i32>,
}

fn has_meaningful_voice_config(value: &serde_json::Value) -> bool {
    match value {
        serde_json::Value::Null => false,
        serde_json::Value::Object(map) => !map.is_empty(),
        serde_json::Value::Array(items) => !items.is_empty(),
        serde_json::Value::String(text) => !text.trim().is_empty(),
        _ => true,
    }
}

fn asset_intent(asset_target: &str) -> ProjectHomeLaunchIntent {
    ProjectHomeLaunchIntent::asset_target(asset_target)
}

fn storyboard_step_intent() -> ProjectHomeLaunchIntent {
    ProjectHomeLaunchIntent::step("storyboard")
}

fn build_assets_hub(
    role_rows: &[AssetOverviewDbRow],
    character_rows: &[ProjectCharacterOverviewRow],
    candidate_counts: &AssetsOverviewCandidateCounts,
) -> AssetsOverviewHub {
    let anchored_character_count = character_rows
        .iter()
        .filter(|row| row.asset_id.is_some())
        .count();
    let voice_ready_character_count = character_rows
        .iter()
        .filter(|row| has_meaningful_voice_config(&row.voice_config))
        .count();
    let reusable_role_assets_count = role_rows
        .iter()
        .filter(|row| row.script_numeric_ids.len() >= 2)
        .count();
    let role_without_character_count = role_rows
        .iter()
        .filter(|row| {
            !character_rows
                .iter()
                .any(|character| character.asset_id == Some(row.asset_id))
        })
        .count();
    let missing_anchor_count = character_rows
        .iter()
        .filter(|row| row.asset_id.is_none())
        .count();

    let primary_action = if role_rows.is_empty() {
        AssetsOverviewHubAction {
            key: "build_role_library".into(),
            title: "先把角色资产库搭起来".into(),
            detail: "当前项目还没有 role 资产。先把主要角色立住，后面的分镜、提示词和视频一致性才有抓手。".into(),
            target_step: "assets".into(),
            cta_label: "进入资产阶段".into(),
            launch_intent: asset_intent("build_role_library"),
        }
    } else if character_rows.is_empty() {
        AssetsOverviewHubAction {
            key: "define_project_characters".into(),
            title: "把角色表从资产库里定义出来".into(),
            detail: "现在已经有角色资产，但项目角色表还是空的。先把主角、配角和声音配置挂上，后面镜头引用会顺很多。".into(),
            target_step: "assets".into(),
            cta_label: "建立角色表".into(),
            launch_intent: asset_intent("define_project_characters"),
        }
    } else if missing_anchor_count > 0 {
        AssetsOverviewHubAction {
            key: "anchor_characters".into(),
            title: "先补齐角色锚点".into(),
            detail: format!(
                "还有 {} 个项目角色没有挂到具体资产上。先把人设锚住，后面角色一致性和旁白声线都更稳定。",
                missing_anchor_count
            ),
            target_step: "assets".into(),
            cta_label: "补角色锚点".into(),
            launch_intent: asset_intent("anchor_characters"),
        }
    } else if candidate_counts.pending > 0 {
        AssetsOverviewHubAction {
            key: "confirm_candidates".into(),
            title: "优先处理候选资产".into(),
            detail: format!(
                "当前还有 {} 条候选资产待确认。先把候选关系收口，资产库复用才不会继续漂。",
                candidate_counts.pending
            ),
            target_step: "assets".into(),
            cta_label: "确认候选资产".into(),
            launch_intent: asset_intent("confirm_candidates"),
        }
    } else if reusable_role_assets_count == 0 && role_rows.len() >= 2 {
        AssetsOverviewHubAction {
            key: "link_roles_to_scripts".into(),
            title: "让角色资产开始跨剧本复用".into(),
            detail: "现在角色资产还没有形成明显复用。先把主角资产挂到多个剧本或镜头链路上，后面效率会高很多。".into(),
            target_step: "assets".into(),
            cta_label: "整理复用关系".into(),
            launch_intent: asset_intent("link_roles_to_scripts"),
        }
    } else {
        AssetsOverviewHubAction {
            key: "carry_roles_into_storyboard".into(),
            title: "把角色资产带进分镜执行".into(),
            detail: "角色资产、角色表和候选确认都已经初步成形，下一步更值得去分镜阶段检查落镜和引用一致性。".into(),
            target_step: "storyboard".into(),
            cta_label: "进入分镜阶段".into(),
            launch_intent: storyboard_step_intent(),
        }
    };

    let headline = if role_rows.is_empty() {
        "当前项目还没有形成主体资产库。".into()
    } else if missing_anchor_count > 0 {
        format!(
            "项目已有 {} 条角色资产，但还有角色锚点没接好。",
            role_rows.len()
        )
    } else if reusable_role_assets_count > 0 {
        format!(
            "项目已有 {} 条角色资产，其中 {} 条已经出现跨剧本复用。",
            role_rows.len(),
            reusable_role_assets_count
        )
    } else {
        format!(
            "项目已有 {} 条角色资产，开始具备主体库雏形。",
            role_rows.len()
        )
    };
    let subheadline = primary_action.detail.clone();

    let metrics = vec![
        AssetsOverviewHubMetric {
            key: "roles".into(),
            label: "角色资产".into(),
            value: role_rows.len().to_string(),
            detail: format!(
                "其中 {} 条还没有挂到项目角色表。",
                role_without_character_count
            ),
            launch_intent: asset_intent("build_role_library"),
        },
        AssetsOverviewHubMetric {
            key: "characters".into(),
            label: "项目角色表".into(),
            value: format!(
                "{} / {} 已锚定",
                anchored_character_count,
                character_rows.len()
            ),
            detail: format!("带声音配置的角色有 {} 个。", voice_ready_character_count),
            launch_intent: asset_intent(if missing_anchor_count > 0 {
                "anchor_characters"
            } else {
                "define_project_characters"
            }),
        },
        AssetsOverviewHubMetric {
            key: "candidates".into(),
            label: "候选确认".into(),
            value: format!(
                "待处理 {} / 已确认 {}",
                candidate_counts.pending, candidate_counts.linked
            ),
            detail: "候选资产先收口，后面复用关系才稳定。".into(),
            launch_intent: asset_intent("confirm_candidates"),
        },
        AssetsOverviewHubMetric {
            key: "reuse".into(),
            label: "跨剧本复用".into(),
            value: reusable_role_assets_count.to_string(),
            detail: "按已关联两个及以上剧本的角色资产计数。".into(),
            launch_intent: asset_intent(if reusable_role_assets_count == 0 {
                "link_roles_to_scripts"
            } else {
                "carry_roles_into_storyboard"
            }),
        },
    ];

    let character_summaries = character_rows
        .iter()
        .take(6)
        .map(|row| AssetsOverviewCharacterSummary {
            character_id: row.character_id,
            name: row.name.clone(),
            asset_id: row.asset_id,
            asset_name: row.asset_name.clone(),
            linked_script_numeric_ids: row.script_numeric_ids.clone(),
            has_voice_config: has_meaningful_voice_config(&row.voice_config),
            missing_asset_anchor: row.asset_id.is_none(),
        })
        .collect();

    let mut by_asset_character_names: HashMap<Uuid, Vec<String>> = HashMap::new();
    for row in character_rows {
        if let Some(asset_id) = row.asset_id {
            by_asset_character_names
                .entry(asset_id)
                .or_default()
                .push(row.name.clone());
        }
    }
    let reusable_role_assets = role_rows
        .iter()
        .filter(|row| {
            row.script_numeric_ids.len() >= 2
                || by_asset_character_names.contains_key(&row.asset_id)
        })
        .take(6)
        .map(|row| AssetsOverviewRoleSummary {
            asset_id: row.asset_id,
            numeric_id: row.numeric_id,
            name: row.name.clone(),
            candidate_status: row.candidate_status.clone(),
            linked_script_numeric_ids: row.script_numeric_ids.clone(),
            linked_character_names: by_asset_character_names
                .get(&row.asset_id)
                .cloned()
                .unwrap_or_default(),
        })
        .collect();

    let hub = AssetsOverviewHub {
        headline,
        subheadline,
        primary_action,
        metrics,
        character_summaries,
        reusable_role_assets,
    };
    debug_assert_assets_hub_launch_intents(&hub);
    hub
}

fn debug_assert_assets_hub_launch_intents(hub: &AssetsOverviewHub) {
    debug_assert!(
        hub.primary_action.launch_intent.has_route(),
        "assets hub primary action must emit launch_intent",
    );
    debug_assert!(
        hub.metrics
            .iter()
            .all(|metric| metric.launch_intent.has_route()),
        "assets hub metrics must emit launch_intent",
    );
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/assets-overview",
    operation_id = "getProjectAssetsOverviewByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectAssetsOverviewResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_assets_overview_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectAssetsOverviewResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let resolved_id = scope.id;

    let rows: Vec<AssetOverviewDbRow> = sqlx::query_as(
        r#"
        SELECT
          a.id AS asset_id,
          a.numeric_id,
          a.name,
          a.asset_type,
          a.candidate_status,
          COALESCE(
            ARRAY_AGG(DISTINCT s.numeric_id) FILTER (WHERE s.numeric_id IS NOT NULL),
            ARRAY[]::integer[]
          ) AS script_numeric_ids
        FROM app_asset a
        LEFT JOIN app_script_asset sa ON sa.asset_id = a.id
        LEFT JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
        WHERE a.project_id = $1
        GROUP BY a.id, a.numeric_id, a.name, a.asset_type, a.candidate_status
        ORDER BY a.asset_type ASC, a.numeric_id ASC
        "#,
    )
    .bind(resolved_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_count = rows.len() as i64;
    let mut pending = 0_i64;
    let mut linked = 0_i64;
    let mut ignored = 0_i64;
    let mut unset = 0_i64;

    let mut by_type: HashMap<String, Vec<AssetsOverviewItem>> = HashMap::new();

    let mut role_rows: Vec<AssetOverviewDbRow> = Vec::new();
    for r in rows {
        match r.candidate_status.as_deref() {
            Some("pending") => pending += 1,
            Some("linked") => linked += 1,
            Some("ignored") => ignored += 1,
            None => unset += 1,
            Some(_) => unset += 1,
        }

        if r.asset_type == "role" {
            role_rows.push(AssetOverviewDbRow {
                asset_id: r.asset_id,
                numeric_id: r.numeric_id,
                name: r.name.clone(),
                asset_type: r.asset_type.clone(),
                candidate_status: r.candidate_status.clone(),
                script_numeric_ids: r.script_numeric_ids.clone(),
            });
        }

        let item = AssetsOverviewItem {
            asset_id: r.asset_id,
            numeric_id: r.numeric_id,
            name: r.name,
            asset_type: r.asset_type.clone(),
            candidate_status: r.candidate_status,
            linked_script_numeric_ids: r.script_numeric_ids,
        };

        by_type.entry(r.asset_type).or_default().push(item);
    }

    let character_rows: Vec<ProjectCharacterOverviewRow> = sqlx::query_as(
        r#"
        SELECT
          c.id AS character_id,
          c.name,
          c.asset_id,
          a.name AS asset_name,
          c.voice_config,
          COALESCE(
            ARRAY_AGG(DISTINCT s.numeric_id) FILTER (WHERE s.numeric_id IS NOT NULL),
            ARRAY[]::integer[]
          ) AS script_numeric_ids
        FROM app_project_character c
        LEFT JOIN app_asset a
          ON a.id = c.asset_id AND a.project_id = c.project_id
        LEFT JOIN app_script_asset sa
          ON sa.asset_id = c.asset_id
        LEFT JOIN app_script s
          ON s.id = sa.script_id AND s.project_id = c.project_id
        WHERE c.project_id = $1
        GROUP BY c.id, c.name, c.asset_id, a.name, c.voice_config
        ORDER BY c.name ASC
        "#,
    )
    .bind(resolved_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let type_order = ["role", "scene", "tool"];
    let mut by_asset_type: Vec<AssetsOverviewTypeGroup> = Vec::new();
    for t in type_order {
        if let Some(items) = by_type.remove(t) {
            by_asset_type.push(AssetsOverviewTypeGroup {
                asset_type: t.to_string(),
                items,
            });
        }
    }
    for (t, items) in by_type {
        by_asset_type.push(AssetsOverviewTypeGroup {
            asset_type: t,
            items,
        });
    }

    // Compute data version from latest asset updates
    let data_version: Option<String> = sqlx::query_scalar(
        r#"
        SELECT MAX(updated_at)::text
        FROM app_asset
        WHERE project_id = $1
        "#,
    )
    .bind(resolved_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectAssetsOverviewResponse {
        schema_version: 1,
        data_version,
        total_count,
        candidate_counts: AssetsOverviewCandidateCounts {
            pending,
            linked,
            ignored,
            unset,
        },
        by_asset_type,
        hub: build_assets_hub(
            &role_rows,
            &character_rows,
            &AssetsOverviewCandidateCounts {
                pending,
                linked,
                ignored,
                unset,
            },
        ),
    }))
}
