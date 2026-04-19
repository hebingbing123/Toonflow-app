//! 脚本域 Harness 工具：get_planData、get_script_content、get_novel_text、get_novel_events。

mod novel;
mod plan;
mod rows;
mod scope;
mod script_content;

pub(crate) use novel::{invoke_get_novel_events, invoke_get_novel_text};
pub(crate) use plan::invoke_get_plan_data;
pub(crate) use scope::require_owned_script_scope;
pub(crate) use script_content::invoke_get_script_content;
