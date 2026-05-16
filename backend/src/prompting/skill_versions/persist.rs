// Feature: ai-drama-quality-optimization
//! 技能文件版本持久化：写入时自动计算 SHA256 并插入 app_skill_versions（需求 24.1, 24.2）

use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use super::models::SkillVersion;

/// 计算字符串内容的 SHA256 十六进制哈希
pub fn sha256_hex(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    format!("{:x}", hasher.finalize())
}

/// 在技能文件写入成功后，自动记录版本到 `app_skill_versions`（需求 24.1, 24.2）
///
/// - `file_path`：相对于 `backend/data/skills/` 的路径
/// - `old_content`：写入前的旧内容（`None` 表示新建文件）
/// - `new_content`：写入后的新内容
/// - `changed_by`：操作用户 UUID
/// - `summary`：变更摘要（不超过 100 字）
pub async fn record_skill_version(
    pool: &PgPool,
    file_path: &str,
    old_content: Option<&str>,
    new_content: &str,
    changed_by: Option<Uuid>,
    summary: Option<&str>,
) -> Result<SkillVersion, sqlx::Error> {
    let hash_before = old_content.map(sha256_hex);
    let hash_after = sha256_hex(new_content);

    // 截断摘要到 100 字
    let summary_trimmed = summary.map(|s| {
        let chars: Vec<char> = s.chars().collect();
        if chars.len() > 100 {
            chars[..100].iter().collect::<String>()
        } else {
            s.to_string()
        }
    });

    let version = sqlx::query_as::<_, SkillVersion>(
        r#"
        INSERT INTO app_skill_versions (file_path, summary, hash_before, hash_after, changed_by, content_snapshot)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
        "#,
    )
    .bind(file_path)
    .bind(summary_trimmed)
    .bind(hash_before)
    .bind(&hash_after)
    .bind(changed_by)
    .bind(new_content)  // 存储内容快照，支持回滚（需求 24.4）
    .fetch_one(pool)
    .await?;

    tracing::info!(
        file_path = %file_path,
        hash_after = %hash_after,
        version_id = %version.id,
        "recorded skill file version"
    );

    Ok(version)
}

/// 查询某文件的版本历史（按 changed_at DESC）
pub async fn list_skill_versions(
    pool: &PgPool,
    file_path: &str,
    limit: i64,
    offset: i64,
) -> Result<Vec<SkillVersion>, sqlx::Error> {
    sqlx::query_as::<_, SkillVersion>(
        r#"
        SELECT * FROM app_skill_versions
        WHERE file_path = $1
        ORDER BY changed_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(file_path)
    .bind(limit.clamp(1, 100))
    .bind(offset.max(0))
    .fetch_all(pool)
    .await
}

#[cfg(test)]
mod tests {
    use super::*;

    // Feature: ai-drama-quality-optimization, Property 15: 技能文件版本记录完整性
    // 验证：需求 6.5, 24.1, 24.2
    // hash_after 必须等于写入内容的 SHA256 哈希值
    #[test]
    fn sha256_hex_is_deterministic() {
        let content = "# 测试技能文件\n\n这是一个测试内容。";
        let h1 = sha256_hex(content);
        let h2 = sha256_hex(content);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64); // SHA256 hex = 64 chars
    }

    #[test]
    fn sha256_hex_differs_for_different_content() {
        let h1 = sha256_hex("content A");
        let h2 = sha256_hex("content B");
        assert_ne!(h1, h2);
    }

    #[test]
    fn sha256_hex_empty_string() {
        let h = sha256_hex("");
        // SHA256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        assert_eq!(
            h,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
    }

    #[test]
    fn sha256_hex_unicode_content() {
        let content = "角色：苏晚卿\n情绪：冷傲轻蔑";
        let h = sha256_hex(content);
        assert_eq!(h.len(), 64);
        // 再次计算应相同
        assert_eq!(h, sha256_hex(content));
    }
}
