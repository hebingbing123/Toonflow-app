//! Resolve Harness WS attach payloads: **`projectUuid`** / **`scriptUuid`** plus legacy numeric ids.

use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id;
use crate::error::ApiError;
use crate::scope::{self, resolve_owned_script_numeric_from_uuid_or_legacy_id};

#[derive(Debug, Clone)]
pub(crate) struct WsResolvedProject {
    /// `app_project.id` when resolved with Postgres; **`None`** only for legacy numeric-only attach without a pool.
    pub project_pk: Option<Uuid>,
    pub project_numeric: i32,
}

pub(crate) async fn resolve_ws_attach_project(
    pool: Option<&PgPool>,
    user_id: Uuid,
    project_uuid: Option<Uuid>,
    project_id_raw: Option<i64>,
) -> Result<WsResolvedProject, ApiError> {
    let legacy = project_id_raw
        .and_then(|v| i32::try_from(v).ok())
        .filter(|&n| n > 0);

    match (project_uuid, legacy) {
        (None, None) => Err(ApiError::BadRequest(
            "Provide projectUuid (preferred) or legacy numeric project_id".into(),
        )),
        (Some(u), legacy_opt) => {
            let Some(pool) = pool else {
                return Err(ApiError::BadRequest(
                    "Database not configured; cannot resolve projectUuid".into(),
                ));
            };
            let (pk, num) = resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
                pool,
                user_id,
                Some(u),
                legacy_opt,
            )
            .await?;
            Ok(WsResolvedProject {
                project_pk: Some(pk),
                project_numeric: num,
            })
        }
        (None, Some(n)) => {
            if let Some(pool) = pool {
                let (pk, num) = resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
                    pool,
                    user_id,
                    None,
                    Some(n),
                )
                .await?;
                Ok(WsResolvedProject {
                    project_pk: Some(pk),
                    project_numeric: num,
                })
            } else {
                Ok(WsResolvedProject {
                    project_pk: None,
                    project_numeric: n,
                })
            }
        }
    }
}

pub(crate) async fn resolve_ws_attach_script_production(
    pool: Option<&PgPool>,
    user_id: Uuid,
    project: &WsResolvedProject,
    script_uuid: Option<Uuid>,
    script_id_raw: Option<i64>,
) -> Result<i32, ApiError> {
    let legacy_script = script_id_raw
        .and_then(|v| i32::try_from(v).ok())
        .filter(|&n| n > 0);

    match (script_uuid, legacy_script) {
        (None, None) => Err(ApiError::BadRequest(
            "Provide scriptUuid (preferred) or legacy numeric script_id".into(),
        )),
        (Some(u), opt_n) => {
            let Some(pool) = pool else {
                return Err(ApiError::BadRequest(
                    "Database not configured; cannot resolve scriptUuid".into(),
                ));
            };
            let pk = project.project_pk.ok_or_else(|| {
                ApiError::BadRequest("Resolve project with database before using scriptUuid".into())
            })?;
            resolve_owned_script_numeric_from_uuid_or_legacy_id(pool, user_id, pk, Some(u), opt_n)
                .await
        }
        (None, Some(sn)) => {
            if let Some(pool) = pool {
                match project.project_pk {
                    Some(pk) => {
                        scope::owned_script_in_project(pool, user_id, pk, sn)
                            .await
                            .map_err(|e| e.into_api_error())?;
                    }
                    None => {
                        scope::owned_script_scope(pool, user_id, project.project_numeric, sn)
                            .await
                            .map_err(|e| e.into_api_error())?;
                    }
                }
                Ok(sn)
            } else {
                Ok(sn)
            }
        }
    }
}
