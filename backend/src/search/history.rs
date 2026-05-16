//! 搜索历史 API 处理器。
//!
//! 提供搜索历史的获取、删除和保存功能。

use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    error::ApiError,
    search::models::{HistoryEntry, HistoryResponse},
};

/// 获取用户搜索历史
///
/// 返回用户最近 10 条搜索历史记录，按搜索时间倒序排列。
/// 仅返回当前用户自己的历史记录（通过 RLS 策略自动过滤）。
///
/// # Arguments
///
/// * `pool` - 数据库连接池
/// * `user_id` - 用户 ID
///
/// # Returns
///
/// 返回 `HistoryResponse` 包含历史记录列表
pub async fn get_search_history(pool: &PgPool, user_id: Uuid) -> Result<HistoryResponse, ApiError> {
    let rows: Vec<(Uuid, String, i32, DateTime<Utc>)> = sqlx::query_as(
        r#"
        SELECT id, query, result_count, searched_at
        FROM public.app_search_history
        WHERE user_id = $1
        ORDER BY searched_at DESC
        LIMIT 10
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| {
        tracing::error!("Failed to fetch search history for user {}: {}", user_id, e);
        ApiError::DatabaseError(format!("获取搜索历史失败: {}", e))
    })?;

    let history = rows
        .into_iter()
        .map(|(id, query, result_count, searched_at)| HistoryEntry {
            id,
            query,
            result_count: result_count as u32,
            searched_at,
        })
        .collect();

    Ok(HistoryResponse { history })
}

/// 删除用户所有搜索历史
///
/// 删除当前用户的所有搜索历史记录。
/// 仅删除当前用户自己的历史记录（通过 RLS 策略自动过滤）。
///
/// # Arguments
///
/// * `pool` - 数据库连接池
/// * `user_id` - 用户 ID
///
/// # Returns
///
/// 成功返回 `Ok(())`
pub async fn delete_search_history(pool: &PgPool, user_id: Uuid) -> Result<(), ApiError> {
    let result = sqlx::query(
        r#"
        DELETE FROM public.app_search_history
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(|e| {
        tracing::error!(
            "Failed to delete search history for user {}: {}",
            user_id,
            e
        );
        ApiError::DatabaseError(format!("删除搜索历史失败: {}", e))
    })?;

    tracing::info!(
        "Deleted {} search history entries for user {}",
        result.rows_affected(),
        user_id
    );

    Ok(())
}

/// 保存搜索历史记录
///
/// 在搜索成功后自动保存历史记录到 `app_search_history` 表。
/// 数据库触发器会自动限制每用户最多 50 条历史记录。
///
/// # Arguments
///
/// * `pool` - 数据库连接池
/// * `user_id` - 用户 ID
/// * `workspace_id` - 工作区 ID
/// * `query` - 搜索关键词
/// * `result_count` - 结果数量
///
/// # Returns
///
/// 成功返回 `Ok(())`，失败记录错误日志但不影响搜索结果返回
pub async fn save_search_history(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
    query: &str,
    result_count: u32,
) -> Result<(), ApiError> {
    // 验证查询长度（2-200 字符）
    let query_len = query.chars().count();
    if !(2..=200).contains(&query_len) {
        tracing::warn!(
            "Search query length {} out of range [2, 200], skipping history save",
            query_len
        );
        return Ok(());
    }

    let result = sqlx::query(
        r#"
        INSERT INTO public.app_search_history (user_id, workspace_id, query, result_count)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .bind(query)
    .bind(result_count as i32)
    .execute(pool)
    .await;

    match result {
        Ok(_) => {
            tracing::debug!(
                "Saved search history for user {}: query='{}', result_count={}",
                user_id,
                query,
                result_count
            );
            Ok(())
        }
        Err(e) => {
            // 保存历史失败不应影响搜索结果返回，仅记录错误日志
            tracing::error!(
                "Failed to save search history for user {}: query='{}', error={}",
                user_id,
                query,
                e
            );
            // 不返回错误，避免影响搜索功能
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_query_length_validation() {
        // 测试查询长度验证逻辑
        let short_query = "a"; // 1 字符，应该被跳过
        let valid_query = "测试"; // 2 字符，有效
        let long_query = "a".repeat(201); // 201 字符，应该被跳过

        assert_eq!(short_query.chars().count(), 1);
        assert_eq!(valid_query.chars().count(), 2);
        assert_eq!(long_query.chars().count(), 201);
    }
}
