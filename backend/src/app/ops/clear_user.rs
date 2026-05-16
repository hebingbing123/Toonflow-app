use anyhow::{anyhow, bail, Context, Result};
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

use super::queries::{COUNT_QUERIES, DELETE_QUERIES};

#[derive(Debug, Clone, PartialEq, Eq)]
pub(super) struct ClearUserDataArgs {
    pub(super) user_id: Uuid,
    pub(super) execute: bool,
    pub(super) confirm: Option<String>,
}

impl ClearUserDataArgs {
    pub(super) fn parse(args: &[String]) -> Result<Self> {
        let mut user_id = None;
        let mut execute = false;
        let mut confirm = None;

        let mut i = 0usize;
        while i < args.len() {
            match args[i].as_str() {
                "--user-id" => {
                    i += 1;
                    let raw = args
                        .get(i)
                        .ok_or_else(|| anyhow!("missing value after --user-id"))?;
                    user_id = Some(
                        Uuid::parse_str(raw)
                            .with_context(|| format!("invalid --user-id `{raw}`"))?,
                    );
                }
                "--confirm" => {
                    i += 1;
                    confirm = Some(
                        args.get(i)
                            .ok_or_else(|| anyhow!("missing value after --confirm"))?
                            .clone(),
                    );
                }
                "--execute" => execute = true,
                "--dry-run" => execute = false,
                "--help" | "-h" => bail!("{}", super::USAGE),
                other => bail!("unknown argument `{other}`\n\n{}", super::USAGE),
            }
            i += 1;
        }

        let user_id = user_id.ok_or_else(|| anyhow!("--user-id is required"))?;
        Ok(Self {
            user_id,
            execute,
            confirm,
        })
    }
}

pub(super) async fn clear_user_data(args: ClearUserDataArgs) -> Result<()> {
    let database_url = std::env::var("DATABASE_URL").context("DATABASE_URL is required")?;
    let pool = PgPoolOptions::new()
        .max_connections(1)
        .connect(&database_url)
        .await
        .context("connect postgres")?;

    let counts = collect_counts(&pool, args.user_id).await?;
    print_report(args.user_id, args.execute, &counts);

    if !args.execute {
        return Ok(());
    }

    let expected_confirm = format!("clear-user-data:{}", args.user_id);
    if args.confirm.as_deref() != Some(expected_confirm.as_str()) {
        bail!(
            "--execute requires --confirm {}",
            shell_escape(&expected_confirm)
        );
    }

    let mut tx = pool.begin().await.context("begin transaction")?;
    for (label, sql) in DELETE_QUERIES {
        let deleted = sqlx::query(sql)
            .bind(args.user_id)
            .execute(&mut *tx)
            .await
            .with_context(|| format!("delete {label}"))?
            .rows_affected();
        eprintln!("deleted {label}: {deleted}");
    }
    tx.commit()
        .await
        .context("commit clear-user-data transaction")?;
    eprintln!("clear-user-data committed for {}", args.user_id);
    Ok(())
}

async fn collect_counts(pool: &sqlx::PgPool, user_id: Uuid) -> Result<Vec<(String, i64)>> {
    let mut counts = Vec::with_capacity(COUNT_QUERIES.len());
    for (label, sql) in COUNT_QUERIES {
        let count = sqlx::query_scalar::<_, i64>(sql)
            .bind(user_id)
            .fetch_one(pool)
            .await
            .with_context(|| format!("count {label}"))?;
        counts.push(((*label).to_string(), count));
    }
    Ok(counts)
}

fn print_report(user_id: Uuid, execute: bool, counts: &[(String, i64)]) {
    let mode = if execute { "execute" } else { "dry-run" };
    eprintln!("clear-user-data {mode} report for {user_id}");
    for (label, count) in counts {
        eprintln!("  {label}: {count}");
    }
    eprintln!(
        "note: deleting projects cascades project-owned scripts/storyboards/assets/novels/videos and related child rows"
    );
}

fn shell_escape(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\"'\"'"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_clear_user_data_defaults_to_dry_run() {
        let user_id = Uuid::new_v4();
        let args = vec!["--user-id".into(), user_id.to_string()];
        let parsed = ClearUserDataArgs::parse(&args).unwrap();
        assert_eq!(
            parsed,
            ClearUserDataArgs {
                user_id,
                execute: false,
                confirm: None,
            }
        );
    }

    #[test]
    fn parse_clear_user_data_execute_requires_confirm_later() {
        let user_id = Uuid::new_v4();
        let confirm = format!("clear-user-data:{user_id}");
        let args = vec![
            "--user-id".into(),
            user_id.to_string(),
            "--execute".into(),
            "--confirm".into(),
            confirm.clone(),
        ];
        let parsed = ClearUserDataArgs::parse(&args).unwrap();
        assert!(parsed.execute);
        assert_eq!(parsed.confirm.as_deref(), Some(confirm.as_str()));
    }

    #[test]
    fn parse_clear_user_data_rejects_unknown_flag() {
        let user_id = Uuid::new_v4();
        let args = vec!["--user-id".into(), user_id.to_string(), "--nope".into()];
        assert!(ClearUserDataArgs::parse(&args).is_err());
    }
}
