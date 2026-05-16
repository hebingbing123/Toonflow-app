//! GET /api/v1/quality/bad-case-frequency — 高频 bad case 统计（需求 14.3）。

use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use axum::extract::Query;

use super::super::issue_type::infer_issue_types;
use super::super::types::{BadCaseFrequencyItem, QualityReview};

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct BadCaseFrequencyQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
}

/// GET /api/v1/quality/bad-case-frequency
///
/// 统计近 20 条 bad case 中各问题类型出现频率，count >= 3 标记为高频。
#[utoipa::path(
    get,
    path = "/api/v1/quality/bad-case-frequency",
    operation_id = "getQualityBadCaseFrequencyV1",
    tag = "quality",
    params(BadCaseFrequencyQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_bad_case_frequency(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BadCaseFrequencyQuery>,
) -> Result<Json<Vec<BadCaseFrequencyItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 取最近 20 条 bad case，保留足够字段供 infer_issue_types 使用
    let rows = sqlx::query_as::<_, QualityReview>(
        r#"
        SELECT * FROM app_quality_review
        WHERE user_id = $1
          AND is_bad_case = true
          AND ($2::int IS NULL OR project_id = $2)
          AND ($3::int IS NULL OR script_id = $3)
        ORDER BY created_at DESC
        LIMIT 20
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 按 (issue_type, raw_category) 分组聚合
    use std::collections::HashMap;
    let mut groups: HashMap<String, (Option<String>, i64, Vec<String>)> = HashMap::new();

    for review in &rows {
        let issue_types = infer_issue_types(review);
        // 若推断不出具体类型，归入 raw_category 本身
        let keys: Vec<String> = if issue_types.is_empty() {
            vec![review
                .bad_case_category
                .clone()
                .unwrap_or_else(|| "other".to_string())]
        } else {
            issue_types.iter().map(|t| t.as_str().to_string()).collect()
        };

        for key in keys {
            let entry = groups
                .entry(key.clone())
                .or_insert_with(|| (review.bad_case_category.clone(), 0, Vec::new()));
            entry.1 += 1;
            if entry.2.len() < 3 {
                if let Some(c) = &review.comments {
                    let truncated = if c.chars().count() > 80 {
                        c.chars().take(80).collect::<String>() + "…"
                    } else {
                        c.clone()
                    };
                    entry.2.push(truncated);
                }
            }
        }
    }

    let mut items: Vec<BadCaseFrequencyItem> = groups
        .into_iter()
        .map(
            |(issue_type, (raw_category, count, sample_comments))| BadCaseFrequencyItem {
                is_high_frequency: count >= 3,
                scope: "user".to_string(),
                issue_type,
                raw_category,
                count,
                sample_comments,
            },
        )
        .collect();

    items.sort_by(|a, b| b.count.cmp(&a.count).then(a.issue_type.cmp(&b.issue_type)));

    Ok(Json(items))
}
