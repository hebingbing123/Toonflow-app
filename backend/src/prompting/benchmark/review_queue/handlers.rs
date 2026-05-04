//! 人工复核队列 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{GetReviewQueueQuery, ReviewQueueItem, SkipReviewBody, SubmitReviewBody};

/// GET /api/v1/benchmark/review-queue - 获取人工复核队列
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/review-queue",
    operation_id = "getReviewQueueV1",
    tag = "benchmark",
    params(GetReviewQueueQuery),
    responses(
        (status = 200, description = "OK", body = Vec<ReviewQueueItem>),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_review_queue(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<GetReviewQueueQuery>,
) -> Result<Json<Vec<ReviewQueueItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_get_query(&query)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let offset = query.offset.unwrap_or(0).max(0);

    let mut qb =
        QueryBuilder::<Postgres>::new("SELECT * FROM app_review_queue WHERE owner_user_id = ");
    qb.push_bind(user_id);

    if let Some(experiment_run_id) = query.experiment_run_id {
        qb.push(" AND experiment_run_id = ");
        qb.push_bind(experiment_run_id);
    }
    if let Some(review_type) = &query.review_type {
        qb.push(" AND review_type = ");
        qb.push_bind(review_type);
    }
    if let Some(status) = &query.status {
        qb.push(" AND status = ");
        qb.push_bind(status);
    }

    // 按优先级和创建时间排序
    qb.push(" ORDER BY priority DESC, created_at ASC LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    let items = qb
        .build_query_as::<ReviewQueueItem>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

/// POST /api/v1/benchmark/review-queue/:id/submit - 提交复核结果
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/review-queue/{id}/submit",
    operation_id = "submitReviewV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Review queue item ID")
    ),
    request_body(content = SubmitReviewBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ReviewQueueItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn submit_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<SubmitReviewBody>,
) -> Result<Json<ReviewQueueItem>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_submit_body(&body)?;
    let pool = state.require_pool()?;

    // 验证所有权和状态
    let existing = sqlx::query_as::<_, ReviewQueueItem>(
        "SELECT * FROM app_review_queue WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if existing.status != "pending" {
        return Err(ApiError::BadRequest(format!(
            "Cannot submit review with status '{}'",
            existing.status
        )));
    }

    // 开始事务：更新复核队列项并回写实验结果
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 更新复核队列项
    let updated = sqlx::query_as::<_, ReviewQueueItem>(
        r#"
        UPDATE app_review_queue
        SET status = 'submitted',
            submitted_score = $1,
            submitted_at = NOW()
        WHERE id = $2 AND owner_user_id = $3
        RETURNING *
        "#,
    )
    .bind(&body.submitted_score)
    .bind(id)
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 回写实验结果（需求 5.5）
    if let Some(result_id) = updated.experiment_result_id {
        write_back_to_experiment_result(&mut tx, result_id, &body.submitted_score).await?;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(updated))
}

/// POST /api/v1/benchmark/review-queue/:id/skip - 跳过复核
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/review-queue/{id}/skip",
    operation_id = "skipReviewV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Review queue item ID")
    ),
    request_body(content = SkipReviewBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ReviewQueueItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn skip_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(_body): Json<SkipReviewBody>,
) -> Result<Json<ReviewQueueItem>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 验证所有权和状态
    let existing = sqlx::query_as::<_, ReviewQueueItem>(
        "SELECT * FROM app_review_queue WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if existing.status != "pending" {
        return Err(ApiError::BadRequest(format!(
            "Cannot skip review with status '{}'",
            existing.status
        )));
    }

    // 更新状态为 skipped
    let updated = sqlx::query_as::<_, ReviewQueueItem>(
        r#"
        UPDATE app_review_queue
        SET status = 'skipped'
        WHERE id = $1 AND owner_user_id = $2
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(updated))
}

// ============================================================
// 验证辅助函数
// ============================================================

fn validate_get_query(query: &GetReviewQueueQuery) -> Result<(), ApiError> {
    if let Some(review_type) = &query.review_type {
        validate_review_type(review_type)?;
    }
    if let Some(status) = &query.status {
        validate_status(status)?;
    }
    Ok(())
}

pub(super) fn validate_submit_body(body: &SubmitReviewBody) -> Result<(), ApiError> {
    let Some(score_obj) = body.submitted_score.as_object() else {
        return Err(ApiError::BadRequest(
            "submitted_score must be a JSON object".into(),
        ));
    };

    let Some(overall_score) = score_obj
        .get("overallScore")
        .and_then(|value| value.as_f64())
    else {
        return Err(ApiError::BadRequest(
            "submitted_score.overallScore must be a number between 0 and 100".into(),
        ));
    };
    if !(0.0..=100.0).contains(&overall_score) {
        return Err(ApiError::BadRequest(
            "submitted_score.overallScore must be between 0 and 100".into(),
        ));
    }

    if score_obj
        .get("passed")
        .and_then(|value| value.as_bool())
        .is_none()
    {
        return Err(ApiError::BadRequest(
            "submitted_score.passed must be a boolean".into(),
        ));
    }

    if score_obj.contains_key("requiresRework")
        && score_obj
            .get("requiresRework")
            .and_then(|value| value.as_bool())
            .is_none()
    {
        return Err(ApiError::BadRequest(
            "submitted_score.requiresRework must be a boolean when provided".into(),
        ));
    }
    Ok(())
}

pub(super) fn validate_review_type(review_type: &str) -> Result<(), ApiError> {
    const VALID_TYPES: &[&str] = &["quality", "roi"];

    if !VALID_TYPES.contains(&review_type) {
        return Err(ApiError::BadRequest(format!(
            "Invalid review_type '{}'. Must be one of: {}",
            review_type,
            VALID_TYPES.join(", ")
        )));
    }

    Ok(())
}

pub(super) fn validate_status(status: &str) -> Result<(), ApiError> {
    const VALID_STATUSES: &[&str] = &["pending", "submitted", "skipped"];

    if !VALID_STATUSES.contains(&status) {
        return Err(ApiError::BadRequest(format!(
            "Invalid status '{}'. Must be one of: {}",
            status,
            VALID_STATUSES.join(", ")
        )));
    }

    Ok(())
}

/// 回写复核结果到实验结果（需求 5.5）
async fn write_back_to_experiment_result(
    tx: &mut sqlx::Transaction<'_, Postgres>,
    result_id: Uuid,
    submitted_score: &serde_json::Value,
) -> Result<(), ApiError> {
    let merged_score_summary = merged_human_review_score_summary(submitted_score);

    // 更新实验结果的 score_summary，合并人工复核分数
    sqlx::query(
        r#"
        UPDATE app_experiment_result
        SET score_summary = COALESCE(score_summary, '{}'::jsonb) || $1::jsonb,
            requires_human_review = FALSE,
            updated_at = NOW()
        WHERE id = $2
        "#,
    )
    .bind(merged_score_summary)
    .bind(result_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

fn merged_human_review_score_summary(submitted_score: &serde_json::Value) -> serde_json::Value {
    let mut merged = submitted_score
        .as_object()
        .cloned()
        .unwrap_or_default();
    merged.insert("humanReview".into(), submitted_score.clone());
    serde_json::Value::Object(merged)
}

/// 检查是否存在等价的未完成复核项（需求 5.4）
///
/// 此函数供实验运行模块调用,在创建复核项前检查是否已存在相同的待处理复核。
#[allow(dead_code)] // 预留给实验运行模块使用
pub(crate) async fn check_duplicate_review(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    experiment_result_id: Option<Uuid>,
    review_type: &str,
) -> Result<bool, ApiError> {
    let count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_review_queue
        WHERE owner_user_id = $1
          AND experiment_result_id = $2
          AND review_type = $3
          AND status = 'pending'
        "#,
    )
    .bind(user_id)
    .bind(experiment_result_id)
    .bind(review_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(count > 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_review_type() {
        assert!(validate_review_type("quality").is_ok());
        assert!(validate_review_type("roi").is_ok());
        assert!(validate_review_type("invalid").is_err());
    }

    #[test]
    fn test_validate_status() {
        assert!(validate_status("pending").is_ok());
        assert!(validate_status("submitted").is_ok());
        assert!(validate_status("skipped").is_ok());
        assert!(validate_status("invalid").is_err());
    }

    #[test]
    fn test_validate_submit_body() {
        let valid_body = SubmitReviewBody {
            submitted_score: serde_json::json!({
                "overallScore": 85,
                "passed": true,
                "issues": []
            }),
        };
        assert!(validate_submit_body(&valid_body).is_ok());

        let invalid_body = SubmitReviewBody {
            submitted_score: serde_json::json!("not an object"),
        };
        assert!(validate_submit_body(&invalid_body).is_err());

        let missing_passed = SubmitReviewBody {
            submitted_score: serde_json::json!({"overallScore": 85}),
        };
        assert!(validate_submit_body(&missing_passed).is_err());

        let invalid_score_range = SubmitReviewBody {
            submitted_score: serde_json::json!({"overallScore": 101, "passed": true}),
        };
        assert!(validate_submit_body(&invalid_score_range).is_err());
    }

    #[test]
    fn test_merged_human_review_score_summary_promotes_top_level_fields() {
        let merged = merged_human_review_score_summary(&serde_json::json!({
            "overallScore": 91,
            "passed": true,
            "requiresRework": false,
            "recommendation": "approved"
        }));

        assert_eq!(merged["overallScore"].as_i64(), Some(91));
        assert_eq!(merged["passed"].as_bool(), Some(true));
        assert_eq!(merged["requiresRework"].as_bool(), Some(false));
        assert_eq!(merged["recommendation"].as_str(), Some("approved"));
        assert_eq!(merged["humanReview"]["overallScore"].as_i64(), Some(91));
        assert_eq!(merged["humanReview"]["passed"].as_bool(), Some(true));
    }
}
