//! Resolve Harness WS attach payloads: **`projectUuid`** / **`scriptUuid`** plus legacy numeric ids.

use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id;
use crate::error::{bad_request_i18n, ApiError};
use crate::scope::{self, resolve_owned_script_numeric_from_uuid_or_legacy_id};

#[derive(Debug, Clone)]
pub(crate) struct WsResolvedProject {
    /// `app_project.id` when resolved with Postgres; **`None`** only for legacy numeric-only attach without a pool.
    pub project_pk: Option<Uuid>,
    pub project_numeric: i32,
    /// Populated when Postgres resolves the project row (always when pool is used on success paths).
    pub workspace_id: Option<Uuid>,
}

pub(crate) fn enforce_workspace_uuid_claim(
    resolved_workspace_id: Option<Uuid>,
    claimed: Option<Uuid>,
) -> Result<(), ApiError> {
    let Some(claimed) = claimed else {
        return Ok(());
    };
    let Some(actual) = resolved_workspace_id else {
        return Err(bad_request_i18n(
            "workspaceUuid requires database-backed project resolution",
            "workspaceUuid 需要基于数据库的项目解析",
        ));
    };
    if actual != claimed {
        return Err(bad_request_i18n(
            "workspaceUuid does not match project workspace",
            "workspaceUuid 与项目所属 workspace 不匹配",
        ));
    }
    Ok(())
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
        (None, None) => Err(bad_request_i18n(
            "Provide projectUuid (preferred) or legacy numeric project_id",
            "请提供 projectUuid（推荐）或旧版 numeric project_id",
        )),
        (Some(u), legacy_opt) => {
            let Some(pool) = pool else {
                return Err(bad_request_i18n(
                    "Database not configured; cannot resolve projectUuid",
                    "数据库未配置，无法解析 projectUuid",
                ));
            };
            let (pk, num, ws) = resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
                pool,
                user_id,
                Some(u),
                legacy_opt,
            )
            .await?;
            Ok(WsResolvedProject {
                project_pk: Some(pk),
                project_numeric: num,
                workspace_id: Some(ws),
            })
        }
        (None, Some(n)) => {
            if let Some(pool) = pool {
                let (pk, num, ws) = resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
                    pool,
                    user_id,
                    None,
                    Some(n),
                )
                .await?;
                Ok(WsResolvedProject {
                    project_pk: Some(pk),
                    project_numeric: num,
                    workspace_id: Some(ws),
                })
            } else {
                Ok(WsResolvedProject {
                    project_pk: None,
                    project_numeric: n,
                    workspace_id: None,
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
        (None, None) => Err(bad_request_i18n(
            "Provide scriptUuid (preferred) or legacy numeric script_id",
            "请提供 scriptUuid（推荐）或旧版 numeric script_id",
        )),
        (Some(u), opt_n) => {
            let Some(pool) = pool else {
                return Err(bad_request_i18n(
                    "Database not configured; cannot resolve scriptUuid",
                    "数据库未配置，无法解析 scriptUuid",
                ));
            };
            let pk = project.project_pk.ok_or_else(|| {
                bad_request_i18n(
                    "Resolve project with database before using scriptUuid",
                    "使用 scriptUuid 前需要先通过数据库解析项目",
                )
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

#[cfg(test)]
mod workspace_claim_tests {
    use super::enforce_workspace_uuid_claim;
    use crate::error::ApiError;
    use uuid::Uuid;

    #[test]
    fn claim_ok_when_omitted() {
        enforce_workspace_uuid_claim(Some(Uuid::nil()), None).unwrap();
        enforce_workspace_uuid_claim(None, None).unwrap();
    }

    #[test]
    fn claim_rejects_without_resolved_workspace() {
        let w = Uuid::from_u128(42);
        let err = enforce_workspace_uuid_claim(None, Some(w)).unwrap_err();
        let ApiError::BadRequest(msg) = err else {
            panic!("expected BadRequest");
        };
        assert!(msg.contains("workspaceUuid"));
    }

    #[test]
    fn claim_rejects_mismatch() {
        let a = Uuid::from_u128(1);
        let b = Uuid::from_u128(2);
        assert!(enforce_workspace_uuid_claim(Some(a), Some(b)).is_err());
    }

    #[test]
    fn claim_ok_when_matches() {
        let w = Uuid::from_u128(99);
        enforce_workspace_uuid_claim(Some(w), Some(w)).unwrap();
    }
}
