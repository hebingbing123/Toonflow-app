//! 资产列表查询：计数与行选择（按项目 / 脚本 / 类型 / 名称过滤）。

use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

use crate::error::ApiError;

use super::super::super::models::AssetRow;

pub(super) async fn count_project_assets_filtered(
    pool: &PgPool,
    project_id: Uuid,
    uid: Uuid,
    script_numeric_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
) -> Result<i64, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_numeric_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(DISTINCT a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.id = "#,
        );
        qb.push_bind(project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.numeric_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT COUNT(a.id)::BIGINT
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.id = "#,
        );
        qb.push_bind(project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn select_project_assets_filtered(
    pool: &PgPool,
    project_id: Uuid,
    uid: Uuid,
    script_numeric_id: Option<i32>,
    asset_type: Option<&str>,
    name_ilike: Option<&str>,
    limit_offset: Option<(i64, i64)>,
) -> Result<Vec<AssetRow>, ApiError> {
    let mut qb: QueryBuilder<Postgres> = if let Some(sid) = script_numeric_id {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT DISTINCT a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms, a.candidate_status
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            INNER JOIN app_script_asset sa ON sa.asset_id = a.id
            INNER JOIN app_script s ON s.id = sa.script_id AND s.project_id = a.project_id
            WHERE p.id = "#,
        );
        qb.push_bind(project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb.push(" AND s.numeric_id = ");
        qb.push_bind(sid);
        qb
    } else {
        let mut qb = QueryBuilder::new(
            r#"
            SELECT a.id, a.numeric_id, a.name, a.asset_type, a.description, a.create_time_ms, a.candidate_status
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.id = "#,
        );
        qb.push_bind(project_id);
        qb.push(" AND p.owner_user_id = ");
        qb.push_bind(uid);
        qb
    };
    if let Some(t) = asset_type {
        qb.push(" AND a.asset_type = ");
        qb.push_bind(t);
    }
    if let Some(pat) = name_ilike {
        qb.push(" AND a.name ILIKE ");
        qb.push_bind(pat);
    }
    qb.push(" ORDER BY a.numeric_id ASC ");
    if let Some((lim, off)) = limit_offset {
        qb.push(" LIMIT ");
        qb.push_bind(lim);
        qb.push(" OFFSET ");
        qb.push_bind(off);
    }
    qb.build_query_as::<AssetRow>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
}
