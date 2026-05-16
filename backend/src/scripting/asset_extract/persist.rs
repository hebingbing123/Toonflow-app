//! 事务性 `app_asset` / `app_script_asset` 写入，用于单次提取批次。

use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::tool::{ExistingRefItemFiltered, NewAssetItemFiltered};
use super::util::{trim_empty_opt, ADV_LOCK_ASSET_NUMERIC_ID};

pub(crate) async fn persist_group(
    tx: &mut Transaction<'_, Postgres>,
    project_uuid: Uuid,
    batch_numeric_ids: &[i32],
    new_assets: &[NewAssetItemFiltered],
    existing_refs: &[ExistingRefItemFiltered],
) -> Result<(), String> {
    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC_ID)
        .execute(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;

    let script_rows: Vec<(Uuid, i32)> = sqlx::query_as(
        r#"SELECT id, numeric_id FROM app_script WHERE project_id = $1 AND numeric_id = ANY($2)"#,
    )
    .bind(project_uuid)
    .bind(batch_numeric_ids)
    .fetch_all(&mut **tx)
    .await
    .map_err(|e| e.to_string())?;

    let numeric_id_to_script: std::collections::HashMap<i32, Uuid> =
        script_rows.into_iter().map(|(id, lid)| (lid, id)).collect();

    let script_uuids: Vec<Uuid> = batch_numeric_ids
        .iter()
        .filter_map(|lid| numeric_id_to_script.get(lid).copied())
        .collect();

    if !script_uuids.is_empty() {
        sqlx::query(r#"DELETE FROM app_script_asset WHERE script_id = ANY($1)"#)
            .bind(&script_uuids)
            .execute(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;
    }

    let existing: Vec<(Uuid, String)> =
        sqlx::query_as(r#"SELECT id, name FROM app_asset WHERE project_id = $1"#)
            .bind(project_uuid)
            .fetch_all(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;

    let mut name_to_id: std::collections::HashMap<String, Uuid> =
        existing.into_iter().map(|(id, n)| (n, id)).collect();

    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) FROM app_asset"#)
            .fetch_one(&mut **tx)
            .await
            .map_err(|e| e.to_string())?;

    for na in new_assets {
        if name_to_id.contains_key(&na.name) {
            continue;
        }
        next_numeric_id += 1;
        let id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO app_asset (
              project_id, numeric_id, name, asset_type, description, create_time_ms, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, '{}'::jsonb)
            RETURNING id
            "#,
        )
        .bind(project_uuid)
        .bind(next_numeric_id)
        .bind(&na.name)
        .bind(&na.asset_type)
        .bind(trim_empty_opt(&na.desc))
        .bind(now_ms)
        .fetch_one(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;
        name_to_id.insert(na.name.clone(), id);
    }

    let mut pairs: Vec<(Uuid, Uuid)> = Vec::new();
    for na in new_assets {
        let Some(aid) = name_to_id.get(&na.name).copied() else {
            continue;
        };
        for lid in &na.script_numeric_ids {
            if let Some(sid) = numeric_id_to_script.get(lid) {
                pairs.push((*sid, aid));
            }
        }
    }
    for er in existing_refs {
        let Some(aid) = name_to_id.get(&er.name).copied() else {
            continue;
        };
        for lid in &er.script_numeric_ids {
            if let Some(sid) = numeric_id_to_script.get(lid) {
                pairs.push((*sid, aid));
            }
        }
    }

    pairs.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));
    pairs.dedup();

    for (sid, aid) in pairs {
        sqlx::query(
            r#"INSERT INTO app_script_asset (script_id, asset_id) VALUES ($1, $2)
               ON CONFLICT (script_id, asset_id) DO NOTHING"#,
        )
        .bind(sid)
        .bind(aid)
        .execute(&mut **tx)
        .await
        .map_err(|e| e.to_string())?;
    }

    Ok(())
}
