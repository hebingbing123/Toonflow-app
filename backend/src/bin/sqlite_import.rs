//! 将SQLite `db2.sqlite` 表导入 `import_staging.snapshot`（JSONB 行）。
//!
//! 用法：
//! ```text
//! SQLITE_PATH=/path/to/db2.sqlite DATABASE_URL=postgresql://... \
//!   cargo run --bin openflow-sqlite-import --release
//! ```
//! 可选：`IMPORT_STAGING_TRUNCATE=1` 首先执行 `TRUNCATE import_staging.snapshot`。

use std::collections::HashMap;

use anyhow::{bail, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use rusqlite::{types::Value as SqlValue, Connection};
use serde_json::{json, Map, Value};
use sqlx::postgres::PgPoolOptions;
use sqlx::types::Json;

/// Whitelist: must match `src/lib/initDB.ts` table names exactly.
const TABLES: &[&str] = &[
    "o_user",
    "o_project",
    "o_artStyle",
    "o_agentDeploy",
    "o_setting",
    "o_tasks",
    "o_prompt",
    "o_novel",
    "o_event",
    "o_eventChapter",
    "o_outline",
    "o_outlineNovel",
    "o_script",
    "o_assets",
    "o_image",
    "o_storyboard",
    "o_agentWorkData",
    "o_video",
    "o_videoTrack",
    "o_vendorConfig",
    "o_imageFlow",
    "o_assets2Storyboard",
    "o_scriptAssets",
    "o_skillList",
    "o_skillAttribution",
];

fn sql_value_to_json(v: SqlValue) -> Value {
    match v {
        SqlValue::Null => Value::Null,
        SqlValue::Integer(i) => json!(i),
        SqlValue::Real(f) => json!(f),
        SqlValue::Text(s) => Value::String(s),
        SqlValue::Blob(b) => Value::String(format!("base64:{}", STANDARD.encode(b))),
    }
}

fn is_safe_table_name(name: &str) -> bool {
    !name.is_empty() && name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
}

fn read_table(conn: &Connection, table: &str) -> Result<Vec<(i64, Map<String, Value>)>> {
    if !is_safe_table_name(table) {
        bail!("invalid table name");
    }
    let sql = format!(r#"SELECT rowid AS "__tk_rowid", * FROM "{table}""#);
    let mut stmt = conn
        .prepare(&sql)
        .with_context(|| format!("prepare {table}"))?;
    let col_count = stmt.column_count();
    let col_names: Vec<String> = (0..col_count)
        .map(|i| stmt.column_name(i).unwrap_or("").to_string())
        .collect();

    let mut out = Vec::new();
    let mut rows = stmt.query([])?;
    while let Some(row) = rows.next()? {
        let rowid: i64 = row.get(0)?;
        let mut map = Map::new();
        for i in 1..col_count {
            let name = col_names
                .get(i)
                .cloned()
                .unwrap_or_else(|| format!("col_{i}"));
            if name == "__tk_rowid" {
                continue;
            }
            let v: SqlValue = row.get(i)?;
            map.insert(name, sql_value_to_json(v));
        }
        out.push((rowid, map));
    }
    Ok(out)
}

fn table_exists(conn: &Connection, table: &str) -> Result<bool> {
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?1",
        [table],
        |r| r.get(0),
    )?;
    Ok(count > 0)
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();

    let sqlite_path = std::env::var("SQLITE_PATH").context("SQLITE_PATH is required")?;
    let database_url = std::env::var("DATABASE_URL").context("DATABASE_URL is required")?;

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .context("connect postgres")?;

    if std::env::var("IMPORT_STAGING_TRUNCATE").ok().as_deref() == Some("1") {
        sqlx::query("TRUNCATE import_staging.snapshot RESTART IDENTITY")
            .execute(&pool)
            .await
            .context("truncate import_staging.snapshot")?;
        eprintln!("truncated import_staging.snapshot");
    }

    let sqlite_conn =
        Connection::open(&sqlite_path).with_context(|| format!("open sqlite {}", sqlite_path))?;

    let mut total_rows: usize = 0;
    let mut per_table: HashMap<String, usize> = HashMap::new();

    for &table in TABLES {
        if !table_exists(&sqlite_conn, table)? {
            eprintln!("skip missing table: {table}");
            continue;
        }
        let rows = match read_table(&sqlite_conn, table) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("skip {table}: {e:#}");
                continue;
            }
        };
        let n = rows.len();
        for (rowid, map) in rows {
            let payload = Value::Object(map);
            sqlx::query(
                r#"INSERT INTO import_staging.snapshot (source_table, source_row_key, payload)
                   VALUES ($1, $2, $3)"#,
            )
            .bind(table)
            .bind(rowid.to_string())
            .bind(Json(payload))
            .execute(&pool)
            .await
            .with_context(|| format!("insert {table} rowid {rowid}"))?;
        }
        total_rows += n;
        per_table.insert(table.to_string(), n);
        eprintln!("imported {table}: {n} rows");
    }

    eprintln!("done: {total_rows} rows total");
    for (t, c) in per_table {
        eprintln!("  {t}: {c}");
    }
    Ok(())
}
