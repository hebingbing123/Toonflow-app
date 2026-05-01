// Feature: ai-drama-quality-optimization
//! 技能文件版本回滚逻辑（需求 24.4）

use sqlx::PgPool;
use uuid::Uuid;

use crate::prompting::skills::{read_skill_markdown, skills_root, write_skill_at};

use super::models::{RollbackRequest, RollbackResponse, SkillVersion};
use super::persist::sha256_hex;

/// 将技能文件回滚到指定版本（需求 24.4）
///
/// 流程：
/// 1. 查询目标版本记录，获取 content_snapshot
/// 2. 读取当前文件内容，计算 hash_before
/// 3. 将目标版本的 content_snapshot 写回磁盘
/// 4. 记录回滚操作日志（新版本记录，rollback_of 指向目标版本）
pub async fn rollback_skill_version(
    pool: &PgPool,
    request: &RollbackRequest,
    changed_by: Option<Uuid>,
) -> Result<RollbackResponse, RollbackError> {
    // 1. 查询目标版本记录
    let target_version =
        sqlx::query_as::<_, SkillVersion>("SELECT * FROM app_skill_versions WHERE id = $1")
            .bind(request.target_version_id)
            .fetch_optional(pool)
            .await
            .map_err(RollbackError::Database)?
            .ok_or(RollbackError::VersionNotFound(request.target_version_id))?;

    // 确认目标版本的文件路径与请求一致
    if target_version.file_path != request.file_path {
        return Err(RollbackError::FilePathMismatch {
            requested: request.file_path.clone(),
            found: target_version.file_path.clone(),
        });
    }

    // 获取目标版本的内容快照（需求 24.4 的核心：必须有内容才能真正回滚）
    let target_content = target_version
        .content_snapshot
        .as_deref()
        .ok_or_else(|| RollbackError::NoContentSnapshot(request.target_version_id))?;

    // 2. 读取当前文件内容（用于记录 hash_before）
    let current_content = read_skill_markdown(&request.file_path)
        .map(|doc| doc.content)
        .unwrap_or_default();
    let current_hash = sha256_hex(&current_content);

    // 检查是否已经是目标版本
    if current_hash == target_version.hash_after {
        return Err(RollbackError::AlreadyAtTargetVersion);
    }

    // 3. 将目标版本内容写回磁盘（真正的文件恢复）
    write_skill_at(&skills_root(), &request.file_path, target_content)
        .map_err(|e| RollbackError::FileWrite(format!("{:?}", e)))?;

    // 4. 记录回滚操作日志（需求 24.4 要求记录操作日志）
    let summary = request.summary.as_deref().unwrap_or("版本回滚操作");
    let summary_with_note = format!(
        "{} | 回滚至版本 {}",
        summary,
        &target_version.id.to_string()[..8]
    );

    let new_version = sqlx::query_as::<_, SkillVersion>(
        r#"
        INSERT INTO app_skill_versions (
            file_path, summary, hash_before, hash_after, changed_by, rollback_of, content_snapshot
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
        "#,
    )
    .bind(&request.file_path)
    .bind(&summary_with_note)
    .bind(&current_hash)
    .bind(&target_version.hash_after)
    .bind(changed_by)
    .bind(request.target_version_id)
    .bind(target_content)
    .fetch_one(pool)
    .await
    .map_err(RollbackError::Database)?;

    tracing::info!(
        file_path = %request.file_path,
        rolled_back_to = %request.target_version_id,
        target_hash = %target_version.hash_after,
        current_hash = %current_hash,
        new_version_id = %new_version.id,
        operator = ?changed_by,
        "skill file version rolled back and file content restored"
    );

    Ok(RollbackResponse {
        new_version_id: new_version.id,
        file_path: request.file_path.clone(),
        rolled_back_from: new_version.id,
        rolled_back_to: request.target_version_id,
        hash_after: target_version.hash_after.clone(),
    })
}

/// 回滚操作错误类型
#[derive(Debug)]
pub enum RollbackError {
    Database(sqlx::Error),
    VersionNotFound(Uuid),
    FilePathMismatch {
        requested: String,
        found: String,
    },
    FileWrite(String),
    /// 目标版本没有内容快照（迁移前的旧记录），无法自动恢复文件内容
    NoContentSnapshot(Uuid),
    AlreadyAtTargetVersion,
}

impl std::fmt::Display for RollbackError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RollbackError::Database(e) => write!(f, "数据库错误: {}", e),
            RollbackError::VersionNotFound(id) => write!(f, "版本记录不存在: {}", id),
            RollbackError::FilePathMismatch { requested, found } => {
                write!(f, "文件路径不匹配: 请求 {}, 版本记录 {}", requested, found)
            }
            RollbackError::FileWrite(e) => write!(f, "文件写入失败: {}", e),
            RollbackError::NoContentSnapshot(id) => write!(
                f,
                "版本 {} 没有内容快照（该记录在内容快照功能上线前写入），无法自动恢复文件内容",
                id
            ),
            RollbackError::AlreadyAtTargetVersion => {
                write!(f, "当前文件内容已与目标版本一致，无需回滚")
            }
        }
    }
}
