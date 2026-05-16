//! 人工复核队列 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::types::{
    CreateReviewQueueBody, GetReviewQueueQuery, ReviewQueueItem, SkipReviewBody, SubmitReviewBody,
};

/// POST /api/v1/benchmark/review-queue - 创建人工复核队列项
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/review-queue",
    operation_id = "createReviewQueueItemV1",
    tag = "benchmark",
    request_body(content = CreateReviewQueueBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ReviewQueueItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_review_queue_item(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateReviewQueueBody>,
) -> Result<Json<ReviewQueueItem>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_body(&body)?;
    let pool = state.require_pool()?;

    ensure_experiment_run_owner(pool, body.experiment_run_id, user_id).await?;

    let experiment_result_id = resolve_experiment_result_id(pool, user_id, &body).await?;
    let review_type = body.review_type.as_deref().unwrap_or("quality");

    if check_duplicate_review(pool, user_id, experiment_result_id, review_type).await? {
        return Err(bad_request_i18n(
            "Equivalent pending review queue item already exists",
            "等价的待处理复核项已存在",
        ));
    }

    let prompt = body.prompt.unwrap_or_else(|| {
        let stage = body.stage.as_deref().unwrap_or("unknown_stage");
        format!("Review benchmark result for stage '{stage}'")
    });
    let rubric_snapshot = body
        .rubric_snapshot
        .unwrap_or_else(|| default_rubric_snapshot(review_type, body.stage.as_deref()));
    let priority = body.priority.unwrap_or(0).clamp(0, 10);

    let created = sqlx::query_as::<_, ReviewQueueItem>(
        r#"
        INSERT INTO app_review_queue (
            owner_user_id,
            experiment_run_id,
            experiment_result_id,
            review_type,
            status,
            priority,
            prompt,
            rubric_snapshot
        ) VALUES ($1, $2, $3, $4, 'pending', $5, $6, $7)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.experiment_run_id)
    .bind(experiment_result_id)
    .bind(review_type)
    .bind(priority)
    .bind(prompt)
    .bind(rubric_snapshot)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(created))
}

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
        return Err(bad_request_i18n(
            &format!("Cannot submit review with status '{}'", existing.status),
            &format!("状态为 '{}' 的复核项无法提交", existing.status),
        ));
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
        WHERE id = $2 AND owner_user_id = $3 AND status = 'pending'
        RETURNING *
        "#,
    )
    .bind(&body.submitted_score)
    .bind(id)
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        bad_request_i18n(
            "Review queue item is no longer pending",
            "复核队列项已不再处于 pending 状态",
        )
    })?;

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
        return Err(bad_request_i18n(
            &format!("Cannot skip review with status '{}'", existing.status),
            &format!("状态为 '{}' 的复核项无法跳过", existing.status),
        ));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 更新状态为 skipped
    let updated = sqlx::query_as::<_, ReviewQueueItem>(
        r#"
        UPDATE app_review_queue
        SET status = 'skipped'
        WHERE id = $1 AND owner_user_id = $2 AND status = 'pending'
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        bad_request_i18n(
            "Review queue item is no longer pending",
            "复核队列项已不再处于 pending 状态",
        )
    })?;

    if let Some(result_id) = updated.experiment_result_id {
        clear_experiment_result_human_review_requirement(&mut tx, result_id).await?;
    }

    tx.commit()
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

pub(super) fn validate_create_body(body: &CreateReviewQueueBody) -> Result<(), ApiError> {
    if let Some(review_type) = body.review_type.as_deref() {
        validate_review_type(review_type)?;
    }

    if body.experiment_result_id.is_none() && (body.variant_id.is_none() || body.case_id.is_none())
    {
        return Err(bad_request_i18n(
            "experimentResultId or both variantId and caseId must be provided",
            "必须提供 experimentResultId，或同时提供 variantId 和 caseId",
        ));
    }

    if let Some(priority) = body.priority {
        if !(0..=10).contains(&priority) {
            return Err(bad_request_i18n(
                "priority must be between 0 and 10",
                "priority 必须在 0 到 10 之间",
            ));
        }
    }

    Ok(())
}

pub(super) fn validate_submit_body(body: &SubmitReviewBody) -> Result<(), ApiError> {
    let Some(score_obj) = body.submitted_score.as_object() else {
        return Err(bad_request_i18n(
            "submitted_score must be a JSON object",
            "submitted_score 必须是 JSON 对象",
        ));
    };

    let Some(overall_score) = score_obj
        .get("overallScore")
        .and_then(|value| value.as_f64())
    else {
        return Err(bad_request_i18n(
            "submitted_score.overallScore must be a number between 0 and 100",
            "submitted_score.overallScore 必须是 0 到 100 之间的数字",
        ));
    };
    if !(0.0..=100.0).contains(&overall_score) {
        return Err(bad_request_i18n(
            "submitted_score.overallScore must be between 0 and 100",
            "submitted_score.overallScore 必须在 0 到 100 之间",
        ));
    }

    if score_obj
        .get("passed")
        .and_then(|value| value.as_bool())
        .is_none()
    {
        return Err(bad_request_i18n(
            "submitted_score.passed must be a boolean",
            "submitted_score.passed 必须是布尔值",
        ));
    }

    if score_obj.contains_key("requiresRework")
        && score_obj
            .get("requiresRework")
            .and_then(|value| value.as_bool())
            .is_none()
    {
        return Err(bad_request_i18n(
            "submitted_score.requiresRework must be a boolean when provided",
            "submitted_score.requiresRework 提供时必须是布尔值",
        ));
    }
    Ok(())
}

pub(super) fn validate_review_type(review_type: &str) -> Result<(), ApiError> {
    const VALID_TYPES: &[&str] = &["quality", "roi"];

    if !VALID_TYPES.contains(&review_type) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid review_type '{}'. Must be one of: {}",
                review_type,
                VALID_TYPES.join(", ")
            ),
            &format!(
                "无效的 review_type '{}'。必须是以下之一：{}",
                review_type,
                VALID_TYPES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn validate_status(status: &str) -> Result<(), ApiError> {
    const VALID_STATUSES: &[&str] = &["pending", "submitted", "skipped"];

    if !VALID_STATUSES.contains(&status) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid status '{}'. Must be one of: {}",
                status,
                VALID_STATUSES.join(", ")
            ),
            &format!(
                "无效的 status '{}'。必须是以下之一：{}",
                status,
                VALID_STATUSES.join("、")
            ),
        ));
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

async fn clear_experiment_result_human_review_requirement(
    tx: &mut sqlx::Transaction<'_, Postgres>,
    result_id: Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE app_experiment_result
        SET requires_human_review = FALSE,
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(result_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn ensure_experiment_run_owner(
    pool: &sqlx::PgPool,
    experiment_run_id: Uuid,
    user_id: Uuid,
) -> Result<(), ApiError> {
    let owned = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS(
            SELECT 1
            FROM app_experiment_run
            WHERE id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(experiment_run_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
}

async fn resolve_experiment_result_id(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    body: &CreateReviewQueueBody,
) -> Result<Option<Uuid>, ApiError> {
    if let Some(experiment_result_id) = body.experiment_result_id {
        let owned = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1
                FROM app_experiment_result r
                JOIN app_experiment_run run ON run.id = r.experiment_run_id
                WHERE r.id = $1
                  AND r.experiment_run_id = $2
                  AND run.owner_user_id = $3
            )
            "#,
        )
        .bind(experiment_result_id)
        .bind(body.experiment_run_id)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        return if owned {
            Ok(Some(experiment_result_id))
        } else {
            Err(ApiError::NotFound)
        };
    }

    let Some(variant_id) = body.variant_id else {
        return Ok(None);
    };
    let Some(case_id) = body.case_id else {
        return Ok(None);
    };

    let resolved = sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT r.id
        FROM app_experiment_result r
        JOIN app_experiment_run run ON run.id = r.experiment_run_id
        WHERE r.experiment_run_id = $1
          AND r.variant_id = $2
          AND r.benchmark_case_id = $3
          AND run.owner_user_id = $4
        ORDER BY r.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(body.experiment_run_id)
    .bind(variant_id)
    .bind(case_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(resolved)
}

fn merged_human_review_score_summary(submitted_score: &serde_json::Value) -> serde_json::Value {
    let mut merged = submitted_score.as_object().cloned().unwrap_or_default();
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

fn default_rubric_snapshot(review_type: &str, stage: Option<&str>) -> serde_json::Value {
    serde_json::json!({
        "reviewType": review_type,
        "stage": stage,
        "requiredFields": ["overallScore", "passed"],
    })
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
    fn test_validate_create_body() {
        let valid_body = CreateReviewQueueBody {
            experiment_run_id: Uuid::new_v4(),
            experiment_result_id: None,
            variant_id: Some(Uuid::new_v4()),
            case_id: Some(Uuid::new_v4()),
            stage: Some("video_prompt".into()),
            review_type: Some("quality".into()),
            priority: Some(1),
            prompt: None,
            rubric_snapshot: None,
        };
        assert!(validate_create_body(&valid_body).is_ok());

        let missing_refs = CreateReviewQueueBody {
            experiment_run_id: Uuid::new_v4(),
            experiment_result_id: None,
            variant_id: None,
            case_id: None,
            stage: None,
            review_type: Some("quality".into()),
            priority: Some(1),
            prompt: None,
            rubric_snapshot: None,
        };
        assert!(validate_create_body(&missing_refs).is_err());
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
