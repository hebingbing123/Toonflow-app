//! 后台任务：加载脚本，调用 LLM 工具，持久化资产。

mod mark_failed;
mod process_group;
mod run;

pub(crate) use run::run_extract_job;
