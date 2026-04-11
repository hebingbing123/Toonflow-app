//! 受保护的操作命令，用于 HTTP API 之外的维护任务。
//!
//! 提供命令行工具执行一次性维护操作，如清除用户数据。
//! 默认以 --dry-run 模式运行，执行需要显式确认。

use anyhow::{anyhow, bail, Context, Result};
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

const USAGE: &str = "\
toonflow-server ops clear-user-data --user-id <uuid> [--dry-run]
toonflow-server ops clear-user-data --user-id <uuid> --execute --confirm clear-user-data:<uuid>

Notes:
  - requires DATABASE_URL
  - default mode is --dry-run
  - --execute requires a matching --confirm string";

const COUNT_QUERIES: &[(&str, &str)] = &[
    (
        "projects",
        "SELECT COUNT(*)::bigint FROM public.app_project WHERE owner_user_id = $1",
    ),
    (
        "scripts",
        "SELECT COUNT(*)::bigint
         FROM public.app_script s
         INNER JOIN public.app_project p ON p.id = s.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "storyboards",
        "SELECT COUNT(*)::bigint
         FROM public.app_storyboard sb
         INNER JOIN public.app_script s ON s.id = sb.script_id
         INNER JOIN public.app_project p ON p.id = s.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "assets",
        "SELECT COUNT(*)::bigint
         FROM public.app_asset a
         INNER JOIN public.app_project p ON p.id = a.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "asset_images",
        "SELECT COUNT(*)::bigint
         FROM public.app_asset_image ai
         INNER JOIN public.app_asset a ON a.id = ai.asset_id
         INNER JOIN public.app_project p ON p.id = a.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "novels",
        "SELECT COUNT(*)::bigint
         FROM public.app_novel n
         INNER JOIN public.app_project p ON p.id = n.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "novel_events",
        "SELECT COUNT(*)::bigint
         FROM public.app_novel_event e
         INNER JOIN public.app_project p ON p.id = e.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "videos",
        "SELECT COUNT(*)::bigint
         FROM public.app_video v
         INNER JOIN public.app_project p ON p.id = v.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "video_tracks",
        "SELECT COUNT(*)::bigint
         FROM public.app_video_track vt
         INNER JOIN public.app_project p ON p.id = vt.project_id
         WHERE p.owner_user_id = $1",
    ),
    (
        "generation_jobs",
        "SELECT COUNT(*)::bigint FROM public.app_generation_job WHERE owner_user_id = $1",
    ),
    (
        "quality_reviews",
        "SELECT COUNT(*)::bigint FROM public.app_quality_review WHERE user_id = $1",
    ),
    (
        "usage_events",
        "SELECT COUNT(*)::bigint FROM public.app_usage_event WHERE user_id = $1",
    ),
    (
        "agent_memories",
        "SELECT COUNT(*)::bigint FROM public.app_agent_memory WHERE owner_user_id = $1",
    ),
    (
        "script_agent_plans",
        "SELECT COUNT(*)::bigint FROM public.app_script_agent_plan WHERE owner_user_id = $1",
    ),
    (
        "art_styles",
        "SELECT COUNT(*)::bigint FROM public.app_art_style WHERE owner_user_id = $1",
    ),
    (
        "prompts",
        "SELECT COUNT(*)::bigint FROM public.app_user_prompt WHERE owner_user_id = $1",
    ),
    (
        "vendor_credentials",
        "SELECT COUNT(*)::bigint FROM public.app_vendor_credential WHERE owner_user_id = $1",
    ),
    (
        "user_profiles",
        "SELECT COUNT(*)::bigint FROM public.app_user_profile WHERE user_id = $1",
    ),
    (
        "import_user_maps",
        "SELECT COUNT(*)::bigint FROM public.import_user_map WHERE supabase_user_id = $1",
    ),
];

const DELETE_QUERIES: &[(&str, &str)] = &[
    (
        "quality_reviews",
        "DELETE FROM public.app_quality_review WHERE user_id = $1",
    ),
    (
        "generation_jobs",
        "DELETE FROM public.app_generation_job WHERE owner_user_id = $1",
    ),
    (
        "usage_events",
        "DELETE FROM public.app_usage_event WHERE user_id = $1",
    ),
    (
        "agent_memories",
        "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1",
    ),
    (
        "script_agent_plans",
        "DELETE FROM public.app_script_agent_plan WHERE owner_user_id = $1",
    ),
    (
        "art_styles",
        "DELETE FROM public.app_art_style WHERE owner_user_id = $1",
    ),
    (
        "prompts",
        "DELETE FROM public.app_user_prompt WHERE owner_user_id = $1",
    ),
    (
        "vendor_credentials",
        "DELETE FROM public.app_vendor_credential WHERE owner_user_id = $1",
    ),
    (
        "projects",
        "DELETE FROM public.app_project WHERE owner_user_id = $1",
    ),
    (
        "import_user_maps",
        "DELETE FROM public.import_user_map WHERE supabase_user_id = $1",
    ),
    (
        "user_profiles",
        "DELETE FROM public.app_user_profile WHERE user_id = $1",
    ),
];

pub async fn maybe_run_from_args<I>(args: I) -> Option<Result<()>>
where
    I: IntoIterator<Item = String>,
{
    let args: Vec<String> = args.into_iter().collect();
    if args.first().map(String::as_str) != Some("ops") {
        return None;
    }
    Some(run_ops(&args[1..]).await)
}

async fn run_ops(args: &[String]) -> Result<()> {
    match args.first().map(String::as_str) {
        Some("clear-user-data") => {
            let config = ClearUserDataArgs::parse(&args[1..])?;
            clear_user_data(config).await
        }
        Some("--help") | Some("-h") | None => {
            println!("{USAGE}");
            Ok(())
        }
        Some(other) => bail!("unknown ops command `{other}`\n\n{USAGE}"),
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ClearUserDataArgs {
    user_id: Uuid,
    execute: bool,
    confirm: Option<String>,
}

impl ClearUserDataArgs {
    fn parse(args: &[String]) -> Result<Self> {
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
                "--help" | "-h" => bail!("{USAGE}"),
                other => bail!("unknown argument `{other}`\n\n{USAGE}"),
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

async fn clear_user_data(args: ClearUserDataArgs) -> Result<()> {
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
