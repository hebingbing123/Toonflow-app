use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

const DEDUPE_WINDOW_MS: i64 = 60_000;

#[derive(Debug, Clone, PartialEq, Eq)]
enum SkillChangeKind {
    Core {
        file_name: String,
    },
    ArtPack {
        pack_path: String,
        pack_name: String,
        file_name: String,
    },
    StoryPack {
        pack_path: String,
        pack_name: String,
        file_name: String,
    },
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct AffectedProjectRow {
    owner_user_id: Uuid,
    numeric_id: i32,
}

fn pack_display_name(pack_path: &str) -> String {
    pack_path
        .rsplit('/')
        .next()
        .unwrap_or(pack_path)
        .replace('_', " ")
}

fn classify_skill_change(path: &str) -> SkillChangeKind {
    let normalized = path.trim().trim_start_matches('/');
    let parts = normalized.split('/').collect::<Vec<_>>();
    let file_name = parts.last().copied().unwrap_or(normalized).to_string();
    if normalized.starts_with("art_skills/") && parts.len() >= 3 {
        let pack_path = parts[..2].join("/");
        return SkillChangeKind::ArtPack {
            pack_name: pack_display_name(&pack_path),
            pack_path,
            file_name,
        };
    }
    if normalized.starts_with("story_skills/") && parts.len() >= 3 {
        let pack_path = parts[..2].join("/");
        return SkillChangeKind::StoryPack {
            pack_name: pack_display_name(&pack_path),
            pack_path,
            file_name,
        };
    }
    SkillChangeKind::Core { file_name }
}

fn notification_name(kind: &SkillChangeKind) -> String {
    match kind {
        SkillChangeKind::Core { file_name } => format!("skill_change_notice:core:{file_name}"),
        SkillChangeKind::ArtPack { pack_path, .. } => {
            format!("skill_change_notice:art:{}", pack_path.replace('/', "_"))
        }
        SkillChangeKind::StoryPack { pack_path, .. } => {
            format!("skill_change_notice:story:{}", pack_path.replace('/', "_"))
        }
    }
}

fn notification_message(kind: &SkillChangeKind, path: &str) -> String {
    match kind {
        SkillChangeKind::Core { file_name } => format!(
            "核心技能文件已更新：{file_name}（{path}）。建议重新审核相关阶段产出物。"
        ),
        SkillChangeKind::ArtPack {
            pack_name,
            file_name,
            ..
        } => format!(
            "画风技能包已更新：{pack_name} / {file_name}（{path}）。建议重新审核相关素材与分镜产出。"
        ),
        SkillChangeKind::StoryPack {
            pack_name,
            file_name,
            ..
        } => format!(
            "故事风格包已更新：{pack_name} / {file_name}（{path}）。建议重新审核相关故事与导演规划产出。"
        ),
    }
}

async fn notification_table_exists(pool: &PgPool) -> Result<bool, ApiError> {
    sqlx::query_scalar::<_, Option<String>>(r#"SELECT to_regclass('public.app_notification')"#)
        .fetch_one(pool)
        .await
        .map(|value| value.is_some())
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn select_affected_projects(
    pool: &PgPool,
    kind: &SkillChangeKind,
) -> Result<Vec<AffectedProjectRow>, ApiError> {
    let active_modes = vec!["in_progress".to_string(), "active".to_string()];
    let rows = match kind {
        SkillChangeKind::Core { .. } => {
            sqlx::query_as::<_, AffectedProjectRow>(
                r#"
                SELECT owner_user_id, numeric_id
                FROM app_project
                WHERE mode IS NULL
                   OR mode = ANY($1)
                ORDER BY numeric_id ASC
                "#,
            )
            .bind(&active_modes)
            .fetch_all(pool)
            .await
        }
        SkillChangeKind::ArtPack { pack_path, .. } => {
            sqlx::query_as::<_, AffectedProjectRow>(
                r#"
                SELECT owner_user_id, numeric_id
                FROM app_project
                WHERE art_style_pack = $1
                  AND (mode IS NULL OR mode = ANY($2))
                ORDER BY numeric_id ASC
                "#,
            )
            .bind(pack_path)
            .bind(&active_modes)
            .fetch_all(pool)
            .await
        }
        SkillChangeKind::StoryPack { pack_path, .. } => {
            sqlx::query_as::<_, AffectedProjectRow>(
                r#"
                SELECT owner_user_id, numeric_id
                FROM app_project
                WHERE story_style_pack = $1
                  AND (mode IS NULL OR mode = ANY($2))
                ORDER BY numeric_id ASC
                "#,
            )
            .bind(pack_path)
            .bind(&active_modes)
            .fetch_all(pool)
            .await
        }
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows)
}

async fn recent_notification_exists_in_table(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    path: &str,
    changed_at_ms: i64,
) -> Result<bool, ApiError> {
    let changed_at = chrono::DateTime::from_timestamp_millis(changed_at_ms)
        .ok_or_else(|| ApiError::BadRequest("invalid changed_at timestamp".into()))?;
    let changed_at = changed_at.naive_utc();
    sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_notification
          WHERE user_id = $1
            AND project_id = $2
            AND file_path = $3
            AND changed_at >= $4 - INTERVAL '1 minute'
        )
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(path)
    .bind(changed_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn recent_notification_exists_in_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    name: &str,
    changed_at_ms: i64,
) -> Result<bool, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND agent_type = 'system'
            AND name = $3
            AND create_time_ms >= $4
        )
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(name)
    .bind(changed_at_ms - DEDUPE_WINDOW_MS)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn insert_notification_table_row(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    path: &str,
    changed_at_ms: i64,
    message: &str,
) -> Result<(), ApiError> {
    let changed_at = chrono::DateTime::from_timestamp_millis(changed_at_ms)
        .ok_or_else(|| ApiError::BadRequest("invalid changed_at timestamp".into()))?;
    let changed_at = changed_at.naive_utc();
    sqlx::query(
        r#"
        INSERT INTO app_notification (user_id, project_id, file_path, changed_at, message)
        VALUES ($1, $2, $3, $4, $5)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(path)
    .bind(changed_at)
    .bind(message)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn insert_notification_memory_row(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    path: &str,
    changed_at_ms: i64,
    name: &str,
    message: &str,
) -> Result<(), ApiError> {
    let scope_signature = json!({
        "projectId": project_id,
        "filePath": path,
    });
    let content = serde_json::to_string(&json!({
        "filePath": path,
        "changedAt": changed_at_ms,
        "message": message,
    }))
    .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms,
          memory_tier, scope_signature
        )
        VALUES ($1, $2, NULL, 'system', 'message', 'assistant', $3, $4, 0, $5, 'message', $6)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(name)
    .bind(content)
    .bind(changed_at_ms)
    .bind(scope_signature)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) async fn notify_skill_change(
    pool: &PgPool,
    path: &str,
    changed_at_ms: i64,
) -> Result<(), ApiError> {
    let kind = classify_skill_change(path);
    let name = notification_name(&kind);
    let message = notification_message(&kind, path);
    let affected_projects = select_affected_projects(pool, &kind).await?;
    if affected_projects.is_empty() {
        return Ok(());
    }

    let table_exists = notification_table_exists(pool).await?;
    for project in affected_projects {
        if table_exists
            && recent_notification_exists_in_table(
                pool,
                project.owner_user_id,
                project.numeric_id,
                path,
                changed_at_ms,
            )
            .await?
        {
            continue;
        }
        if recent_notification_exists_in_memory(
            pool,
            project.owner_user_id,
            project.numeric_id,
            &name,
            changed_at_ms,
        )
        .await?
        {
            continue;
        }
        let inserted_to_table = if table_exists {
            match insert_notification_table_row(
                pool,
                project.owner_user_id,
                project.numeric_id,
                path,
                changed_at_ms,
                &message,
            )
            .await
            {
                Ok(()) => true,
                Err(error) => {
                    tracing::warn!(
                        file_path = path,
                        project_id = project.numeric_id,
                        error = ?error,
                        "skill change notification table insert failed, falling back to agent memory"
                    );
                    false
                }
            }
        } else {
            false
        };
        if inserted_to_table {
            continue;
        }
        insert_notification_memory_row(
            pool,
            project.owner_user_id,
            project.numeric_id,
            path,
            changed_at_ms,
            &name,
            &message,
        )
        .await?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{classify_skill_change, notification_message, SkillChangeKind};

    #[test]
    fn classify_core_skill_change() {
        assert_eq!(
            classify_skill_change("script_execution_script.md"),
            SkillChangeKind::Core {
                file_name: "script_execution_script.md".to_string()
            }
        );
    }

    #[test]
    fn classify_art_pack_skill_change() {
        assert_eq!(
            classify_skill_change("art_skills/real_people/driector_skills/director_storyboard.md"),
            SkillChangeKind::ArtPack {
                pack_path: "art_skills/real_people".to_string(),
                pack_name: "real people".to_string(),
                file_name: "director_storyboard.md".to_string()
            }
        );
    }

    #[test]
    fn classify_story_pack_skill_change() {
        assert_eq!(
            classify_skill_change(
                "story_skills/Sweet_romance_novel/driector_skills/director_planning_narrative.md"
            ),
            SkillChangeKind::StoryPack {
                pack_path: "story_skills/Sweet_romance_novel".to_string(),
                pack_name: "Sweet romance novel".to_string(),
                file_name: "director_planning_narrative.md".to_string()
            }
        );
    }

    #[test]
    fn notification_message_marks_pack_type() {
        let message = notification_message(
            &SkillChangeKind::StoryPack {
                pack_path: "story_skills/Sweet_romance_novel".to_string(),
                pack_name: "Sweet romance novel".to_string(),
                file_name: "director_planning_narrative.md".to_string(),
            },
            "story_skills/Sweet_romance_novel/driector_skills/director_planning_narrative.md",
        );
        assert!(message.contains("故事风格包已更新"));
        assert!(message.contains("Sweet romance novel"));
    }
}
