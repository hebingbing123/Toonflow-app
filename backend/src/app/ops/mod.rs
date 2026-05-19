//! 受保护的操作命令，用于 HTTP API 之外的维护任务。
//!
//! 提供命令行工具执行一次性维护操作，如清除用户数据。
//! 默认以 --dry-run 模式运行，执行需要显式确认。

use anyhow::{bail, Result};

mod clear_user;
mod queries;

pub const USAGE: &str = "\
openflow-server ops clear-user-data --user-id <uuid> [--dry-run]
openflow-server ops clear-user-data --user-id <uuid> --execute --confirm clear-user-data:<uuid>

Notes:
  - requires DATABASE_URL
  - default mode is --dry-run
  - --execute requires a matching --confirm string";

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
            let config = clear_user::ClearUserDataArgs::parse(&args[1..])?;
            clear_user::clear_user_data(config).await
        }
        Some("--help") | Some("-h") | None => {
            println!("{USAGE}");
            Ok(())
        }
        Some(other) => bail!("unknown ops command `{other}`\n\n{USAGE}"),
    }
}
